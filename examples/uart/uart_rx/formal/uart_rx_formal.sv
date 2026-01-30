`default_nettype none

// Formal harness for uart_rx.
module uart_rx_formal;
  localparam int ClkHz = 100;
  localparam int Baud = 10;
  localparam int BaudDiv = ClkHz / Baud;

  (* gclk *) logic clk;
  logic rst;

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

  logic [7:0] rx_latched;
  integer phase_cnt;
  logic active;
  logic fired;

  function automatic logic expected_bit(input integer idx);
    if (idx == 0) begin
      expected_bit = 1'b0; // start bit
    end else if (idx >= 1 && idx <= 8) begin
      expected_bit = rx_latched[idx - 1];
    end else begin
      expected_bit = 1'b1; // stop bit
    end
  endfunction

  always_ff @(posedge clk) begin
    if ($initstate) begin
      assume(rst);
    end else begin
      assume(!rst);
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      rx_latched <= 8'd0;
      phase_cnt <= 0;
      active <= 1'b0;
      fired <= 1'b0;
    end else begin
      if (!fired) begin
        fired <= 1'b1;
        rx_latched <= rx_payload;
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
    integer bit_idx;
    integer phase_cnt_adj;
    rx_serial = 1'b1;
    bit_idx = 0;
    phase_cnt_adj = phase_cnt + 1;
    if (active && (phase_cnt_adj >= 1)) begin
      bit_idx = (phase_cnt_adj - 1) / BaudDiv;
      rx_serial = expected_bit(bit_idx);
    end
  end

  always_comb begin
    integer phase_cnt_adj;
    integer last_phase;
    phase_cnt_adj = phase_cnt + 1;
    last_phase = (BaudDiv * 10);
    if (!rst) begin
      cover (rx_valid == 1'b0);
      cover (rx_valid == 1'b1);
      cover (rx_busy == 1'b0);
      cover (rx_busy == 1'b1);
      cover (rx_data == 8'h00);
      cover (rx_data == 8'hA5);

      if (!fired) begin
        assert (rx_busy == 1'b0);
      end
      if (rx_valid) begin
        assert (rx_busy == 1'b0);
        assert (rx_data == rx_latched);
      end
    end
  end
endmodule

`default_nettype wire
