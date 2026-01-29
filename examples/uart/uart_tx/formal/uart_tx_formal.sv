`default_nettype none

// Formal harness for uart_tx.
module uart_tx_formal;
  localparam int ClkHz = 100;
  localparam int Baud = 10;
  localparam int BaudDiv = ClkHz / Baud;
  localparam int SampleOffset = (BaudDiv / 2);

  (* gclk *) logic clk;
  logic rst;

  (* anyseq *) logic [7:0] tx_data;
  wire tx_start;
  wire tx_busy;
  wire tx_serial;

  uart_tx #(
      .CLK_HZ(ClkHz),
      .BAUD(Baud)
  ) dut (
      .clk(clk),
      .rst(rst),
      .tx_start(tx_start),
      .tx_data(tx_data),
      .tx_busy(tx_busy),
      .tx_serial(tx_serial)
  );


  logic [7:0] tx_latched;
  integer phase_cnt;
  logic active;
  logic fired;

  function automatic logic expected_bit(input integer idx);
    if (idx == 0) begin
      expected_bit = 1'b0; // start bit
    end else if (idx >= 1 && idx <= 8) begin
      expected_bit = tx_latched[idx - 1];
    end else begin
      expected_bit = 1'b1; // stop bit
    end
  endfunction

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
      tx_latched <= 8'd0;
      phase_cnt <= 0;
      active <= 1'b0;
      fired <= 1'b0;
    end else begin
      // Generate a single start pulse on the first cycle after reset.
      if (!fired) begin
        fired <= 1'b1;
        tx_latched <= tx_data;
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
    integer phase_cnt_adj_local;
    integer sample_idx_local;

    phase_cnt_adj_local = phase_cnt + 1;
    sample_idx_local = 0;

    if (!rst) begin
      cover (tx_start == 1'b0);
      cover (tx_start == 1'b1);
      cover (tx_busy == 1'b0);
      cover (tx_busy == 1'b1);
      cover (tx_serial == 1'b0);
      cover (tx_serial == 1'b1);
      cover (tx_data == 8'h00);
      cover (tx_data == 8'hA5);

      assert (tx_start == (!rst && !fired));
      if (!fired) begin
        assert (tx_busy == 1'b0);
      end
      if (active && (phase_cnt != (BaudDiv * 10 - 1))) begin
        assert (tx_busy == 1'b1);
      end
    end

    if (!rst && active) begin
      if ((phase_cnt_adj_local >= SampleOffset) &&
          (((phase_cnt_adj_local - SampleOffset) % BaudDiv) == 0)) begin
        sample_idx_local = (phase_cnt_adj_local - SampleOffset) / BaudDiv;
        if (sample_idx_local <= 9) begin
          assert (tx_serial == expected_bit(sample_idx_local));
          if (sample_idx_local == 0) begin
            cover (tx_serial == 1'b0);
          end
          if (sample_idx_local == 9) begin
            cover (tx_serial == 1'b1);
          end
        end
      end
    end
  end
endmodule

`default_nettype wire
