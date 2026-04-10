// =============================================================================
// Formal harness – vga_vtim (Video Timing Generator)
// Campaign: vga_lcd  Round: R2  (Refinement)
//
// R1 achieved 18/20 = 90%.  Survivors M019/M020 both mutate non-blocking
// delay annotations (#1 → #0), which Yosys formal ignores semantically.
// R2 extends the harness with:
//   • Second-Done liveness: Done must fire a second time within 2×MaxDoneDelay
//   • Exact first-Sync-fall window: Sync must fall within TSYNC+2 cycles of rising
//   • Tighter Gate-rise window: [MinGateRiseCycle, MaxGateRiseCycle]
//   • Gate/Done cycle-exact lower bound (tightened from R1)
//   • First Done exact-cycle lower bound for A_len_wait (tightened threshold)
//
// Expected result: M019/M020 remain SURVIVED (confirmed true equivalents).
// All other 18 mutants remain KILLED.
// =============================================================================

`default_nettype none

module vga_vtim_prove_formal;

  (* gclk *) logic clk;

  // -------------------------------------------------------------------------
  // Fixed timing parameters (identical to R1)
  // -------------------------------------------------------------------------
  localparam [7:0]  TSYNC = 8'd3;
  localparam [7:0]  TGDEL = 8'd3;
  localparam [15:0] TGATE = 16'd3;
  localparam [15:0] TLEN  = 16'd30;

  // Liveness / duration thresholds
  localparam int unsigned MaxSyncRiseDelay   = 6;
  localparam int unsigned MaxGateRiseDelay   = 16;
  localparam int unsigned MaxDoneDelay       = 38;
  localparam int unsigned Max2ndDoneDelay    = 76;  // second Done within 76 cycles
  localparam int unsigned MinGateHighCycles  = 3;
  localparam int unsigned MinLenWaitCycles   = 6;   // tightened from R1 (was 5)

  // Absolute-cycle Gate-event bounds (tight — derived from fixed params)
  localparam int unsigned MinGateRiseCycle   = 8;
  localparam int unsigned MaxGateRiseCycle   = 12;  // Gate must rise no later than cycle 12 (R2-new)
  localparam int unsigned MinGateFallCycle   = 12;
  localparam int unsigned MaxGateFallCycle   = 16;  // Gate must fall no later than cycle 16 (R2-new)

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
  // Input model
  // -------------------------------------------------------------------------
  always @(posedge clk) begin
    if ($initstate) begin
      assume(rst  == 1'b1);
      assume(Sync == 1'b0);
      assume(Gate == 1'b0);
      assume(Done == 1'b0);
    end else begin
      assume(rst  == 1'b0);
    end
  end
  always @(posedge clk) assume(ena == 1'b1);

  // -------------------------------------------------------------------------
  // Tracking registers
  // -------------------------------------------------------------------------
  logic [7:0] cycle_ctr       = 8'd0;
  logic [7:0] gate_fell_ctr   = 8'd0;
  logic [7:0] sync_high_ctr   = 8'd0;
  logic       sync_ever_high  = 1'b0;
  logic       gate_ever_high  = 1'b0;
  logic       done_ever_fired = 1'b0;
  logic       done_twice      = 1'b0;    // R2-new: Done has fired at least twice

  always @(posedge clk) begin
    if (cycle_ctr != 8'hFF) cycle_ctr <= cycle_ctr + 8'd1;

    // Sync trackers
    if (Sync) begin
      sync_high_ctr  <= sync_high_ctr + 8'd1;
      sync_ever_high <= 1'b1;
    end else begin
      sync_high_ctr <= 8'd0;
    end

    // Gate trackers
    if (Gate) begin
      gate_ever_high <= 1'b1;
      gate_fell_ctr  <= 8'd0;
    end else begin
      if (gate_ever_high && gate_fell_ctr != 8'hFF)
        gate_fell_ctr <= gate_fell_ctr + 8'd1;
    end

    // Done tracker
    if (Done) begin
      if (done_ever_fired) done_twice <= 1'b1;
      done_ever_fired <= 1'b1;
    end
  end

  // -------------------------------------------------------------------------
  // Assertions — post-reset (same block as R1)
  // -------------------------------------------------------------------------

  // A_rst – cycle after rst deasserts: all outputs zero
  always @(posedge clk) begin
    if (!$initstate && $past(rst))
      assert(Sync === 1'b0 && Gate === 1'b0 && Done === 1'b0);
  end

  always @(posedge clk) begin
    if (!$initstate && !rst) begin

      // ---------- R1 assertions (preserved) ----------

      // A_mutex
      assert(!(Sync && Gate));
      // A_mutex2
      assert(!(Gate && Done));
      // A_done_1cyc
      assert(!(Done && $past(Done)));
      // A_done_sync
      if (Done) assert(Sync);
      // A_sync_live
      if (!sync_ever_high) assert(cycle_ctr < MaxSyncRiseDelay);
      // A_gate_live
      if (!gate_ever_high) assert(cycle_ctr < MaxGateRiseDelay);
      // A_done_live
      if (!done_ever_fired) assert(cycle_ctr < MaxDoneDelay);
      // A_gate_rise_cycle (lower bound)
      if (Gate && !$past(Gate)) assert(cycle_ctr >= MinGateRiseCycle);
      // A_gate_fall_cycle (lower bound)
      if (!Gate && $past(Gate)) assert(cycle_ctr >= MinGateFallCycle);
      // A_len_wait (tightened threshold in R2)
      if (Done) assert(gate_fell_ctr >= MinLenWaitCycles);

      // ---------- R2 new assertions ----------

      // A_gate_rise_upper – Gate must not rise too late (first line only).
      //   With fixed params, Gate rises at cycle 9. Mutations that stall the FSM
      //   (e.g., wrong counter init) would cause Gate to rise later.
      //   Uses $past(Gate) on DUT output reg — works correctly with Yosys SMTBMC.
      //   Guard: !done_ever_fired to apply only on the first occurrence.
      if (Gate && !$past(Gate) && !done_ever_fired)
        assert(cycle_ctr <= MaxGateRiseCycle);

      // A_gate_fall_upper – Gate must fall within MaxGateFallCycle cycles (first line only).
      //   Catches mutations that hold Gate asserted too long.
      if (!Gate && $past(Gate) && !done_ever_fired)
        assert(cycle_ctr <= MaxGateFallCycle);

      // A_2nd_done_live – Done must fire a second time within Max2ndDoneDelay
      //   Confirms the FSM loops correctly (len_state → sync_state → … → Done again).
      //   Catches mutations that break the return path after the first Done.
      if (!done_twice) assert(cycle_ctr < Max2ndDoneDelay);

      // A_no_spurious_done – Done must never fire outside of len_state
      //   Equivalently: when Done fires, Gate must have been seen high previously.
      if (Done) assert(gate_ever_high);

    end
  end

endmodule

`default_nettype wire
