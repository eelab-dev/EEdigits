`default_nettype none

// Instruction-semantics proof for uP8 without a concrete program.
//
// Idea:
// - Run with UP8_SYMBOLIC_IMEM so op0/op1/op2 are symbolic each cycle.
// - Constrain rst low so state is arbitrary (anyinit).
// - Constrain we are not halted in the previous cycle.
// - For the previous-cycle instruction, assert the next-state matches the spec.

module up8_isa_step_formal;
  (* gclk *) logic clk;
  logic rst;

  wire [15:0] pc;
  wire z;
  wire c;
  wire halted;
  wire [7:0] r0, r1, r2, r3;

  // Symbolic instruction bytes (formal-only)
  (* anyseq *)wire [7:0] imem0;
  (* anyseq *)wire [7:0] imem1;
  (* anyseq *)wire [7:0] imem2;

  // Keep memory small; in symbolic-imem mode memory is not used for instruction fetch.
  up8_cpu #(
      .MEM_SIZE(256),
      .MEM_INIT_FILE("")
  ) dut (
      .clk(clk),
      .rst(rst),
      .imem0(imem0),
      .imem1(imem1),
      .imem2(imem2),
      .pc(pc),
      .z(z),
      .c(c),
      .halted(halted),
      .r0(r0),
      .r1(r1),
      .r2(r2),
      .r3(r3)
  );

  // No reset: allow arbitrary pre-state (anyinit) for stronger semantics checks.
  always_ff @(posedge clk) begin
    assume (!rst);
  end

  function automatic logic [7:0] sel_reg(input logic [1:0] idx, input logic [7:0] a0,
                                         input logic [7:0] a1, input logic [7:0] a2,
                                         input logic [7:0] a3);
    case (idx)
      2'd0: sel_reg = a0;
      2'd1: sel_reg = a1;
      2'd2: sel_reg = a2;
      default: sel_reg = a3;
    endcase
  endfunction

  function automatic logic [7:0] upd_reg(
      input logic [1:0] idx, input logic [7:0] newv, input logic [7:0] a0, input logic [7:0] a1,
      input logic [7:0] a2, input logic [7:0] a3, input logic [7:0] which);
    // "which" selects which output register to return (0..3)
    logic [7:0] b0, b1, b2, b3;
    begin
      b0 = a0;
      b1 = a1;
      b2 = a2;
      b3 = a3;
      case (idx)
        2'd0: b0 = newv;
        2'd1: b1 = newv;
        2'd2: b2 = newv;
        default: b3 = newv;
      endcase

      case (which[1:0])
        2'd0: upd_reg = b0;
        2'd1: upd_reg = b1;
        2'd2: upd_reg = b2;
        default: upd_reg = b3;
      endcase
    end
  endfunction


  // Constrain and assert next-state semantics for *all* outputs.
  // (Use a clocked block so $past() is legal in Yosys.)
  always @(posedge clk) begin
    if (!$initstate) begin
      logic [15:0] pc_p;
      logic z_p;
      logic c_p;
      logic halted_p;
      logic [7:0] r0_p;
      logic [7:0] r1_p;
      logic [7:0] r2_p;
      logic [7:0] r3_p;
      logic [7:0] op0_p;
      logic [7:0] op1_p;
      logic [7:0] op2_p;
      logic [15:0] addr16_p;
      logic [1:0] rd_p;
      logic [1:0] rs_p;

      // Expected next-state
      logic [15:0] exp_pc;
      logic exp_halted;
      logic exp_z;
      logic exp_c;
      logic [7:0] exp_r0;
      logic [7:0] exp_r1;
      logic [7:0] exp_r2;
      logic [7:0] exp_r3;

      logic [7:0] rd_val;
      logic [7:0] rs_val;
      logic [7:0] mov_val;
      logic [8:0] wide;
      logic [7:0] res;
      logic carry;
      logic noborrow;
      logic [1:0] rd;

      pc_p = $past(pc);
      z_p = $past(z);
      c_p = $past(c);
      halted_p = $past(halted);
      r0_p = $past(r0);
      r1_p = $past(r1);
      r2_p = $past(r2);
      r3_p = $past(r3);
      op0_p = $past(imem0);
      op1_p = $past(imem1);
      op2_p = $past(imem2);

      addr16_p = {op2_p, op1_p};
      rd_p = op0_p[3:2];
      rs_p = op0_p[1:0];

      // Constraints
      assume (!halted_p);
      assume (pc_p <= 16'hFFFC);
      assume ((op0_p & 8'hFC) != 8'h30);  // no LOAD
      assume ((op0_p & 8'hFC) != 8'h40);  // no STORE

      // Defaults = NOP behavior (unknown opcodes treated as NOP in the RTL)
      exp_pc = pc_p + 16'd1;
      exp_halted = 1'b0;
      exp_z = z_p;
      exp_c = c_p;
      exp_r0 = r0_p;
      exp_r1 = r1_p;
      exp_r2 = r2_p;
      exp_r3 = r3_p;

      rd_val = sel_reg(rd_p, r0_p, r1_p, r2_p, r3_p);
      rs_val = sel_reg(rs_p, r0_p, r1_p, r2_p, r3_p);
      mov_val = rs_val;

      if (op0_p == 8'h00) begin
        exp_pc = pc_p + 16'd1;
      end else if (op0_p == 8'hFF) begin
        exp_pc = pc_p + 16'd1;
        exp_halted = 1'b1;
      end else if (op0_p[7:4] == 4'h1) begin
        // MOV Rd, Rs
        exp_pc = pc_p + 16'd1;
        exp_r0 = upd_reg(rd_p, mov_val, r0_p, r1_p, r2_p, r3_p, 8'd0);
        exp_r1 = upd_reg(rd_p, mov_val, r0_p, r1_p, r2_p, r3_p, 8'd1);
        exp_r2 = upd_reg(rd_p, mov_val, r0_p, r1_p, r2_p, r3_p, 8'd2);
        exp_r3 = upd_reg(rd_p, mov_val, r0_p, r1_p, r2_p, r3_p, 8'd3);
      end else if ((op0_p & 8'hFC) == 8'h20) begin
        // MOVI Rd, imm8
        rd = op0_p[1:0];
        exp_pc = pc_p + 16'd2;
        exp_r0 = upd_reg(rd, op1_p, r0_p, r1_p, r2_p, r3_p, 8'd0);
        exp_r1 = upd_reg(rd, op1_p, r0_p, r1_p, r2_p, r3_p, 8'd1);
        exp_r2 = upd_reg(rd, op1_p, r0_p, r1_p, r2_p, r3_p, 8'd2);
        exp_r3 = upd_reg(rd, op1_p, r0_p, r1_p, r2_p, r3_p, 8'd3);
      end else if (op0_p[7:4] == 4'h5) begin
        // ADD Rd, Rs
        wide = {1'b0, rd_val} + {1'b0, rs_val};
        res = wide[7:0];
        carry = wide[8];
        exp_pc = pc_p + 16'd1;
        exp_z = (res == 8'h00);
        exp_c = carry;
        exp_r0 = upd_reg(rd_p, res, r0_p, r1_p, r2_p, r3_p, 8'd0);
        exp_r1 = upd_reg(rd_p, res, r0_p, r1_p, r2_p, r3_p, 8'd1);
        exp_r2 = upd_reg(rd_p, res, r0_p, r1_p, r2_p, r3_p, 8'd2);
        exp_r3 = upd_reg(rd_p, res, r0_p, r1_p, r2_p, r3_p, 8'd3);
      end else if ((op0_p & 8'hFC) == 8'h60) begin
        // ADDI Rd, imm8
        rd = op0_p[1:0];
        wide = {1'b0, sel_reg(rd, r0_p, r1_p, r2_p, r3_p)} + {1'b0, op1_p};
        res = wide[7:0];
        carry = wide[8];
        exp_pc = pc_p + 16'd2;
        exp_z = (res == 8'h00);
        exp_c = carry;
        exp_r0 = upd_reg(rd, res, r0_p, r1_p, r2_p, r3_p, 8'd0);
        exp_r1 = upd_reg(rd, res, r0_p, r1_p, r2_p, r3_p, 8'd1);
        exp_r2 = upd_reg(rd, res, r0_p, r1_p, r2_p, r3_p, 8'd2);
        exp_r3 = upd_reg(rd, res, r0_p, r1_p, r2_p, r3_p, 8'd3);
      end else if (op0_p[7:4] == 4'h7) begin
        // SUB Rd, Rs
        wide = {1'b0, rd_val} - {1'b0, rs_val};
        res = wide[7:0];
        noborrow = ~wide[8];
        exp_pc = pc_p + 16'd1;
        exp_z = (res == 8'h00);
        exp_c = noborrow;
        exp_r0 = upd_reg(rd_p, res, r0_p, r1_p, r2_p, r3_p, 8'd0);
        exp_r1 = upd_reg(rd_p, res, r0_p, r1_p, r2_p, r3_p, 8'd1);
        exp_r2 = upd_reg(rd_p, res, r0_p, r1_p, r2_p, r3_p, 8'd2);
        exp_r3 = upd_reg(rd_p, res, r0_p, r1_p, r2_p, r3_p, 8'd3);
      end else if ((op0_p & 8'hFC) == 8'h80) begin
        // SUBI Rd, imm8
        rd = op0_p[1:0];
        wide = {1'b0, sel_reg(rd, r0_p, r1_p, r2_p, r3_p)} - {1'b0, op1_p};
        res = wide[7:0];
        noborrow = ~wide[8];
        exp_pc = pc_p + 16'd2;
        exp_z = (res == 8'h00);
        exp_c = noborrow;
        exp_r0 = upd_reg(rd, res, r0_p, r1_p, r2_p, r3_p, 8'd0);
        exp_r1 = upd_reg(rd, res, r0_p, r1_p, r2_p, r3_p, 8'd1);
        exp_r2 = upd_reg(rd, res, r0_p, r1_p, r2_p, r3_p, 8'd2);
        exp_r3 = upd_reg(rd, res, r0_p, r1_p, r2_p, r3_p, 8'd3);
      end else if (op0_p == 8'h90) begin
        exp_pc = addr16_p;
      end else if (op0_p == 8'h91) begin
        exp_pc = z_p ? addr16_p : (pc_p + 16'd3);
      end else if (op0_p == 8'h92) begin
        exp_pc = z_p ? (pc_p + 16'd3) : addr16_p;
      end

      assert (pc == exp_pc);
      assert (halted == exp_halted);
      assert (z == exp_z);
      assert (c == exp_c);
      assert (r0 == exp_r0);
      assert (r1 == exp_r1);
      assert (r2 == exp_r2);
      assert (r3 == exp_r3);

      cover ((op0_p & 8'hFC) == 8'h20);  // MOVI
      cover ((op0_p & 8'hFC) == 8'h60);  // ADDI
      cover ((op0_p & 8'hFC) == 8'h80);  // SUBI
      cover (op0_p == 8'h90);  // JMP
      cover (op0_p == 8'hFF);  // HALT
    end
  end
endmodule

`default_nettype wire
