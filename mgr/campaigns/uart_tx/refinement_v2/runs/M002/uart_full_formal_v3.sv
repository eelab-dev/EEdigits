`default_nettype none

//=============================================================================
// Formal Verification Harness v3 — Mutation-Guided Refinement, Round 3
//=============================================================================

module uart_full_formal_v3;
  localparam int ClkHz   = 100;
  localparam int Baud    = 10;
  localparam int BaudDiv = ClkHz / Baud;

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

  logic       fired;
  logic [7:0] tx_latched;
  integer     phase_cnt;
  logic       active;
  integer     cycle_cnt;
  logic       rx_valid_seen;

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

      if (active && (phase_cnt == (BaudDiv * 10 - 1))) begin
        active <= 1'b0;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (rst) cycle_cnt <= 0;
    else if (fired) cycle_cnt <= cycle_cnt + 1;
  end

  always_ff @(posedge clk) begin
    if (rst) rx_valid_seen <= 1'b0;
    else if (rx_valid) rx_valid_seen <= 1'b1;
  end

  always_ff @(posedge clk) begin
    if ($initstate) assume(rst);
    else assume(!rst);
  end

  always_comb begin
    if (!rst) begin
      cover (tx_busy  == 1'b0);
      cover (tx_busy  == 1'b1);
      cover (rx_busy  == 1'b0);
      cover (rx_busy  == 1'b1);
      cover (rx_valid == 1'b0);
      cover (rx_valid == 1'b1);
      cover (rx_data  == 8'h00);
      cover (rx_data  == 8'hA5);

      if (rx_valid) begin
        assert (rx_busy == 1'b0);
        assert (rx_data == tx_latched);
      end

      if (!fired) begin
        assert (tx_serial == 1'b1);
        assert (tx_busy   == 1'b0);
      end

      if (active && phase_cnt >= 1 && phase_cnt < BaudDiv * 10 - 1) begin
        assert (tx_busy == 1'b1);
      end

      if (active && phase_cnt >= 0 && phase_cnt < BaudDiv) begin
        assert (tx_serial == 1'b0);
      end

      if (active && phase_cnt == BaudDiv * 1 + BaudDiv / 2 - 1) assert (tx_serial == tx_latched[0]);
      if (active && phase_cnt == BaudDiv * 2 + BaudDiv / 2 - 1) assert (tx_serial == tx_latched[1]);
      if (active && phase_cnt == BaudDiv * 3 + BaudDiv / 2 - 1) assert (tx_serial == tx_latched[2]);
      if (active && phase_cnt == BaudDiv * 4 + BaudDiv / 2 - 1) assert (tx_serial == tx_latched[3]);
      if (active && phase_cnt == BaudDiv * 5 + BaudDiv / 2 - 1) assert (tx_serial == tx_latched[4]);
      if (active && phase_cnt == BaudDiv * 6 + BaudDiv / 2 - 1) assert (tx_serial == tx_latched[5]);
      if (active && phase_cnt == BaudDiv * 7 + BaudDiv / 2 - 1) assert (tx_serial == tx_latched[6]);
      if (active && phase_cnt == BaudDiv * 8 + BaudDiv / 2 - 1) assert (tx_serial == tx_latched[7]);

      if (active && phase_cnt >= BaudDiv * 9 + 1 && phase_cnt < BaudDiv * 10 - 1) begin
        assert (tx_serial == 1'b1);
      end

      if (fired && !active) begin
        assert (tx_busy   == 1'b0);
        assert (tx_serial == 1'b1);
      end

      if (cycle_cnt == 115) begin
        assert (rx_valid_seen);
      end
    end
  end

endmodule

`default_nettype wire
