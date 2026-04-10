`default_nettype none

//=============================================================================
// Formal Verification Harness for Full-Duplex UART
//=============================================================================
// This harness verifies uart_full by creating a loopback configuration.
//
// Verification strategy:
//   1. Connect tx_serial directly to rx_serial (loopback)
//   2. Send a byte through TX
//   3. Verify RX receives the same byte correctly
//   4. Check that both TX and RX busy flags behave correctly
//
// This tests the integration of uart_tx and uart_rx modules.
// Uses reduced clock and baud parameters for faster verification.
//=============================================================================

module uart_full_formal;
  // Reduced parameters for faster formal verification
  localparam int ClkHz = 100;              // Clock frequency
  localparam int Baud = 10;                // Baud rate
  localparam int BaudDiv = ClkHz / Baud;   // Clock cycles per bit = 10

  // Clock and reset
  (* gclk *) logic clk;  // Global clock for formal verification
  logic rst;

  // Test stimulus and DUT signals
  (* anyseq *) logic [7:0] tx_payload;  // Arbitrary data for symbolic execution
  wire tx_start;    // Start signal (derived from fired flag)
  wire tx_busy;     // TX busy flag from DUT
  wire tx_serial;   // TX serial output from DUT
  wire rx_serial;   // RX serial input to DUT
  wire [7:0] rx_data;  // RX data output from DUT
  wire rx_valid;    // RX valid flag from DUT
  wire rx_busy;     // RX busy flag from DUT

  // Loopback configuration: connect TX output to RX input
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

  //===========================================================================
  // Verification State Tracking
  //===========================================================================
  logic fired;             // Indicates start pulse has been sent
  logic [7:0] tx_latched;  // Latched copy of tx_payload to compare against
  integer phase_cnt;       // Phase counter: tracks cycle within transmission
  logic active;            // Indicates transmission/reception in progress

  // Generate single start pulse on first cycle after reset
  assign tx_start = (!rst) && !fired;

  //===========================================================================
  // Reset Assumptions
  //===========================================================================
  // Ensure reset is active at initialization, then deasserted
  always_ff @(posedge clk) begin
    if ($initstate) begin
      assume(rst);   // Reset must be active initially
    end else begin
      assume(!rst);  // After init, reset is deasserted
    end
  end

  //===========================================================================
  // Transmission Tracking Logic
  //===========================================================================
  // Track transmission progress and latch data for verification
  always_ff @(posedge clk) begin
    if (rst) begin
      fired <= 1'b0;
      tx_latched <= 8'd0;
      phase_cnt <= 0;
      active <= 1'b0;
    end else begin
      if (!fired) begin
        fired <= 1'b1;            // Mark that start has been issued
        tx_latched <= tx_payload;  // Latch the data to verify against
        phase_cnt <= -1;           // Initialize phase counter
        active <= 1'b1;            // Mark transmission as active
      end else if (active) begin
        phase_cnt <= phase_cnt + 1;  // Increment phase through transmission
      end

      // Deactivate after full frame transmission (10 bits)
      if (active && (phase_cnt == (BaudDiv * 10 - 1))) begin
        active <= 1'b0;
      end
    end
  end

  //===========================================================================
  // Formal Verification Assertions and Coverage
  //===========================================================================
  always_comb begin
    if (!rst) begin
      // Coverage points: verify all signal states are reachable
      cover (tx_start == 1'b0);
      cover (tx_start == 1'b1);
      cover (tx_busy == 1'b0);
      cover (tx_busy == 1'b1);
      cover (rx_busy == 1'b0);
      cover (rx_busy == 1'b1);
      cover (rx_valid == 1'b0);
      cover (rx_valid == 1'b1);
      cover (rx_data == 8'h00);  // Test with all zeros
      cover (rx_data == 8'hA5);  // Test with alternating bits

      // Assertions: verify loopback correctness
      if (rx_valid) begin
        assert (rx_busy == 1'b0);  // Not busy when valid
        assert (rx_data == tx_latched);  // Loopback data matches TX data
      end
    end
  end
endmodule

`default_nettype wire
