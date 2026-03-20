`timescale 1ns/1ps

//=============================================================================
// Full-Duplex UART Module
//=============================================================================
// This module provides a complete UART interface with independent transmit
// and receive channels. It instantiates both uart_tx and uart_rx modules.
//
// Parameters:
//   CLK_HZ - System clock frequency in Hz
//   BAUD   - Baud rate for both TX and RX
//
// Features:
//   - Independent TX and RX channels (full duplex)
//   - Standard 8N1 format (8 data bits, no parity, 1 stop bit)
//   - Separate busy flags for TX and RX operations
//=============================================================================

module uart_full #(
    parameter integer CLK_HZ = 50_000_000,  // System clock frequency
    parameter integer BAUD   = 115_200       // Baud rate
) (
    input  wire       clk,        // System clock
    input  wire       rst,        // Synchronous reset (active high)
    // Receiver interface
    input  wire       rx_serial,  // Serial input line
    output wire [7:0] rx_data,    // Received data byte
    output wire       rx_valid,   // Valid flag (pulsed high for 1 cycle)
    output wire       rx_busy,    // RX busy flag
    // Transmitter interface
    input  wire       tx_start,   // Start transmission
    input  wire [7:0] tx_data,    // Data byte to transmit
    output wire       tx_busy,    // TX busy flag
    output wire       tx_serial   // Serial output line   // Serial output line
);

    //=========================================================================
    // UART Transmitter Instance
    //=========================================================================
    uart_tx #(
        .CLK_HZ(CLK_HZ),
        .BAUD(BAUD)
    ) u_uart_tx (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_busy(tx_busy),
        .tx_serial(tx_serial)
    );

    //=========================================================================
    // UART Receiver Instance
    //=========================================================================
    uart_rx #(
        .CLK_HZ(CLK_HZ),
        .BAUD(BAUD)
    ) u_uart_rx (
        .clk(clk),
        .rst(rst),
        .rx_serial(rx_serial),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .rx_busy(rx_busy)
    );

endmodule
