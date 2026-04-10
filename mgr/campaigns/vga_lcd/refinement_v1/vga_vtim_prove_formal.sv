// =============================================================================
// Formal harness – vga_vtim (Video Timing Generator)
// Campaign: vga_lcd  Round: R1
//
// vga_vtim runs a 5-state one-hot FSM:
//   idle → sync_state → gdel_state → gate_state → len_state → (sync_state…)
//
// Outputs:
//   Sync  – high during sync_state (and simultaneously with Done at line end)
//   Gate  – high during gate_state
//   Done  – pulses for exactly 1 cycle when len_state wraps back to sync_state
//
// Strategy: fix all timing parameters to small, concrete values so the FSM
// completes one full line (~32 cycles) and a second line (~62 cycles) within
// BMC depth 70.  This lets us assert both safety invariants and bounded
// liveness properties that kill mutants across all 5 code regions.
//
// Mutant coverage (expected kills):
//   M001 – rst pred inv     → A_sync_live (Sync never rises)
//   M002 – ena pred inv     → A_sync_live (FSM frozen)
//   M003 – sync cnt_done    → A_sync_dur  (Sync too short)
//   M004 – gdel cnt_done    → A_gate_live (Gate delayed)
//   M005 – gate cnt_done    → A_gate_dur  (Gate too short)
//   M006 – len  cnt_len_done→ A_len_wait  (Done too soon after Gate)
//   M007 – cnt_nxt lit flip → A_sync_dur  (cnt_done always 1 → Sync 1 cycle)
//   M008 – cnt_len_nxt flip → A_len_wait  (cnt_len_done always 1 → Done 1 cycle after Gate)
//   M009 – Sync:=1 in rst   → A_rst       (Sync=1 during rst)
//   M010 – Gate:=1 in rst   → A_rst       (Gate=1 during rst)
//   M011 – Done:=1 in rst   → A_rst       (Done=1 during rst)
//   M012 – Done default 1   → A_done_1cyc (Done stays high)
//   M013 – Sync not set idle→ A_sync_live (Sync never rises in first line)
//   M014 – Sync not clr sync→ A_mutex     (Sync∧Gate simultaneously high)
//   M015 – Gate not set gdel→ A_gate_live (Gate never rises)
//   M016 – Gate not clr gate→ A_mutex2    (Gate∧Done simultaneously high)
//   M017 – Sync not set len → A_done_sync (Done fires without Sync)
//   M018 – Done not set len → A_done_live (Done never fires)
//   M019 – wrong reset state→ A_gate_live / A_sync_live
//   M020 – wrong idle→next  → A_gate_live
// =============================================================================

