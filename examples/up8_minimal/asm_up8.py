#!/usr/bin/env python3
"""uP8 Minimal assembler.

Features (minimal but practical):
- Two-pass assembly with label resolution
- Accepts either .asm text or a Markdown file containing a ```asm fenced block
- Emits a ROM image as:
  - Verilog-friendly hex bytes (default): one byte per line (for $readmemh)
  - Raw binary

Instruction set implemented matches examples/up8_minimal/up8_spec.md.

Usage examples:
  python3 asm_up8.py program_add1_loop.md -o rom.memh
  python3 asm_up8.py input.asm -o rom.bin --format bin

"""

from __future__ import annotations

import argparse
import dataclasses
import re
import sys
from pathlib import Path
from typing import Iterable


class AsmError(Exception):
    pass


_LABEL_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


@dataclasses.dataclass(frozen=True)
class SourceLoc:
    path: str
    line_no: int
    line_text: str


@dataclasses.dataclass(frozen=True)
class Statement:
    loc: SourceLoc
    pc: int
    kind: str  # "insn" | "org" | "db"
    op: str
    args: tuple[str, ...]


def _strip_comment(line: str) -> str:
    # ';' is the canonical comment in our examples; also accept '#'.
    for ch in (";", "#"):
        idx = line.find(ch)
        if idx != -1:
            line = line[:idx]
    return line


def _extract_asm_from_markdown(text: str) -> str:
    # First fenced block tagged as asm.
    # Accept ```asm or ```ASM
    fence = re.compile(r"^```\s*(asm)\s*$", re.IGNORECASE)
    lines = text.splitlines()
    in_block = False
    out: list[str] = []
    for line in lines:
        if not in_block:
            if fence.match(line.strip()):
                in_block = True
            continue
        if line.strip().startswith("```"):
            break
        out.append(line)

    if not out:
        raise AsmError("no ```asm fenced block found in markdown input")
    return "\n".join(out) + "\n"


def _tokenize_args(arg_str: str) -> list[str]:
    # Split by commas but allow whitespace.
    parts = [p.strip() for p in arg_str.split(",")]
    return [p for p in parts if p]


def _parse_register(tok: str, loc: SourceLoc) -> int:
    t = tok.strip().upper()
    if t in ("R0", "R1", "R2", "R3"):
        return int(t[1])
    raise AsmError(_fmt_err(loc, f"invalid register '{tok}' (expected R0..R3)"))


def _parse_int_expr(expr: str, symbols: dict[str, int], loc: SourceLoc) -> int:
    e = expr.strip()
    if not e:
        raise AsmError(_fmt_err(loc, "empty expression"))

    # [LABEL] is handled elsewhere; here accept raw LABEL or numeric.
    if _LABEL_RE.match(e) and e.upper() not in ("R0", "R1", "R2", "R3"):
        if e in symbols:
            return symbols[e]
        raise AsmError(_fmt_err(loc, f"unknown symbol '{e}'"))

    try:
        if e.lower().startswith("0x"):
            return int(e, 16)
        if e.lower().startswith("0b"):
            return int(e, 2)
        return int(e, 10)
    except ValueError as ex:
        raise AsmError(_fmt_err(loc, f"invalid number '{expr}'")) from ex


def _parse_addr16(tok: str, symbols: dict[str, int], loc: SourceLoc) -> int:
    v = _parse_int_expr(tok, symbols, loc)
    if not (0 <= v <= 0xFFFF):
        raise AsmError(_fmt_err(loc, f"addr16 out of range: {v}"))
    return v


def _parse_imm8(tok: str, symbols: dict[str, int], loc: SourceLoc) -> int:
    v = _parse_int_expr(tok, symbols, loc)
    if not (0 <= v <= 0xFF):
        raise AsmError(_fmt_err(loc, f"imm8 out of range: {v}"))
    return v


def _fmt_err(loc: SourceLoc, msg: str) -> str:
    return f"{loc.path}:{loc.line_no}: {msg}\n  {loc.line_text.rstrip()}"


def _insn_size(mn: str, args: tuple[str, ...], loc: SourceLoc) -> int:
    m = mn.upper()

    if m in ("NOP", "HALT"):
        if args:
            raise AsmError(_fmt_err(loc, f"{m} takes no operands"))
        return 1

    if m in ("MOV", "ADD", "SUB"):
        if len(args) != 2:
            raise AsmError(_fmt_err(loc, f"{m} expects 2 operands"))
        return 1

    if m in ("MOVI", "ADDI", "SUBI"):
        if len(args) != 2:
            raise AsmError(_fmt_err(loc, f"{m} expects 2 operands"))
        return 2

    if m in ("LOAD", "STORE", "JMP", "JZ", "JNZ"):
        if m in ("LOAD", "STORE"):
            if len(args) != 2:
                raise AsmError(_fmt_err(loc, f"{m} expects 2 operands"))
        else:
            if len(args) != 1:
                raise AsmError(_fmt_err(loc, f"{m} expects 1 operand"))
        return 3

    raise AsmError(_fmt_err(loc, f"unknown mnemonic '{mn}'"))


