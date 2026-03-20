`timescale 1ns/1ps

//=============================================================================
// UART Transmitter Module
//=============================================================================
// This module implements a UART transmitter that sends 8-bit data frames.
// Frame format: 1 start bit (0), 8 data bits (LSB first), 1 stop bit (1).
//
// Parameters:
//   CLK_HZ - System clock frequency in Hz
//   BAUD   - Desired baud rate (bits per second)
//
// Operation:
//   - Assert tx_start with tx_data to initiate transmission
//   - tx_busy indicates transmission in progress
//   - tx_serial outputs the serial data stream
//=============================================================================

module uart_tx #(
    parameter integer CLK_HZ = 50_000_000,  // System clock frequency
    parameter integer BAUD   = 115_200       // Baud rate
) (
    input  wire       clk,        // System clock
    input  wire       rst,        // Synchronous reset (active high)
    input  wire       tx_start,   // Start transmission (pulse high)
    input  wire [7:0] tx_data,    // Data byte to transmit
    output reg        tx_busy,    // Busy flag (high during transmission)
    output reg        tx_serial   // Serial output line   // Serial output line
);
    // Calculate clock divider for baud rate generation
    localparam integer BaudDiv = CLK_HZ / BAUD;

    // State machine states
    localparam logic [2:0] SIdle  = 3'd0;  // Idle state, waiting for tx_start
    localparam logic [2:0] SStart = 3'd1;  // Transmitting start bit (0)
    localparam logic [2:0] SData  = 3'd2;  // Transmitting 8 data bits
    localparam logic [2:0] SStop  = 3'd3;  // Transmitting stop bit (1)

    // Internal state registers
    reg [2:0] state;                        // Current state
    reg [$clog2(BaudDiv)-1:0] baud_cnt;     // Baud rate counter
    reg [2:0] bit_idx;                      // Current bit index (0-7)
    reg [7:0] shift_reg;                    // Shift register for data bits

    // Baud tick: asserted when one bit period has elapsed
    wire baud_tick = (baud_cnt == BaudDiv - 1);

    always @(posedge clk) begin
        if (rst) begin
            state     <= SIdle;
            tx_serial <= 1'b1;
            tx_busy   <= 1'b0;
            baud_cnt  <= {($clog2(BaudDiv)){1'b0}};
            bit_idx   <= 3'd0;
            shift_reg <= 8'd0;
        end else begin
            case (state)
                SIdle: begin
                    // Idle state: line high, ready to accept new data
                    tx_serial <= 1'b1;  // Line idles high
                    tx_busy   <= 1'b0;  // Not busy
                    baud_cnt  <= {($clog2(BaudDiv)){1'b0}};
                    bit_idx   <= 3'd0;
                    if (tx_start) begin
                        shift_reg <= tx_data;  // Latch data to transmit
                        tx_busy   <= 1'b0;
                        state     <= SStart;
                    end
                end

                SStart: begin
                    // Start bit: transmit 0 for one bit period
                    tx_serial <= 1'b0;  // Start bit is always 0
                    if (baud_tick) begin
                        baud_cnt <= {($clog2(BaudDiv)){1'b0}};
                        state    <= SData;  // Move to data transmission
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                SData: begin
                    // Data bits: transmit LSB first, shift right each bit period
                    tx_serial <= shift_reg[0];  // Transmit LSB
                    if (baud_tick) begin
                        baud_cnt  <= {($clog2(BaudDiv)){1'b0}};
                        shift_reg <= {1'b0, shift_reg[7:1]};  // Shift right
                        if (bit_idx == 3'd7) begin
                            bit_idx <= 3'd0;
                            state   <= SStop;  // All 8 bits sent, move to stop bit
                        end else begin
                            bit_idx <= bit_idx + 1'b1;  // Next bit
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                SStop: begin
                    // Stop bit: transmit 1 for one bit period, then return to idle
                    tx_serial <= 1'b1;  // Stop bit is always 1
                    if (baud_tick) begin
                        baud_cnt <= {($clog2(BaudDiv)){1'b0}};
                        state    <= SIdle;  // Transmission complete
                        tx_busy  <= 1'b0;   // Ready for next byte
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
