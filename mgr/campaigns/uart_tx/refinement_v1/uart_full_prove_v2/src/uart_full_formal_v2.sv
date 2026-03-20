`default_nettype none

//=============================================================================
// Formal Verification Harness v2 — Mutation-Guided Refinement, Round 2
//=============================================================================
// Targets for this iteration (survivors from round 1):
//
//   M001 — baud_cnt width reduced: baud_tick (== BaudDiv-1) never fires,
//           module stuck in SStart.  tx_serial is 0 forever, never reaches
//           data or stop bits.
//           NEW KILL: data-bit assertions + stop-bit assertion.
//
//   M005 — reset predicate inverted (if (!rst)):  state machine never runs,
//           tx_busy is always 0 during normal operation.
//           NEW KILL: assert tx_busy == 1 during the active frame.
//
//   M009 — bit_idx reset to 3'd1 in SIdle: SData loop runs bits 1..7 (7 bits)
//           instead of 0..7 (8 bits); frame is misaligned, rx_valid does not
//           fire or fires with wrong data.
//           NEW KILL: rx_valid_seen liveness assertion + data bit check.
//
// Near-equivalent survivors (cannot be killed — mutant generator noise):
//   M002  bit_idx width widened [2:0]→[3:0]:       comparison still works.
//   M006  1'b1→2'b1 on tx_serial in reset block:   same single-bit value.
//   M007  1'b0→2'b0 on tx_busy  in reset block:    same single-bit value.
//   M008  {1'b0}→{2'b0} concat for baud_cnt reset: same zero value.
//   M010  shift_reg reset 8'd0→8'd1:               always overwritten before use.
//   M011  1'b1→2'b1 on tx_serial in SIdle:         same single-bit value.
//   M012  1'b0→2'b0 on tx_busy  in SIdle:          same single-bit value.
//   M013  {1'b0}→{2'b0} concat for baud_cnt:       same zero value.
//   M016  1'b1→2'b1 on tx_busy in tx_start branch: same single-bit value.
//   M017  1'b0→2'b0 on tx_serial in SStart:        same single-bit value.
//   M019  {1'b0}→{2'b0} baud_cnt reset in SStart:  same zero value.
//   M020  baud_cnt + 2'b1 vs + 1'b1:               2'b01 == 1, same result.
//
// Timing reference (BaudDiv = ClkHz/Baud = 100/10 = 10 cycles/bit):
//   phase_cnt -1 : tx_start cycle (fired set, DUT transitions SIdle→SStart)
//   phase_cnt  0 : first SStart cycle;  tx_serial = 0 (start bit)
//   phase_cnt  0.. 9 : start bit period
//   phase_cnt 10..19 : data bit 0 period  (midpoint at 14)
//   phase_cnt 20..29 : data bit 1 period  (midpoint at 24)
//   ...
//   phase_cnt 80..89 : data bit 7 period  (midpoint at 84)
//   phase_cnt 90..99 : stop bit period (active deactivates at 99)
//   cycle_cnt ~101   : rx_valid fires  (loopback reception complete)
//=============================================================================

module uart_full_formal;
  //-------------------------------------------------------------------------
  // Parameters (kept small for fast formal proof)
  //-------------------------------------------------------------------------
  localparam int ClkHz   = 100;
  localparam int Baud    = 10;
  localparam int BaudDiv = ClkHz / Baud;  // = 10 cycles per bit

  //-------------------------------------------------------------------------
  // Clock, reset, DUT signals
  //-------------------------------------------------------------------------
  (* gclk *) logic clk;
  logic rst;

  (* anyseq *) logic [7:0] tx_payload;
  wire tx_start;
  wire tx_busy;
  wire tx_serial;
  wire rx_serial;
  wire [7:0] rx_data;
  wire rx_valid;
  wire rx_busy;

  // Loopback: TX output feeds RX input
  assign rx_serial = tx_serial;

  uart_full #(
      .CLK_HZ(ClkHz),
      .BAUD(Baud)
  ) dut (
      .clk      (clk),
      .rst      (rst),
      .rx_serial(rx_serial),
      .rx_data  (rx_data),
      .rx_valid (rx_valid),
      .rx_busy  (rx_busy),
      .tx_start (tx_start),
      .tx_data  (tx_payload),
      .tx_busy  (tx_busy),
      .tx_serial(tx_serial)
  );

  //-------------------------------------------------------------------------
  // Harness state tracking (unchanged from v1)
  //-------------------------------------------------------------------------
  logic         fired;
  logic [7:0]   tx_latched;
  integer       phase_cnt;
  logic         active;

  // Single tx_start pulse on first cycle after reset
  assign tx_start = (!rst) && !fired;

  always_ff @(posedge clk) begin
    if (rst) begin
      fired      <= 1'b0;
      tx_latched <= 8'd0;
      phase_cnt  <= 0;
      active     <= 1'b0;
    end else begin
      if (!fired) begin
        fired      <= 1'b1;
        tx_latched <= tx_payload;
        phase_cnt  <= -1;
        active     <= 1'b1;
      end else if (active) begin
        phase_cnt <= phase_cnt + 1;
      end

      if (active && (phase_cnt == (BaudDiv * 10 - 1)))
        active <= 1'b0;
    end
  end

  //-------------------------------------------------------------------------
  // NEW: cycle_cnt — free-running counter from the moment fired goes high.
  // Used for the rx_valid liveness assertion which fires AFTER active ends.
  //-------------------------------------------------------------------------
  integer cycle_cnt;

  always_ff @(posedge clk) begin
    if (rst)       cycle_cnt <= 0;
    else if (fired) cycle_cnt <= cycle_cnt + 1;
  end

  //-------------------------------------------------------------------------
  // NEW: rx_valid_seen — sticky latch; asserted once rx_valid pulses.
  //-------------------------------------------------------------------------
  logic rx_valid_seen;

  always_ff @(posedge clk) begin
    if (rst)          rx_valid_seen <= 1'b0;
    else if (rx_valid) rx_valid_seen <= 1'b1;
  end

  //-------------------------------------------------------------------------
  // Reset assumptions (unchanged from v1)
  //-------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if ($initstate) assume(rst);
    else            assume(!rst);
  end

  //=========================================================================
  // Formal properties
  //=========================================================================
  always_comb begin
    if (!rst) begin

      //---------------------------------------------------------------------
      // COVERAGE (unchanged from v1)
      //---------------------------------------------------------------------
      cover (tx_busy   == 1'b0);
      cover (tx_busy   == 1'b1);
      cover (rx_busy   == 1'b0);
      cover (rx_busy   == 1'b1);
      cover (rx_valid  == 1'b0);
      cover (rx_valid  == 1'b1);
      cover (rx_data   == 8'h00);
      cover (rx_data   == 8'hA5);

      //---------------------------------------------------------------------
      // V1 ASSERTIONS (loopback correctness — kept)
      //---------------------------------------------------------------------
      if (rx_valid) begin
        assert (rx_busy == 1'b0);           // Not busy when valid
        assert (rx_data == tx_latched);     // Loopback data matches TX payload
      end

      //---------------------------------------------------------------------
      // V2 ASSERTION A: tx_serial idles HIGH before any transmission.
      // Kills:  supplementary check (M005 already killed by B below, but
      //         also confirms idle line behaviour).
      //---------------------------------------------------------------------
      if (!fired) begin
        assert (tx_serial == 1'b1);
      end

      //---------------------------------------------------------------------
      // V2 ASSERTION B: tx_busy must be HIGH throughout the active frame.
      // Kills:  M005 — inverted reset means state machine never runs,
      //                 tx_busy is permanently 0.
      //
      // Guard:  phase_cnt < BaudDiv*10-1 (< 99) is required because at
      //         phase_cnt==99 the stop-bit baud_tick fires in the DUT,
      //         committing tx_busy←0 in the same posedge where harness
      //         still reads active==1 (active deasserts one cycle later).
      //         Excluding that final tick avoids a spurious false alarm on
      //         the correct baseline.
      //
      // (Check starts at phase_cnt >= 1: at phase_cnt==0 tx_busy is still
      //  being committed from the SIdle→SStart transition.)
      //---------------------------------------------------------------------
      if (active && phase_cnt >= 1 && phase_cnt < BaudDiv * 10 - 1) begin
        assert (tx_busy == 1'b1);
      end

      //---------------------------------------------------------------------
      // V2 ASSERTION C: tx_serial = 0 for the entire start-bit period.
      // Kills: confirms DUT leaves SStart (if still stuck, data assertions
      //        below will fire).
      //---------------------------------------------------------------------
      if (active && phase_cnt >= 0 && phase_cnt < BaudDiv) begin
        assert (tx_serial == 1'b0);
      end

      //---------------------------------------------------------------------
      // V2 ASSERTION D: tx_serial matches tx_latched[i] at data-bit midpoints.
      // Midpoint of bit i: phase_cnt = BaudDiv*(i+1) + BaudDiv/2 - 1
      //                             = 10*(i+1) + 4 = 10i + 14
      //
      // Kills:  M001 — stuck in SStart: tx_serial=0, never 1 for bits whose
      //                 data contains a 1.
      //         M009 — bit_idx starts at 1: 7 bits transmitted instead of 8,
      //                 frame boundary shifts, wrong bits on the serial line.
      //---------------------------------------------------------------------
      if (active && phase_cnt == BaudDiv * 1 + BaudDiv / 2 - 1) assert (tx_serial == tx_latched[0]);
      if (active && phase_cnt == BaudDiv * 2 + BaudDiv / 2 - 1) assert (tx_serial == tx_latched[1]);
      if (active && phase_cnt == BaudDiv * 3 + BaudDiv / 2 - 1) assert (tx_serial == tx_latched[2]);
      if (active && phase_cnt == BaudDiv * 4 + BaudDiv / 2 - 1) assert (tx_serial == tx_latched[3]);
      if (active && phase_cnt == BaudDiv * 5 + BaudDiv / 2 - 1) assert (tx_serial == tx_latched[4]);
      if (active && phase_cnt == BaudDiv * 6 + BaudDiv / 2 - 1) assert (tx_serial == tx_latched[5]);
      if (active && phase_cnt == BaudDiv * 7 + BaudDiv / 2 - 1) assert (tx_serial == tx_latched[6]);
      if (active && phase_cnt == BaudDiv * 8 + BaudDiv / 2 - 1) assert (tx_serial == tx_latched[7]);

      //---------------------------------------------------------------------
      // V2 ASSERTION E: tx_serial = 1 for the stop-bit period.
      //
      // Range: phase_cnt 91..98 (BaudDiv*9+1 .. BaudDiv*10-2).
      //   phase_cnt==90 is the first SStop cycle; the DUT commits
      //   tx_serial←1 at that posedge, so the new value is only visible
      //   from phase_cnt==91 onwards.  The upper bound excludes 99 for
      //   the same reason as assertion B (tx_busy/active boundary).
      //
      // Kills:  M001 — stuck in SStart, never reaches stop-bit window
      //                 (already caught earlier by D).
      //---------------------------------------------------------------------
      if (active && phase_cnt >= BaudDiv * 9 + 1 && phase_cnt < BaudDiv * 10 - 1) begin
        assert (tx_serial == 1'b1);
      end

      //---------------------------------------------------------------------
      // V2 ASSERTION F: tx_busy must be LOW once the frame is complete.
      //---------------------------------------------------------------------
      if (fired && !active) begin
        assert (tx_busy == 1'b0);
      end

      //---------------------------------------------------------------------
      // V2 ASSERTION G: rx_valid liveness — rx_valid MUST have pulsed by
      // cycle_cnt == 115.
      //
      // Timing: rx_valid fires at cycle_cnt ≈ 101 (loopback reception
      // completes one full 10-bit frame after TX start).  115 provides a
      // 14-cycle margin.  BMC depth in v2.sby is set to 150 to cover this.
      //
      // Kills:  M009 — with bit_idx starting at 1 the TX frame is malformed;
      //                 the RX either never asserts rx_valid or asserts it
      //                 with wrong data, caught by the loopback assertion above.
      //                 This assertion additionally catches the "never asserts"
      //                 case that the v1 implication missed when rx_valid=0.
      //---------------------------------------------------------------------
      if (cycle_cnt == 115) begin
        assert (rx_valid_seen);
      end

    end  // if (!rst)
  end

endmodule

`default_nettype wire