def _encode_insn(mn: str, args: tuple[str, ...], symbols: dict[str, int], loc: SourceLoc) -> list[int]:
    m = mn.upper()

    if m == "NOP":
        return [0x00]
    if m == "HALT":
        return [0xFF]

    if m == "MOV":
        rd = _parse_register(args[0], loc)
        rs = _parse_register(args[1], loc)
        return [0x10 | (rd << 2) | rs]

    if m == "MOVI":
        rd = _parse_register(args[0], loc)
        imm = _parse_imm8(args[1], symbols, loc)
        return [0x20 | rd, imm]

    if m == "LOAD":
        rd = _parse_register(args[0], loc)
        addr_tok = args[1].strip()
        if not (addr_tok.startswith("[") and addr_tok.endswith("]")):
            raise AsmError(_fmt_err(loc, "LOAD expects [addr16] as second operand"))
        addr = _parse_addr16(addr_tok[1:-1].strip(), symbols, loc)
        return [0x30 | rd, addr & 0xFF, (addr >> 8) & 0xFF]

    if m == "STORE":
        rs = _parse_register(args[0], loc)
        addr_tok = args[1].strip()
        if not (addr_tok.startswith("[") and addr_tok.endswith("]")):
            raise AsmError(_fmt_err(loc, "STORE expects [addr16] as second operand"))
        addr = _parse_addr16(addr_tok[1:-1].strip(), symbols, loc)
        return [0x40 | rs, addr & 0xFF, (addr >> 8) & 0xFF]

    if m == "ADD":
        rd = _parse_register(args[0], loc)
        rs = _parse_register(args[1], loc)
        return [0x50 | (rd << 2) | rs]

    if m == "ADDI":
        rd = _parse_register(args[0], loc)
        imm = _parse_imm8(args[1], symbols, loc)
        return [0x60 | rd, imm]

    if m == "SUB":
        rd = _parse_register(args[0], loc)
        rs = _parse_register(args[1], loc)
        return [0x70 | (rd << 2) | rs]

    if m == "SUBI":
        rd = _parse_register(args[0], loc)
        imm = _parse_imm8(args[1], symbols, loc)
        return [0x80 | rd, imm]

    if m in ("JMP", "JZ", "JNZ"):
        op = {"JMP": 0x90, "JZ": 0x91, "JNZ": 0x92}[m]
        addr = _parse_addr16(args[0], symbols, loc)
        return [op, addr & 0xFF, (addr >> 8) & 0xFF]

    raise AsmError(_fmt_err(loc, f"unknown mnemonic '{mn}'"))


def _parse_source(path: Path) -> tuple[str, list[str]]:
    text = path.read_text(encoding="utf-8")
    if path.suffix.lower() in (".md", ".markdown"):
        asm = _extract_asm_from_markdown(text)
        return str(path), asm.splitlines()
    return str(path), text.splitlines()


def _iter_statements(src_path: str, lines: list[str]) -> Iterable[tuple[SourceLoc, str]]:
    for idx, raw in enumerate(lines, start=1):
        loc = SourceLoc(path=src_path, line_no=idx, line_text=raw)
        s = _strip_comment(raw).strip()
        if not s:
            continue
        yield loc, s


def _split_label_prefix(line: str) -> tuple[str | None, str]:
    # Support: LABEL: INSN ...
    # Also allow multiple labels on one line, e.g. A: B: NOP
    rest = line
    label: str | None = None
    while True:
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$", rest)
        if not m:
            break
        label = m.group(1)
        rest = m.group(2)
        if rest.strip() == "":
            break
    return label, rest


