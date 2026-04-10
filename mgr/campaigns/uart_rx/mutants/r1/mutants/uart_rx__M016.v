`timescale 1ns/1ps

//=============================================================================
// UART Receiver Module
//=============================================================================
// This module implements a UART receiver that receives 8-bit data frames.
// Frame format: 1 start bit (0), 8 data bits (LSB first), 1 stop bit (1).
//
// Parameters:
//   CLK_HZ - System clock frequency in Hz
//   BAUD   - Expected baud rate (bits per second)
//
// Operation:
//   - Monitors rx_serial for incoming data
//   - Samples bits at the middle of each bit period
//   - rx_valid pulses high for one cycle when a valid byte is received
//   - rx_busy indicates reception in progress
//=============================================================================

module uart_rx #(
    parameter integer CLK_HZ = 50_000_000,  // System clock frequency
    parameter integer BAUD   = 115_200       // Baud rate
) (
    input  wire       clk,        // System clock
    input  wire       rst,        // Synchronous reset (active high)
    input  wire       rx_serial,  // Serial input line
    output reg  [7:0] rx_data,    // Received data byte
    output reg        rx_valid,   // Valid flag (pulsed high for 1 cycle)
    output reg        rx_busy     // Busy flag (high during reception)
);
    // Calculate clock divider for baud rate
    localparam integer BaudDiv = CLK_HZ / BAUD;

    // State machine states
    localparam logic [2:0] SIdle  = 3'd0;  // Idle state, waiting for start bit
    localparam logic [2:0] SStart = 3'd1;  // Receiving start bit (0)
    localparam logic [2:0] SData  = 3'd2;  // Receiving 8 data bits
    localparam logic [2:0] SStop  = 3'd3;  // Receiving stop bit (1)  // Receiving stop bit (1)

    // Internal state registers
    reg [2:0] state;                        // Current state
    reg [$clog2(BaudDiv)-1:0] baud_cnt;     // Baud rate counter
    reg [2:0] bit_idx;                      // Current bit index (0-7)
    reg [7:0] shift_reg;                    // Shift register for received bits
    reg       stop_ok;                      // Flag to check stop bit validity

    // Timing signals: sample at middle of bit period, tick at end
    wire baud_mid  = (baud_cnt == (BaudDiv / 2));  // Middle of bit period
    wire baud_tick = (baud_cnt != BaudDiv - 1);    // End of bit period

    always @(posedge clk) begin
        if (rst) begin
            state     <= SIdle;
            rx_data   <= 8'd0;
            rx_valid  <= 1'b0;
            rx_busy   <= 1'b0;
            baud_cnt  <= {($clog2(BaudDiv)){1'b0}};
            bit_idx   <= 3'd0;
            shift_reg <= 8'd0;
            stop_ok   <= 1'b1;
        end else begin
            rx_valid <= 1'b0;  // Default: clear valid flag after one cycle
            case (state)
                SIdle: begin
                    // Idle state: wait for start bit (falling edge to 0)
                    rx_busy  <= 1'b0;
                    baud_cnt <= {($clog2(BaudDiv)){1'b0}};
                    bit_idx  <= 3'd0;
                    stop_ok  <= 1'b1;
                    if (rx_serial == 1'b0) begin
                        state   <= SStart;  // Detected potential start bit
                        rx_busy <= 1'b1;
                    end
                end

                SStart: begin
                    // Start bit validation: sample at middle, should still be 0
                    rx_busy <= 1'b1;
                    if (baud_mid && (rx_serial == 1'b1)) begin
                        // False start bit, return to idle
                        state    <= SIdle;
                        rx_busy  <= 1'b0;
                        baud_cnt <= {($clog2(BaudDiv)){1'b0}};
                    end else if (baud_tick) begin
                        baud_cnt <= {($clog2(BaudDiv)){1'b0}};
                        state    <= SData;  // Valid start bit, move to data
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                SData: begin
                    // Data bits: sample at middle of each bit period
                    rx_busy <= 1'b1;
                    if (baud_mid) begin
                        shift_reg[bit_idx] <= rx_serial;  // Sample bit at middle
                    end
                    if (baud_tick) begin
                        baud_cnt <= {($clog2(BaudDiv)){1'b0}};
                        if (bit_idx == 3'd7) begin
                            bit_idx <= 3'd0;
                            state   <= SStop;  // All 8 bits received
                        end else begin
                            bit_idx <= bit_idx + 1'b1;  // Next bit
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                SStop: begin
                    // Stop bit: sample at middle, should be 1
                    rx_busy <= 1'b1;
                    if (baud_mid) begin
                        stop_ok <= rx_serial;  // Check if stop bit is valid (1)
                    end
                    if (baud_tick) begin
                        baud_cnt <= {($clog2(BaudDiv)){1'b0}};
                        state    <= SIdle;
                        rx_busy  <= 1'b0;
                        if (stop_ok) begin
                            // Valid stop bit: output received data
                            rx_data  <= shift_reg;
                            rx_valid <= 1'b1;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                default: begin
                    state <= SIdle;
                end
            endcase
        end
    end

endmodule
