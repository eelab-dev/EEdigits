# uP8 Minimal — 8-bit Microprocessor Spec (Draft)

This document defines **uP8 Minimal**, a deliberately small 8-bit microprocessor intended for teaching and simple digital design exercises.

## 1. Overview

- **Data width:** 8-bit
- **Address width:** 16-bit
- **Endian:** little-endian for 16-bit immediates (low byte first)
- **Clocking:** single synchronous clock, positive edge
- **Reset:** synchronous reset, sets `PC=0x0000`, registers = 0, flags = 0

## 2. Programmer-Visible State

### 2.1 Registers

- `R0`..`R3`: four **8-bit general purpose registers**
- `PC`: **16-bit program counter**
- `Z`: **zero flag** (set to 1 when the last ALU result was 0)
- `C`: **carry/borrow flag**

### 2.2 Memory

- **Unified memory** for program and data (von Neumann)
- Address space: `0x0000`..`0xFFFF`
- Byte-addressed

No MMIO is mandated in this minimal spec.

## 3. Instruction Encoding

All instructions are **byte-aligned** and begin with a 1-byte opcode.

Common field conventions:

- `reg` fields are 2 bits: `00=R0`, `01=R1`, `10=R2`, `11=R3`
- `imm8` is an 8-bit immediate value
- `addr16` is a 16-bit absolute address, little-endian: `[low][high]`

### 3.1 Addressing modes

- **Register**: operand is `Rk`
- **Immediate**: operand is `imm8`
- **Absolute**: memory address is `addr16`

## 4. Instruction Set

### 4.1 Data movement

#### `MOV Rd, Rs`
- **Opcode:** `0x10 | (Rd<<2) | Rs`
- **Bytes:** 1
- **Operation:** `Rd ← Rs`
- **Flags:** unchanged

#### `MOVI Rd, imm8`
- **Opcode:** `0x20 | Rd`
- **Bytes:** 2
- **Operation:** `Rd ← imm8`
- **Flags:** unchanged

#### `LOAD Rd, [addr16]`
- **Opcode:** `0x30 | Rd`
- **Bytes:** 3
- **Operation:** `Rd ← MEM[addr16]`
- **Flags:** unchanged

#### `STORE Rs, [addr16]`
- **Opcode:** `0x40 | Rs`
- **Bytes:** 3
- **Operation:** `MEM[addr16] ← Rs`
- **Flags:** unchanged

### 4.2 Arithmetic / logic

#### `ADD Rd, Rs`
- **Opcode:** `0x50 | (Rd<<2) | Rs`
- **Bytes:** 1
- **Operation:** `{C, Rd} ← Rd + Rs`
- **Flags:** `Z` set from result, `C` set from carry out

#### `ADDI Rd, imm8`
- **Opcode:** `0x60 | Rd`
- **Bytes:** 2
- **Operation:** `{C, Rd} ← Rd + imm8`
- **Flags:** `Z` set from result, `C` set from carry out

#### `SUB Rd, Rs`
- **Opcode:** `0x70 | (Rd<<2) | Rs`
- **Bytes:** 1
- **Operation:** `{C, Rd} ← Rd - Rs`
- **Flags:** `Z` set from result, `C` set as *no-borrow* (typical CPU convention)

#### `SUBI Rd, imm8`
- **Opcode:** `0x80 | Rd`
- **Bytes:** 2
- **Operation:** `{C, Rd} ← Rd - imm8`
- **Flags:** `Z` set from result, `C` set as *no-borrow*

### 4.3 Control flow

#### `JMP addr16`
- **Opcode:** `0x90`
- **Bytes:** 3
- **Operation:** `PC ← addr16`
- **Flags:** unchanged

#### `JZ addr16`
- **Opcode:** `0x91`
- **Bytes:** 3
- **Operation:** `if Z==1 then PC ← addr16 else PC ← PC+3`
- **Flags:** unchanged

#### `JNZ addr16`
- **Opcode:** `0x92`
- **Bytes:** 3
- **Operation:** `if Z==0 then PC ← addr16 else PC ← PC+3`
- **Flags:** unchanged

### 4.4 System

#### `NOP`
- **Opcode:** `0x00`
- **Bytes:** 1
- **Operation:** no change

#### `HALT`
- **Opcode:** `0xFF`
- **Bytes:** 1
- **Operation:** stop fetching/executing instructions until reset

## 5. Execution Semantics

- Each instruction fetch reads `MEM[PC]` as opcode.
- Unless an instruction modifies `PC` directly, `PC` increments by the instruction length.
- Flags `Z` and `C` are only modified by ALU instructions listed above.

## 6. Assembly Syntax (Suggested)

Suggested textual assembly format:

- Registers: `R0`, `R1`, `R2`, `R3`
- Hex immediates: `0xNN`
- Hex addresses: `0xHHLL` (16-bit)

Examples:

```asm
MOVI R0, 0x05
ADDI R0, 0x01
JNZ  0x0010
```

## 7. Notes / Intentional Omissions

This spec intentionally omits:

- stack, calls/returns
- interrupts
- indirect addressing
- IO devices

Those can be added later as extensions.
