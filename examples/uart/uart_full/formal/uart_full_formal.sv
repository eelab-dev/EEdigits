`default_nettype none

// Formal harness for uart_full.
module uart_full_formal;
  localparam int ClkHz = 100;
  localparam int Baud = 10;
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
      .clk(clk),
      .rst(rst),
      .rx_serial(rx_serial),
      .rx_data(rx_data),
      .rx_valid(rx_valid),
      .rx_busy(rx_busy),
      .tx_start(tx_start),
      .tx_data(tx_payload),
      .tx_busy(tx_busy),
      .tx_serial(tx_serial)
  );

  logic fired;
  logic [7:0] tx_latched;
  integer phase_cnt;
  logic active;

  assign tx_start = (!rst) && !fired;

  always_ff @(posedge clk) begin
    if ($initstate) begin
      assume(rst);
    end else begin
      assume(!rst);
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      fired <= 1'b0;
      tx_latched <= 8'd0;
      phase_cnt <= 0;
      active <= 1'b0;
    end else begin
      if (!fired) begin
        fired <= 1'b1;
        tx_latched <= tx_payload;
        phase_cnt <= -1;
        active <= 1'b1;
      end else if (active) begin
        phase_cnt <= phase_cnt + 1;
      end

      if (active && (phase_cnt == (BaudDiv * 10 - 1))) begin
        active <= 1'b0;
      end
    end
  end

  always_comb begin
    if (!rst) begin
      cover (tx_start == 1'b0);
      cover (tx_start == 1'b1);
      cover (tx_busy == 1'b0);
      cover (tx_busy == 1'b1);
      cover (rx_busy == 1'b0);
      cover (rx_busy == 1'b1);
      cover (rx_valid == 1'b0);
      cover (rx_valid == 1'b1);
      cover (rx_data == 8'h00);
      cover (rx_data == 8'hA5);

      if (rx_valid) begin
        assert (rx_busy == 1'b0);
        assert (rx_data == tx_latched);
      end
    end
  end
endmodule

`default_nettype wire
