// uP8 Minimal CPU
// - 8-bit data
// - 16-bit PC
// - 4 x 8-bit registers (R0..R3)
// - unified byte-addressed memory
//
// Instruction set and encoding per examples/up8_minimal/up8_spec.md

`timescale 1ns/1ps

module up8_cpu #(
    parameter integer MEM_SIZE = 65536,
    parameter logic [1023:0] MEM_INIT_FILE = ""
) (
    input  wire        clk,
    input  wire        rst,

`ifdef UP8_SYMBOLIC_IMEM
    input  wire [7:0]  imem0,
    input  wire [7:0]  imem1,
    input  wire [7:0]  imem2,
`endif

    output reg  [15:0] pc,
    output reg         z,
    output reg         c,
    output reg         halted,

    output wire [7:0]  r0,
    output wire [7:0]  r1,
    output wire [7:0]  r2,
    output wire [7:0]  r3
);

    // ------------------------------------------------------------------------
    // State
    // ------------------------------------------------------------------------

    reg [7:0] regs [4];

    assign r0 = regs[0];
    assign r1 = regs[1];
    assign r2 = regs[2];
    assign r3 = regs[3];

    reg [7:0] mem [MEM_SIZE];

    integer i;
    initial begin
        for (i = 0; i < MEM_SIZE; i = i + 1) begin
            mem[i] = 8'h00;
        end
`ifdef UP8_INLINE_ROM
        // Optional: inline ROM contents for formal proofs.
        `include "up8_inline_rom.vh"
`endif

    end

    // Instruction fetch: 3 bytes maximum
`ifdef UP8_SYMBOLIC_IMEM
    // Formal-only mode: instruction bytes are provided as inputs.
    wire [7:0] op0 = imem0;
    wire [7:0] op1 = imem1;
    wire [7:0] op2 = imem2;
`else
    wire [7:0] op0 = mem[pc];
    wire [7:0] op1 = mem[pc + 16'd1];
    wire [7:0] op2 = mem[pc + 16'd2];
`endif

    // ------------------------------------------------------------------------
    // Decode helpers
    // ------------------------------------------------------------------------

    wire [1:0] dec_rd_2b = op0[3:2];
    wire [1:0] dec_rs_2b = op0[1:0];

    wire is_mov  = (op0[7:4] == 4'h1);
    wire is_add  = (op0[7:4] == 4'h5);
    wire is_sub  = (op0[7:4] == 4'h7);

    wire is_movi = ((op0 & 8'hFC) == 8'h20);
    wire is_load = ((op0 & 8'hFC) == 8'h30);
    wire is_store= ((op0 & 8'hFC) == 8'h40);

    wire is_addi = ((op0 & 8'hFC) == 8'h60);
    wire is_subi = ((op0 & 8'hFC) == 8'h80);

    wire is_jmp  = (op0 == 8'h90);
    wire is_jz   = (op0 == 8'h91);
    wire is_jnz  = (op0 == 8'h92);

    wire is_nop  = (op0 == 8'h00);
    wire is_halt = (op0 == 8'hFF);

    wire [15:0] imm_addr16 = {op2, op1};

    // Absolute memory read helper (used by LOAD)
`ifdef UP8_FORMAL_ROMONLY
    wire [7:0] mem_abs_rd = 8'h00;
`else
    wire [7:0] mem_abs_rd = mem[imm_addr16];
`endif

    // ------------------------------------------------------------------------
    // Next-state
    // ------------------------------------------------------------------------

    reg [15:0] pc_next;
    reg        z_next;
    reg        c_next;
    reg        halted_next;

    reg [7:0]  regs_next [4];

    reg        mem_we;
    reg [15:0] mem_waddr;
    reg [7:0]  mem_wdata;

    reg [8:0]  wide;
    reg [7:0]  alu_res;
    reg        alu_c;

    integer k;
    always_comb begin
        pc_next = pc;
        z_next = z;
        c_next = c;
        halted_next = halted;

        for (k = 0; k < 4; k = k + 1) begin
            regs_next[k] = regs[k];
        end

        mem_we = 1'b0;
        mem_waddr = 16'h0000;
        mem_wdata = 8'h00;

        wide = 9'h000;
        alu_res = 8'h00;
        alu_c = 1'b0;

        if (halted) begin
            // Hold state.
            pc_next = pc;
        end else if (is_nop) begin
            pc_next = pc + 16'd1;

        end else if (!(is_halt)) begin
            halted_next = 1'b1;
            pc_next = pc + 16'd1;

        end else if (is_mov) begin
            regs_next[dec_rd_2b] = regs[dec_rs_2b];
            pc_next = pc + 16'd1;

        end else if (is_movi) begin
            regs_next[op0[1:0]] = op1;
            pc_next = pc + 16'd2;

        end else if (is_load) begin
            regs_next[op0[1:0]] = mem_abs_rd;
            pc_next = pc + 16'd3;

        end else if (is_store) begin
            pc_next = pc + 16'd3;

        end else if (is_add) begin
            wide = {1'b0, regs[dec_rd_2b]} + {1'b0, regs[dec_rs_2b]};
            alu_res = wide[7:0];
            alu_c = wide[8];
            regs_next[dec_rd_2b] = alu_res;
            z_next = (alu_res == 8'h00);
            c_next = alu_c;
            pc_next = pc + 16'd1;

        end else if (is_addi) begin
            wide = {1'b0, regs[op0[1:0]]} + {1'b0, op1};
            alu_res = wide[7:0];
            alu_c = wide[8];
            regs_next[op0[1:0]] = alu_res;
            z_next = (alu_res == 8'h00);
            c_next = alu_c;
            pc_next = pc + 16'd2;

        end else if (is_sub) begin
            // C = no-borrow
            wide = {1'b0, regs[dec_rd_2b]} - {1'b0, regs[dec_rs_2b]};
            alu_res = wide[7:0];
            alu_c = ~wide[8];
            regs_next[dec_rd_2b] = alu_res;
            z_next = (alu_res == 8'h00);
            c_next = alu_c;
            pc_next = pc + 16'd1;

        end else if (is_subi) begin
            wide = {1'b0, regs[op0[1:0]]} - {1'b0, op1};
            alu_res = wide[7:0];
            alu_c = ~wide[8];
            regs_next[op0[1:0]] = alu_res;
            z_next = (alu_res == 8'h00);
            c_next = alu_c;
            pc_next = pc + 16'd2;

        end else if (is_jmp) begin
            pc_next = imm_addr16;

        end else if (is_jz) begin
            pc_next = z ? imm_addr16 : (pc + 16'd3);

        end else if (is_jnz) begin
            pc_next = z ? (pc + 16'd3) : imm_addr16;

        end else begin
            // Unknown opcode: treat as NOP for robustness.
            pc_next = pc + 16'd1;
        end
    end

    // ------------------------------------------------------------------------
    // Sequential updates
    // ------------------------------------------------------------------------

    integer j;
    always @(posedge clk) begin
        if (rst) begin
            pc <= 16'h0000;
            z <= 1'b0;
            c <= 1'b0;
            halted <= 1'b0;
            for (j = 0; j < 4; j = j + 1) begin
                regs[j] <= 8'h00;
            end
        end else begin
            pc <= pc_next;
            z <= z_next;
            c <= c_next;
            halted <= halted_next;
            for (j = 0; j < 4; j = j + 1) begin
                regs[j] <= regs_next[j];
            end
        end
    end

endmodule
