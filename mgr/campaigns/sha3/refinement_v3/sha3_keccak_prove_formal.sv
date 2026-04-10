`default_nettype none

// =====================================================================
// SHA3/Keccak formal harness – R3 refinement
//
// Two independent DUT instances run in parallel:
//   1. Symbolic-input DUT: liveness + safety assertions (control-path)
//   2. Fixed-input DUT: oracle output check (data-path / byte-reorder)
//
// The fixed-input DUT verifies the design against a known-good simulation
// output for in=0, byte_num=0, is_last=1 (one-block Keccak absorb).
// This catches M010-M013 and M016-M019 which only perturb the output
// byte-ordering or output-lane selection.
// =====================================================================

module sha3_keccak_prove_formal;
  (* gclk *) logic clk;

  // -------------------------------------------------------
  // === DUT 1: SYMBOLIC INPUTS ===
  // -------------------------------------------------------
  (* anyseq *) logic reset;
  (* anyseq *) logic [63:0] in;
  (* anyseq *) logic in_ready;
  (* anyseq *) logic is_last;
  (* anyseq *) logic [2:0] byte_num;

  wire buffer_full;
  wire [511:0] out;
  wire out_ready;

  keccak dut (
      .clk(clk),
      .reset(reset),
      .in(in),
      .in_ready(in_ready),
      .is_last(is_last),
      .byte_num(byte_num),
      .buffer_full(buffer_full),
      .out(out),
      .out_ready(out_ready)
  );

  logic seen_last;
  logic [6:0] cyc_since_last;

  // Liveness bound: out_ready fires at cycle ~19 from is_last; use 25
  localparam int LIVENESS_BOUND = 25;

  always @(posedge clk) begin
    if ($initstate) begin
      assume(reset);
    end else begin
      assume(!reset);
    end
  end

  always @(posedge clk) begin
    if (!in_ready) begin
      assume(!is_last);
    end
  end

  always @(posedge clk) begin
    if (reset) begin
      seen_last      <= 1'b0;
      cyc_since_last <= 7'd0;
    end else begin
      if (in_ready && is_last)
        seen_last <= 1'b1;
      if (seen_last && cyc_since_last < 7'd127)
        cyc_since_last <= cyc_since_last + 7'd1;
    end
  end

  // Safety assertions
  always @(posedge clk) begin
    if (!$initstate && $past(reset)) begin
      assert(!out_ready);
    end
    if (!reset && !seen_last) begin
      assert(!out_ready);
    end
    if (!$initstate && !$past(reset) && !reset && $past(out_ready)) begin
      assert(out_ready);
    end
    if (!$initstate && out_ready) begin
      assert(seen_last);
    end
  end

  // Liveness assertion
  always @(posedge clk) begin
    if (!reset && cyc_since_last >= LIVENESS_BOUND) begin
      assert(out_ready);
    end
  end

  // Cover points (symbolic-input DUT)
  always @(posedge clk) begin
    if (!reset) begin
      cover(seen_last);
      cover(buffer_full);
      cover(out_ready);
      cover(seen_last && out_ready);
    end
  end

  // -------------------------------------------------------
  // === DUT 2: FIXED INPUT ORACLE ===
  // Drives in=0, byte_num=0, is_last fires exactly once at cycle 3
  // (after 2 cycles of reset), then waits for out_ready.
  // Expected output obtained from RTL simulation:
  //   out = 512'h0eab42de4c3ceb9235fc91acffe746b29c29a8c366b7c60e
  //              4e67c466f36a4304c00fa9caf9d87976ba469bcbe06713b4
  //              35f091ef2769fb160cdab33d3670680e
  // (stored MSB-first in the wire, so out_f[511:448] = h0eab42de4c3ceb92, etc.)
  // -------------------------------------------------------
  localparam [511:0] ORACLE_OUT =
    512'h0eab42de4c3ceb9235fc91acffe746b29c29a8c366b7c60e4e67c466f36a4304c00fa9caf9d87976ba469bcbe06713b435f091ef2769fb160cdab33d3670680e;

  logic        rst_f;
  logic [63:0] in_f;
  logic        in_ready_f, is_last_f;
  logic [2:0]  byte_num_f;
  wire         buf_full_f;
  wire [511:0] out_f;
  wire         out_ready_f;

  keccak dut_fixed (
      .clk(clk),
      .reset(rst_f),
      .in(in_f),
      .in_ready(in_ready_f),
      .is_last(is_last_f),
      .byte_num(byte_num_f),
      .buffer_full(buf_full_f),
      .out(out_f),
      .out_ready(out_ready_f)
  );

  // Fixed-input state machine
  logic [5:0] fix_cyc;  // cycle counter for fixed DUT

  always @(posedge clk) begin
    if ($initstate) begin
      fix_cyc     <= 6'd0;
      rst_f       <= 1'b1;
      in_f        <= 64'h0;
      in_ready_f  <= 1'b0;
      is_last_f   <= 1'b0;
      byte_num_f  <= 3'd0;
    end else begin
      fix_cyc <= (fix_cyc < 6'd63) ? fix_cyc + 6'd1 : fix_cyc;

      // Reset for first 2 cycles
      rst_f      <= (fix_cyc < 6'd2);

      // Drive input block on cycle 2 (first non-reset cycle): in=0, byte_num=0, is_last=1
      in_ready_f <= (fix_cyc == 6'd2);
      is_last_f  <= (fix_cyc == 6'd2);
      in_f       <= 64'h0;
      byte_num_f <= 3'd0;
    end
  end

  // Once fixed DUT asserts out_ready, check the output
  always @(posedge clk) begin
    if (!$initstate && !rst_f && out_ready_f) begin
      assert(out_f == ORACLE_OUT);
    end
  end

  // Cover: fixed DUT must reach out_ready within depth 30
  always @(posedge clk) begin
    if (!rst_f) begin
      cover(out_ready_f);
    end
  end

endmodule

`default_nettype wire
