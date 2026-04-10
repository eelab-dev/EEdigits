`default_nettype none

//=============================================================================
// Formal Verification Harness for UART Receiver — Refinement v3 (R4)
//=============================================================================
// Progression of assertions across rounds:
//
//  R1 (baseline): port-level protocol only — busy/valid timing, one-cycle pulse
//  R2 (+v1 harness): added assert(rx_data == rx_latched) at rx_valid → 4 killed
//  R3 (same harness, bmc/yices): proved vs. proved, 9 killed, 11 survived
//  R4 (this file): three targeted additions that address all four surviving
//      mutation classes identified by manual root-cause analysis:
//
//  A. LIVENESS (kills 7: M001,M003,M004,M010,M011,M015,M018)
//     Mutations that suppress rx_valid entirely survive safety-only checks
//     vacuously.  Assert that rx_valid fires within TotalCycles+slack cycles
//     after the frame is launched.
//
//  B. NO PREMATURE VALID (kills 1: M009)
//     !(baud_tick) in SStop causes rx_valid to fire at the *start* of SStop
//     (phase 90) instead of the final cycle (phase 99).  Data is still
//     correct at that point, so the data assertion passes.  An explicit
//     assertion that rx_valid must not fire while we are still well inside
//     the active transmission window catches this.
//
//  C. POST-VALID BUSY CLEAN-UP (kills 1: M005)
//     state<=SStart after stop bit: rx_valid fires correctly, but SStart
//     sets rx_busy<=1 on the very next cycle.  Assert rx_busy is low the
//     cycle after rx_valid.
//
//  Irreducible survivors after R4 (stimulus-limited):
//    M002  — false-start recovery path, dead code for valid single frames
//    M014  — baud_mid inversion in stop-bit sampling; stop_ok still ends
//             up 1 (rx_serial=1 throughout stop bit), producing same output
//=============================================================================

module uart_rx_formal;
  // Reduced parameters for faster formal verification
  localparam int ClkHz = 100;
  localparam int Baud  = 10;
  localparam int BaudDiv    = ClkHz / Baud;   // 10 cycles per bit
  localparam int FrameBits  = 10;             // start + 8 data + stop
  localparam int TotalCycles = BaudDiv * FrameBits; // 100 cycles total

  // Clock and reset
  (* gclk *) logic clk;
  logic rst;

  // Test stimulus and DUT signals
  (* anyseq *) logic [7:0] rx_payload;
  logic rx_serial;
  wire [7:0] rx_data;
  wire rx_valid;
  wire rx_busy;

  uart_rx #(
      .CLK_HZ(ClkHz),
      .BAUD(Baud)
  ) dut (
      .clk(clk),
      .rst(rst),
      .rx_serial(rx_serial),
      .rx_data(rx_data),
      .rx_valid(rx_valid),
      .rx_busy(rx_busy)
  );

  // ── Harness state ─────────────────────────────────────────────────────────
  logic [7:0] rx_latched;
  logic active;
  logic fired;
  logic [$clog2(TotalCycles)-1:0] phase;

  // R4-A: liveness tracking
  logic seen_valid;
  logic [7:0] liveness_ctr; // 0..TotalCycles+slack

  function automatic logic expected_bit(input logic [3:0] idx);
    if (idx == 4'd0)
      expected_bit = 1'b0;
    else if (idx >= 4'd1 && idx <= 4'd8)
      expected_bit = rx_latched[idx - 4'd1];
    else
      expected_bit = 1'b1;
  endfunction

  // ── Reset / init ──────────────────────────────────────────────────────────
  always_ff @(posedge clk) begin
    if ($initstate) assume(rst);
    else            assume(!rst);
  end

  // ── Frame injection ───────────────────────────────────────────────────────
  always_ff @(posedge clk) begin
    if (rst) begin
      rx_latched   <= 8'd0;
      active       <= 1'b0;
      fired        <= 1'b0;
      phase        <= '0;
      seen_valid   <= 1'b0;
      liveness_ctr <= 8'd0;
    end else begin
      if (rx_valid) seen_valid <= 1'b1;

      if (!fired) begin
        fired      <= 1'b1;
        active     <= 1'b1;
        rx_latched <= rx_payload;
        phase      <= '0;
      end else if (active) begin
        phase <= (phase == TotalCycles - 1) ? '0 : phase + 1'b1;
        if (phase == TotalCycles - 1)
          active <= 1'b0;
      end

      // Count cycles since frame was launched (saturate at TotalCycles+10)
      if (fired && liveness_ctr < TotalCycles + 10)
        liveness_ctr <= liveness_ctr + 8'd1;
    end
  end

  // ── Serial line driver ────────────────────────────────────────────────────
  always_comb begin
    logic [3:0] bit_idx;
    rx_serial = 1'b1;
    bit_idx   = 4'd0;
    if (active) begin
      bit_idx   = phase / BaudDiv;
      rx_serial = expected_bit(bit_idx);
    end
  end

  // ── Assertions ────────────────────────────────────────────────────────────
  always_ff @(posedge clk) begin
    if (!rst) begin

      // ── R1: Port-level protocol ───────────────────────────────────────────
      // Before frame launch, DUT must be idle.
      if (!fired)
        assert(!rx_busy);

      // rx_valid implies not busy (valid is a completion signal).
      if (rx_valid)
        assert(!rx_busy);

      // rx_valid is a one-cycle pulse.
      if (!$initstate && $past(rx_valid))
        assert(!rx_valid);

      // ── R2: Data integrity ────────────────────────────────────────────────
      // When rx_valid fires, the received byte must match the transmitted one.
      if (rx_valid)
        assert(rx_data == rx_latched);

      // ── R4-A: Liveness ────────────────────────────────────────────────────
      // rx_valid must fire within TotalCycles+5 cycles of frame launch.
      // Kills any mutation that suppresses rx_valid entirely by making the
      // FSM get stuck, loop, or skip the SStop→rx_valid path.
      if (liveness_ctr == TotalCycles + 5)
        assert(seen_valid);

      // ── R4-B: No premature rx_valid ───────────────────────────────────────
      // rx_valid may only fire in the final 2 cycles of the active window
      // (the last baud period of the stop bit).  Any mutation that causes
      // rx_valid to fire earlier (e.g. !(baud_tick) in SStop) is caught here.
      if (active && phase < TotalCycles - 2)
        assert(!rx_valid);

      // ── R4-C: rx_busy must stay low after rx_valid ────────────────────────
      // After rx_valid fires, the DUT should return to SIdle (rx_busy=0).
      // Mutations that re-enter SStart immediately (which drives rx_busy=1)
      // are caught on the next cycle.
      if (!$initstate && $past(rx_valid))
        assert(!rx_busy);

      // ── Reachability witnesses ────────────────────────────────────────────
      cover(active);
      cover(rx_busy);
      cover(rx_valid);
    end
  end
endmodule

`default_nettype wire
