`default_nettype none

//=============================================================================
// Formal Verification Harness for UART Receiver — Refinement v1
//=============================================================================
// MGR R2 addition: assert that rx_data equals the transmitted payload when
// rx_valid fires.  The baseline harness only checked port-level protocol
// (busy/valid timing), allowing all data-path mutations to survive.
//=============================================================================

module uart_rx_formal;
  // Reduced parameters for faster formal verification
  localparam int ClkHz = 100;
  localparam int Baud = 10;
  localparam int BaudDiv = ClkHz / Baud;
  localparam int FrameBits = 10;  // start + 8 data + stop
  localparam int TotalCycles = BaudDiv * FrameBits;

  // Clock and reset
  (* gclk *) logic clk;
  logic rst;

  // Test stimulus and DUT signals
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
  logic active;
  logic fired;
  logic [$clog2(TotalCycles)-1:0] phase;

  function automatic logic expected_bit(input logic [3:0] idx);
    if (idx == 4'd0) begin
      expected_bit = 1'b0;
    end else if (idx >= 4'd1 && idx <= 4'd8) begin
      expected_bit = rx_latched[idx - 4'd1];
    end else begin
      expected_bit = 1'b1;
    end
  endfunction

  always_ff @(posedge clk) begin
    if ($initstate) begin
      assume(rst);
    end else begin
      assume(!rst);
    end
  end

  // Generate exactly one framed transmission in the harness.
  always_ff @(posedge clk) begin
    if (rst) begin
      rx_latched <= 8'd0;
      active <= 1'b0;
      fired <= 1'b0;
      phase <= '0;
    end else begin
      if (!fired) begin
        fired <= 1'b1;
        active <= 1'b1;
        rx_latched <= rx_payload;
        phase <= '0;
      end else if (active) begin
        if (phase == TotalCycles - 1) begin
          active <= 1'b0;
        end else begin
          phase <= phase + 1'b1;
        end
      end
    end
  end

  // Deterministic line driver: start, 8 data bits (LSB-first), stop.
  always_comb begin
    logic [3:0] bit_idx;
    rx_serial = 1'b1;
    bit_idx = 4'd0;
    if (active) begin
      bit_idx = phase / BaudDiv;
      rx_serial = expected_bit(bit_idx);
    end
  end

  always_ff @(posedge clk) begin
    if (!rst) begin
      // Sanity: before frame launch, DUT must not be busy.
      if (!fired) begin
        assert(!rx_busy);
      end

      // Output protocol: valid implies not busy.
      if (rx_valid) begin
        assert(!rx_busy);
      end

      // Valid should be a one-cycle pulse.
      if (!$initstate && $past(rx_valid)) begin
        assert(!rx_valid);
      end

      // ---------------------------------------------------------------
      // MGR R2: Core data integrity assertion.
      // When the DUT signals rx_valid, the received byte must match the
      // payload that was transmitted on rx_serial.  This assertion kills
      // any mutant that corrupts bit sampling, bit ordering, or counter
      // boundaries.
      // ---------------------------------------------------------------
      if (rx_valid) begin
        assert(rx_data == rx_latched);
      end

      // Reachability guards against vacuous proofs.
      cover(active);
      cover(rx_busy);
      cover(rx_valid);
    end
  end
endmodule

`default_nettype wire
