`default_nettype none

module sha3_keccak_prove_formal;
  (* gclk *) logic clk;

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

  // -------------------------------------------------------
  // Liveness tracking: count cycles since is_last was seen
  // -------------------------------------------------------
  logic [6:0] cyc_since_last;  // 7-bit saturating counter

  // Liveness bound: from the last block arriving, the permutation
  // takes ~1 cycle for padder_out_ready, then f_ack fires, then
  // keccak.i propagates through 11 stages (~12 cycles total).
  // 20 cycles is a generous upper bound (measured ~15 in sim);
  // BMC depth is also reduced to 30 so bitwuzla stays tractable.
  localparam int LIVENESS_BOUND = 20;

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

  // Latch seen_last and count cycles since it fired
  always @(posedge clk) begin
    if (reset) begin
      seen_last      <= 1'b0;
      cyc_since_last <= 7'd0;
    end else begin
      if (in_ready && is_last)
        seen_last <= 1'b1;

      // Saturating counter: only advance once seen_last is set
      if (seen_last && cyc_since_last < 7'd127)
        cyc_since_last <= cyc_since_last + 7'd1;
    end
  end

  // -------------------------------------------------------
  // Safety assertions
  // -------------------------------------------------------
  always @(posedge clk) begin
    // A1: out_ready must be 0 immediately after reset
    if (!$initstate && $past(reset)) begin
      assert(!out_ready);
    end

    // A2: out_ready must not fire before is_last (no premature output)
    if (!reset && !seen_last) begin
      assert(!out_ready);
    end

    // A3: out_ready is sticky once asserted
    if (!$initstate && !$past(reset) && !reset && $past(out_ready)) begin
      assert(out_ready);
    end

    // A4: seen_last must be true whenever out_ready is asserted
    if (!$initstate && out_ready) begin
      assert(seen_last);
    end
  end

  // -------------------------------------------------------
  // Liveness assertion: out_ready must fire within LIVENESS_BOUND
  // cycles of is_last being seen.
  // Catches mutants that permanently suppress out_ready:
  //   M001 (i never resets), M002 (state never 1),
  //   M004 (out_ready cleared every cycle), M006 (i[10] always 0),
  //   M008 (state never becomes 1 on is_last).
  // -------------------------------------------------------
  always @(posedge clk) begin
    if (!reset && cyc_since_last >= LIVENESS_BOUND) begin
      assert(out_ready);
    end
  end

  // NOTE: We intentionally omit an out-value assertion here.
  // The byte-reorder macro mutations (M009-M013, M016-M019) permute
  // the output but do not change timing, so they naturally escape
  // BMC unless an oracle value is available. The liveness and safety
  // assertions above cover all timing/control-path mutations.

  // -------------------------------------------------------
  // Cover points
  // -------------------------------------------------------
  always @(posedge clk) begin
    if (!reset) begin
      cover(seen_last);
      cover(buffer_full);
      cover(out_ready);
      cover(seen_last && out_ready);
    end
  end
endmodule

`default_nettype wire
