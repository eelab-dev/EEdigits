`default_nettype none

//=============================================================================
// Formal Verification Harness for UART Transmitter
//=============================================================================
// This harness verifies the correctness of uart_tx using formal methods.
//
// Verification strategy:
//   1. Generate a single TX start pulse after reset
//   2. Track the expected bit sequence (start, 8 data bits, stop)
//   3. Assert that tx_serial matches expected bits at sample points
//   4. Verify tx_busy flag behavior throughout transmission
//
// Uses reduced clock and baud parameters for faster verification.
//=============================================================================

module uart_tx_formal;
  // Reduced parameters for faster formal verification
  localparam int ClkHz = 100;              // Clock frequency
  localparam int Baud = 10;                // Baud rate (10 bits per 100 clocks)
  localparam int BaudDiv = ClkHz / Baud;   // Clock cycles per bit = 10
  localparam int SampleOffset = (BaudDiv / 2);  // Sample at middle of bit

  // Clock and reset
  (* gclk *) logic clk;  // Global clock for formal verification
  logic rst;

  // DUT inputs and outputs
  (* anyseq *) logic [7:0] tx_data;  // Arbitrary data for symbolic execution
  wire tx_start;   // Start signal (derived from fired flag)
  wire tx_busy;    // Busy output from DUT
  wire tx_serial;  // Serial output from DUT

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

  //===========================================================================
  // Verification State Tracking
  //===========================================================================
  logic [7:0] tx_latched;  // Latched copy of tx_data to compare against
  integer phase_cnt;       // Phase counter: tracks cycle within transmission
  logic active;            // Indicates transmission in progress
  logic fired;             // Indicates start pulse has been sent

  //===========================================================================
  // Expected Bit Function
  //===========================================================================
  // Returns the expected bit value for each position in the UART frame:
  //   idx 0:    Start bit (0)
  //   idx 1-8:  Data bits (LSB first)
  //   idx 9:    Stop bit (1)
  function automatic logic expected_bit(input integer idx);
    if (idx == 0) begin
      expected_bit = 1'b0;  // Start bit
    end else if (idx >= 1 && idx <= 8) begin
      expected_bit = tx_latched[idx - 1];  // Data bits (LSB first)
    end else begin
      expected_bit = 1'b1;  // Stop bit
    end
  endfunction

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
      tx_latched <= 8'd0;
      phase_cnt <= 0;
      active <= 1'b0;
      fired <= 1'b0;
    end else begin
      // Generate a single start pulse on the first cycle after reset
      if (!fired) begin
        fired <= 1'b1;          // Mark that start has been issued
        tx_latched <= tx_data;  // Latch the data to verify against
        phase_cnt <= -1;        // Initialize phase counter
        active <= 1'b1;         // Mark transmission as active
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
    integer phase_cnt_adj_local;
    integer sample_idx_local;

    phase_cnt_adj_local = phase_cnt + 1;
    sample_idx_local = 0;

    if (!rst) begin
      // Coverage points: verify all signal states are reachable
      cover (tx_start == 1'b0);
      cover (tx_start == 1'b1);
      cover (tx_busy == 1'b0);
      cover (tx_busy == 1'b1);
      cover (tx_serial == 1'b0);
      cover (tx_serial == 1'b1);
      cover (tx_data == 8'h00);  // Test with all zeros
      cover (tx_data == 8'hA5);  // Test with alternating bits  // Test with alternating bits

      // Assertions: verify behavior
      assert (tx_start == (!rst && !fired));  // tx_start only high on first cycle
      if (!fired) begin
        assert (tx_busy == 1'b0);  // Not busy before transmission starts
      end
      if (active && (phase_cnt != (BaudDiv * 10 - 1))) begin
        assert (tx_busy == 1'b1);  // Busy throughout active transmission
      end
    end

    // Verify correct bit values at sample points
    if (!rst && active) begin
      // Check if we're at a sample point (middle of each bit period)
      if ((phase_cnt_adj_local >= SampleOffset) &&
          (((phase_cnt_adj_local - SampleOffset) % BaudDiv) == 0)) begin
        // Calculate which bit we're sampling
        sample_idx_local = (phase_cnt_adj_local - SampleOffset) / BaudDiv;
        if (sample_idx_local <= 9) begin
          // Assert that tx_serial matches expected bit value
          assert (tx_serial == expected_bit(sample_idx_local));
          // Coverage: verify start and stop bits are transmitted
          if (sample_idx_local == 0) begin
            cover (tx_serial == 1'b0);  // Start bit
          end
          if (sample_idx_local == 9) begin
            cover (tx_serial == 1'b1);  // Stop bit
          end
        end
      end
    end
  end
endmodule

`default_nettype wire