`default_nettype none

module vga_vtim_prove_formal;

  (* gclk *) logic clk;

  // -------------------------------------------------------------------------
  // Fixed timing parameters
  //   TSYNC=3  → Sync high for 4 cycles (posedges 1-4)
  //   TGDEL=3  → gdel phase  4 cycles
  //   TGATE=3  → Gate high for 4 cycles (posedges 9-12)
  //   TLEN=30  → Done fires at posedge ~32, again at ~62 (both in depth 70)
  // -------------------------------------------------------------------------
  localparam [7:0]  TSYNC = 8'd3;
  localparam [7:0]  TGDEL = 8'd3;
  localparam [15:0] TGATE = 16'd3;
  localparam [15:0] TLEN  = 16'd30;

  // Liveness / duration thresholds (all derived from params above)
  localparam int unsigned MaxSyncRiseDelay  = 6;  // Sync must rise within 6 cycles
  localparam int unsigned MaxGateRiseDelay  = 16; // Gate must rise within 16 cycles
  localparam int unsigned MaxDoneDelay      = 38; // Done must fire within 38 cycles
  localparam int unsigned MinSyncHighCycles = 3;  // Sync must stay high ≥ 3 cycles
  localparam int unsigned MinGateHighCycles = 3;  // Gate must stay high ≥ 3 cycles
  localparam int unsigned MinLenWaitCycles  = 5;  // Done must wait ≥ 5 cycles after Gate falls
  // Absolute-cycle lower bounds for Gate events (fixed params make these exact)
  //   Baseline: Gate rises posedge 9 (cycle_ctr=9), falls posedge 13 (cycle_ctr=13)
  //   Measured as saturating cycle_ctr value when the event occurs.
  localparam int unsigned MinGateRiseCycle  = 8;  // Gate must not rise before cycle 8
  localparam int unsigned MinGateFallCycle  = 12; // Gate must not fall before cycle 12

  // -------------------------------------------------------------------------
  // DUT
  // -------------------------------------------------------------------------
  logic rst;
  logic ena;
  wire  Sync;
  wire  Gate;
  wire  Done;

  vga_vtim dut (
    .clk   (clk),
    .ena   (ena),
    .rst   (rst),
    .Tsync (TSYNC),
    .Tgdel (TGDEL),
    .Tgate (TGATE),
    .Tlen  (TLEN),
    .Sync  (Sync),
    .Gate  (Gate),
    .Done  (Done)
  );

  // -------------------------------------------------------------------------
  // Input model:
  //   rst = 1 on first clock, then 0 forever
  //   ena = 1 always  (simplifies timing analysis)
  // -------------------------------------------------------------------------
  always @(posedge clk) begin
    if ($initstate) begin
      assume(rst  == 1'b1);
      // Constrain DUT's initial register values to match synchronous-reset state,
      // preventing spurious $past(Gate/Sync/Done)=1 at step 1.
      assume(Sync == 1'b0);
      assume(Gate == 1'b0);
      assume(Done == 1'b0);
    end else begin
      assume(rst  == 1'b0);
    end
  end
  always @(posedge clk) assume(ena == 1'b1);

  // -------------------------------------------------------------------------
  // Tracking registers (initialized by declaration; $initstate sets rst=1)
  // -------------------------------------------------------------------------
  logic [7:0] cycle_ctr      = 8'd0;  // saturating total-cycle counter
  logic [7:0] sync_high_ctr  = 8'd0;  // consecutive cycles Sync is high
  logic [7:0] gate_high_ctr  = 8'd0;  // consecutive cycles Gate is high
  logic [7:0] gate_fell_ctr  = 8'd0;  // cycles since Gate last fell
  logic       sync_ever_high = 1'b0;  // Sync has been observed high at least once
  logic       gate_ever_high = 1'b0;  // Gate has been observed high at least once
  logic       done_ever_fired = 1'b0; // Done has been observed at least once

  always @(posedge clk) begin
    // Saturating cycle counter
    if (cycle_ctr != 8'hFF)
      cycle_ctr <= cycle_ctr + 8'd1;

    // Sync duration tracker
    if (Sync) begin
      sync_high_ctr  <= sync_high_ctr + 8'd1;
      sync_ever_high <= 1'b1;
    end else begin
      sync_high_ctr <= 8'd0;
    end

    // Gate duration and post-fall counter
    if (Gate) begin
      gate_high_ctr  <= gate_high_ctr + 8'd1;
      gate_ever_high <= 1'b1;
      gate_fell_ctr  <= 8'd0;       // reset when Gate is high
    end else begin
      gate_high_ctr <= 8'd0;
      if (gate_ever_high && gate_fell_ctr != 8'hFF)
        gate_fell_ctr <= gate_fell_ctr + 8'd1;
    end

    // Done ever-fired flag
    if (Done) done_ever_fired <= 1'b1;
  end

  // -------------------------------------------------------------------------
  // Assertions
  // -------------------------------------------------------------------------
  // A_rst – The cycle immediately after rst=1, all outputs must be zero.
  //         Catches M009/M010/M011 (reset assignments flipped to 1).
  //         Uses $past(rst) so it fires at step 1 when rst just deasserted.
  always @(posedge clk) begin
    if (!$initstate && $past(rst))
      assert(Sync === 1'b0 && Gate === 1'b0 && Done === 1'b0);
  end

  always @(posedge clk) begin
    if (!$initstate && !rst) begin

      // A_mutex – Sync and Gate must never be simultaneously high
      //           Catches M014 (Sync not cleared on sync→gdel transition)
      assert(!(Sync && Gate));

      // A_mutex2 – Gate and Done must never fire simultaneously
      //            Catches M016 (Gate not cleared on gate→len transition)
      assert(!(Gate && Done));

      // A_done_1cyc – Done is a one-cycle pulse; never high two cycles in a row
      //               Catches M012 (Done default assignment flipped to 1)
      assert(!(Done && $past(Done)));

      // A_done_sync – When Done fires, Sync must also fire (len_state sets both)
      //               Catches M017 (Sync not set in len→sync transition)
      if (Done) assert(Sync);

      // A_sync_live – Sync must rise within MaxSyncRiseDelay cycles
      //               Catches M001 (rst inv), M002 (ena inv), M013 (Sync not set in idle)
      if (!sync_ever_high)
        assert(cycle_ctr < MaxSyncRiseDelay);

      // A_gate_live – Gate must rise within MaxGateRiseDelay cycles
      //               Catches M004 (gdel cnt_done inv), M015 (Gate not set),
      //               M019 (wrong reset state), M020 (wrong idle→next state)
      if (!gate_ever_high)
        assert(cycle_ctr < MaxGateRiseDelay);

      // A_done_live – Done must fire within MaxDoneDelay cycles
      //               Catches M018 (Done not set in len_state)
      if (!done_ever_fired)
        assert(cycle_ctr < MaxDoneDelay);

      // A_sync_dur – When Sync falls after a real high period, it must have been
      //              high for ≥ MinSyncHighCycles cycles.
      //              Guard: $past(sync_high_ctr)>0 rules out spurious step-0 transitions.
      //              Catches M003 (sync exits on !cnt_done → exits after 1 cycle)
      //              Catches M007 (cnt_nxt lit flip → cnt_done always 1 → 1-cycle Sync)
      if (!Sync && $past(Sync) && $past(sync_high_ctr) > 0)
        assert($past(sync_high_ctr) >= MinSyncHighCycles);

      // A_gate_dur – When Gate falls after a real high period, it must have been
      //              high for ≥ MinGateHighCycles cycles.
      //              Catches M005 (gate exits on !cnt_done → exits after 1 cycle)
      if (!Gate && $past(Gate) && $past(gate_high_ctr) > 0)
        assert($past(gate_high_ctr) >= MinGateHighCycles);

      // A_gate_rise_cycle – Gate must not rise before MinGateRiseCycle absolute cycles.
      //   With fixed params, Gate rises at cycle 9 in the baseline; catching it before
      //   cycle 8 means the sync or gdel phase was too short.
      //   Catches M003 (sync exits early → Gate rises at cycle 6)
      //   Catches M004 (gdel exits early → Gate rises at cycle 3)
      //   Catches M007 (cnt_done always 1 → Gate rises at cycle 3)
      //   Uses $past(Gate) of DUT output reg — works correctly with Yosys SMTBMC.
      if (Gate && !$past(Gate))
        assert(cycle_ctr >= MinGateRiseCycle);

      // A_gate_fall_cycle – Gate must not fall before MinGateFallCycle absolute cycles.
      //   Gate falls at cycle 13 in baseline; earlier fall means gate phase was too short.
      //   Catches M005 (gate exits on !cnt_done → Gate falls at cycle 10)
      if (!Gate && $past(Gate))
        assert(cycle_ctr >= MinGateFallCycle);

      // A_len_wait – Done must not fire until ≥ MinLenWaitCycles after Gate last fell
      //              Catches M006 (len exits on !cnt_len_done → immediate Done)
      //              Catches M008 (cnt_len_nxt lit flip → cnt_len_done always 1)
      if (Done)
        assert(gate_fell_ctr >= MinLenWaitCycles);

    end
  end

endmodule

`default_nettype wire
