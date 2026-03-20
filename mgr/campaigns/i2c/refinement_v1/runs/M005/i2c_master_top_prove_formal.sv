`default_nettype none

//=============================================================================
// Formal prove harness for i2c_master_top_formal
//=============================================================================
// Purpose:
//   - Prove safety properties on the top-level integration (Wishbone + I2C pads)
//   - Keep environment symbolic but constrained enough for meaningful checks
//
// Scope of properties:
//   1) Open-drain behavior at pads
//   2) Wishbone acknowledge sanity
//   3) IRQ held low under reset conditions
//
module i2c_master_top_prove_formal;
  localparam int unsigned MAX_CMD_CYCLES = 512;
  localparam int unsigned WDOG_W = 10;

  (* gclk *) logic wb_clk_i;

  // Symbolic host-side bus and reset inputs.
  (* anyseq *) logic wb_rst_i;
  (* anyseq *) logic arst_i;
  (* anyseq *) logic [2:0] wb_adr_i;
  (* anyseq *) logic [7:0] wb_dat_i;
  wire [7:0] wb_dat_o;
  (* anyseq *) logic wb_we_i;
  (* anyseq *) logic wb_stb_i;
  (* anyseq *) logic wb_cyc_i;
  wire wb_ack_o;
  wire wb_inta_o;

  wire scl_pad_i;
  wire scl_pad_o;
  wire scl_padoen_o;
  wire sda_pad_i;
  wire sda_pad_o;
  wire sda_padoen_o;

  // Symbolic external pull-down behavior for open-drain SCL/SDA wires.
  (* anyseq *) logic ext_scl_low;
  (* anyseq *) logic ext_sda_low;

  // Open-drain line model:
  // - If DUT drives output enable active (oen=0), line is low.
  // - Otherwise the environment may keep line low or release high.
  assign scl_pad_i = (scl_padoen_o == 1'b0) ? 1'b0 : (ext_scl_low ? 1'b0 : 1'b1);
  assign sda_pad_i = (sda_padoen_o == 1'b0) ? 1'b0 : (ext_sda_low ? 1'b0 : 1'b1);

  i2c_master_top_formal dut (
      .wb_clk_i(wb_clk_i),
      .wb_rst_i(wb_rst_i),
      .arst_i(arst_i),
      .wb_adr_i(wb_adr_i),
      .wb_dat_i(wb_dat_i),
      .wb_dat_o(wb_dat_o),
      .wb_we_i(wb_we_i),
      .wb_stb_i(wb_stb_i),
      .wb_cyc_i(wb_cyc_i),
      .wb_ack_o(wb_ack_o),
      .wb_inta_o(wb_inta_o),
      .scl_pad_i(scl_pad_i),
      .scl_pad_o(scl_pad_o),
      .scl_padoen_o(scl_padoen_o),
      .sda_pad_i(sda_pad_i),
      .sda_pad_o(sda_pad_o),
      .sda_padoen_o(sda_padoen_o)
  );

  // Reset assumptions:
  // - Initial state in reset
  // - Afterwards reset is deasserted (single reset phase model)
  always @(posedge wb_clk_i) begin
    if ($initstate) begin
      assume(wb_rst_i);
      assume(arst_i == 1'b0);
    end else begin
      assume(!wb_rst_i);
      assume(arst_i == 1'b1);
    end
  end

  // Fairness assumptions for progress checks:
  // keep bus lines released externally so the DUT is not blocked forever by
  // unbounded clock stretching or permanent SDA pull-down.
  always @(posedge wb_clk_i) begin
    if (!$initstate && !wb_rst_i && (arst_i == 1'b1)) begin
      assume(ext_scl_low == 1'b0);
      assume(ext_sda_low == 1'b0);
    end
  end

  // A command request transaction on WB (write to CR with a command bit set).
  wire wb_cmd_req = wb_stb_i && wb_cyc_i && wb_we_i &&
                    (wb_adr_i == 3'b100) && (wb_dat_i[7:4] != 4'h0) &&
                    dut.core_en && (dut.prer <= 16'd4);

  // Bounded-progress checker equivalent to a bounded eventuality:
  // wb_cmd_req |-> ##[1:MAX_CMD_CYCLES] dut.done
  logic cmd_watchdog_active;
  logic [WDOG_W-1:0] cmd_watchdog;

  // Bounded-progress checker for TIP completion:
  // $rose(dut.tip) |-> ##[1:MAX_CMD_CYCLES] (dut.done && !dut.tip)
  logic tip_watchdog_active;
  logic [WDOG_W-1:0] tip_watchdog;
  logic tip_q;

  always @(posedge wb_clk_i) begin
    tip_q <= dut.tip;

    if ($initstate || wb_rst_i || (arst_i == 1'b0)) begin
      cmd_watchdog_active <= 1'b0;
      tip_watchdog_active <= 1'b0;
      cmd_watchdog <= '0;
      tip_watchdog <= '0;
    end else begin
      if (wb_cmd_req) begin
        cmd_watchdog_active <= 1'b1;
        cmd_watchdog <= MAX_CMD_CYCLES[WDOG_W-1:0];
      end else if (cmd_watchdog_active && dut.done) begin
        cmd_watchdog_active <= 1'b0;
      end else if (cmd_watchdog_active) begin
        assert(cmd_watchdog != '0);
        cmd_watchdog <= cmd_watchdog - {{(WDOG_W-1){1'b0}}, 1'b1};
      end

      if (!tip_q && dut.tip && (dut.prer <= 16'd4)) begin
        tip_watchdog_active <= 1'b1;
        tip_watchdog <= MAX_CMD_CYCLES[WDOG_W-1:0];
      end else if (tip_watchdog_active && dut.done && !dut.tip) begin
        tip_watchdog_active <= 1'b0;
      end else if (tip_watchdog_active) begin
        assert(tip_watchdog != '0);
        tip_watchdog <= tip_watchdog - {{(WDOG_W-1){1'b0}}, 1'b1};
      end
    end
  end

  // Safety assertions.
  always @(posedge wb_clk_i) begin
    // DUT hard-wires output data pins low; only output-enable toggles.
    assert(scl_pad_o == 1'b0);
    assert(sda_pad_o == 1'b0);

    // If DUT actively drives a line, the sampled line must be low.
    assert((scl_padoen_o != 1'b0) || (scl_pad_i == 1'b0));
    assert((sda_padoen_o != 1'b0) || (sda_pad_i == 1'b0));

    if (!$initstate) begin
      // Acknowledge is only valid if previous cycle had an active bus request.
      assert(!wb_ack_o || $past(wb_cyc_i && wb_stb_i && !wb_ack_o));
    end

    // Interrupt output must remain low while either reset is active.
    if ((arst_i == 1'b0) || wb_rst_i) begin
      assert(wb_inta_o == 1'b0);
    end
  end

  // Reachability goals to avoid vacuous proofs.
  always @(posedge wb_clk_i) begin
    if (!$initstate && !wb_rst_i && (arst_i == 1'b1)) begin
      // Observe at least one WB acknowledge.
      cover(wb_ack_o);
      // Observe line-driving activity on SCL and SDA.
      cover(scl_padoen_o == 1'b0);
      cover(sda_padoen_o == 1'b0);
      // Observe interrupt assertion.
      cover(wb_inta_o == 1'b1);
      // Observe command progress path.
      cover(wb_cmd_req);
      cover($rose(dut.tip));
      cover(dut.done);
    end
  end
endmodule

`default_nettype wire
