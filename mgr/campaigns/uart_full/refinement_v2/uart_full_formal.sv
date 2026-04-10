`default_nettype none

//=============================================================================
// Formal Verification Harness for Full-Duplex UART — Refinement v2
//=============================================================================
// New assertions vs. baseline:
//   R2-A  Liveness    — rx_valid must fire within BaudDiv*12 cycles of tx_start
//   R2-B  TX busy     — tx_busy must be 1 during mid-frame (cycles 2..BaudDiv*10-2)
//   R2-C  TX idle hi  — tx_serial must be 1 after BaudDiv*10+3 cycles (idle state)
//   R2-D  TX busy lo  — tx_busy must be 0  after BaudDiv*10+3 cycles (idle state)
//
// Design: phase_cnt starts at 1 when fired, saturates at BaudDiv*15.
// No 'active' flag — avoids off-by-one between harness counter and UART internals.
//=============================================================================

module uart_full_formal;
  // Reduced parameters for faster formal verification
  localparam int ClkHz = 100;              // Clock frequency
  localparam int Baud  = 10;               // Baud rate
  localparam int BaudDiv = ClkHz / Baud;   // Clock cycles per bit = 10

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

  //===========================================================================
  // Harness tracking state
  //===========================================================================
  logic       fired;       // tx_start has been pulsed
  logic [7:0] tx_latched;  // copy of tx_payload at the moment of tx_start
  // phase_cnt: counts up from 1 once fired; saturates at BaudDiv*15.
  // Starts at 1 (not -1) so all comparisons are straightforward unsigned.
  logic [7:0] phase_cnt;
  logic       seen_valid;  // R2-A: latched once rx_valid ever fires

  assign tx_start = (!rst) && !fired;

  //===========================================================================
  // Reset assumptions
  //===========================================================================
  always_ff @(posedge clk) begin
    if ($initstate) assume(rst);
    else            assume(!rst);
  end

  //===========================================================================
  // Tracking logic
  //===========================================================================
  always_ff @(posedge clk) begin
    if (rst) begin
      fired      <= 1'b0;
      tx_latched <= 8'd0;
      phase_cnt  <= 8'd0;
      seen_valid <= 1'b0;
    end else begin
      // Latch rx_valid occurrence (R2-A)
      if (rx_valid) seen_valid <= 1'b1;

      if (!fired) begin
        fired      <= 1'b1;
        tx_latched <= tx_payload;
        phase_cnt  <= 8'd1;   // starts counting from 1
      end else if (phase_cnt < BaudDiv * 15) begin
        phase_cnt <= phase_cnt + 8'd1;   // saturate so it doesn't wrap
      end
    end
  end

  //===========================================================================
  // Assertions and coverage
  //===========================================================================
  always_comb begin
    if (!rst) begin
      // Coverage
      cover (tx_start == 1'b0);
      cover (tx_start == 1'b1);
      cover (tx_busy  == 1'b0);
      cover (tx_busy  == 1'b1);
      cover (rx_busy  == 1'b0);
      cover (rx_busy  == 1'b1);
      cover (rx_valid == 1'b0);
      cover (rx_valid == 1'b1);
      cover (rx_data  == 8'h00);
      cover (rx_data  == 8'hA5);

      // Baseline: data integrity on rx_valid
      if (rx_valid) begin
        assert (rx_busy == 1'b0);
        assert (rx_data == tx_latched);
      end

      // R2-A  Liveness: rx_valid must have fired by BaudDiv*12 cycles after tx_start
      if (phase_cnt >= BaudDiv * 12)
        assert (seen_valid);

      // R2-B  TX busy during mid-frame: phase 2 to BaudDiv*10-2 (safe inner window)
      if (phase_cnt >= 2 && phase_cnt <= BaudDiv * 10 - 2)
        assert (tx_busy);

      // R2-C  TX serial idle: after BaudDiv*10+3 cycles, the line must be high
      if (phase_cnt > BaudDiv * 10 + 3)
        assert (tx_serial);

      // R2-D  TX busy cleared: after BaudDiv*10+3 cycles, tx_busy must be 0
      if (phase_cnt > BaudDiv * 10 + 3)
        assert (!tx_busy);
    end
  end
endmodule

`default_nettype wire