def assemble(input_path: Path) -> tuple[dict[int, int], int, dict[str, int]]:
    """Return (memory_image, max_addr_exclusive, symbols)."""

    src_path, lines = _parse_source(input_path)

    symbols: dict[str, int] = {}
    statements: list[Statement] = []

    pc = 0
    for loc, line in _iter_statements(src_path, lines):
        label, rest = _split_label_prefix(line)
        if label is not None:
            if label in symbols:
                raise AsmError(_fmt_err(loc, f"duplicate label '{label}'"))
            symbols[label] = pc

        rest = rest.strip()
        if not rest:
            continue

        # Directives
        upper = rest.upper()
        if upper.startswith(".ORG") or upper.startswith("ORG"):
            parts = rest.split(None, 1)
            if len(parts) != 2:
                raise AsmError(_fmt_err(loc, "ORG/.org requires an address"))
            new_pc = _parse_addr16(parts[1].strip(), symbols, loc)
            statements.append(Statement(loc=loc, pc=pc, kind="org", op="ORG", args=(parts[1].strip(),)))
            pc = new_pc
            continue

        if upper.startswith(".DB") or upper.startswith("DB"):
            parts = rest.split(None, 1)
            if len(parts) != 2:
                raise AsmError(_fmt_err(loc, "DB/.db requires one or more byte values"))
            args = tuple(_tokenize_args(parts[1]))
            if not args:
                raise AsmError(_fmt_err(loc, "DB/.db requires one or more byte values"))
            statements.append(Statement(loc=loc, pc=pc, kind="db", op="DB", args=args))
            pc += len(args)
            continue

        # Instruction
        if " " in rest:
            mn, arg_str = rest.split(None, 1)
            args = tuple(_tokenize_args(arg_str))
        else:
            mn, args = rest, ()

        size = _insn_size(mn, args, loc)
        statements.append(Statement(loc=loc, pc=pc, kind="insn", op=mn, args=args))
        pc += size

    # Second pass: emit bytes
    image: dict[int, int] = {}
    max_addr = 0

    for st in statements:
        if st.kind == "org":
            # No emitted bytes; pc change already accounted in pass1.
            continue

        if st.kind == "db":
            for i, tok in enumerate(st.args):
                b = _parse_imm8(tok, symbols, st.loc)
                addr = st.pc + i
                image[addr] = b
                max_addr = max(max_addr, addr + 1)
            continue

        if st.kind == "insn":
            bytes_ = _encode_insn(st.op, st.args, symbols, st.loc)
            for i, b in enumerate(bytes_):
                addr = st.pc + i
                image[addr] = b
                max_addr = max(max_addr, addr + 1)
            continue

        raise AsmError(_fmt_err(st.loc, f"internal error: unknown statement kind {st.kind}"))

    return image, max_addr, symbols


def _write_memh(path: Path, image: dict[int, int], size: int) -> None:
    # One byte per line: 00..FF
    lines = []
    for addr in range(size):
        b = image.get(addr, 0)
        lines.append(f"{b:02x}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _write_hex(path: Path, image: dict[int, int], size: int) -> None:
    # Space-separated bytes with address prefix per line (nice for humans).
    out: list[str] = []
    for base in range(0, size, 16):
        chunk = [image.get(a, 0) for a in range(base, min(size, base + 16))]
        out.append(f"{base:04x}: " + " ".join(f"{b:02x}" for b in chunk))
    path.write_text("\n".join(out) + "\n", encoding="utf-8")


def _write_bin(path: Path, image: dict[int, int], size: int) -> None:
    data = bytes(image.get(addr, 0) for addr in range(size))
    path.write_bytes(data)


def main() -> int:
    ap = argparse.ArgumentParser(description="Assemble uP8 Minimal assembly into a ROM image")
    ap.add_argument("input", type=Path, help=".asm file or Markdown file containing a fenced ```asm block")
    ap.add_argument("-o", "--output", type=Path, required=True, help="Output file path")
    ap.add_argument(
        "--format",
        choices=("memh", "hex", "bin"),
        default="memh",
        help="Output format: memh (one byte per line for $readmemh), hex (human), bin (raw)",
    )
    ap.add_argument(
        "--rom-size",
        type=lambda s: int(s, 0),
        default=None,
        help="Pad/trim ROM size in bytes (e.g. 256, 0x400). Default: just enough to fit program.",
    )
    ap.add_argument("--symbols", type=Path, default=None, help="Optional: write label map as text")

    args = ap.parse_args()

    try:
        image, max_addr, symbols = assemble(args.input)
        size = args.rom_size if args.rom_size is not None else max_addr
        if size < max_addr:
            raise AsmError(f"--rom-size {size} is smaller than program size {max_addr}")

        if args.format == "memh":
            _write_memh(args.output, image, size)
        elif args.format == "hex":
            _write_hex(args.output, image, size)
        elif args.format == "bin":
            _write_bin(args.output, image, size)
        else:
            raise AsmError(f"internal error: unknown format {args.format}")

        if args.symbols is not None:
            sym_lines = [f"{name} = 0x{addr:04x}" for name, addr in sorted(symbols.items(), key=lambda kv: kv[1])]
            args.symbols.write_text("\n".join(sym_lines) + "\n", encoding="utf-8")

        return 0

    except AsmError as e:
        print(str(e), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
