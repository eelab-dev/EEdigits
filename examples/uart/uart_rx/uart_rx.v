`timescale 1ns/1ps

module uart_rx #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer BAUD   = 115_200
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       rx_serial,
    output reg  [7:0] rx_data,
    output reg        rx_valid,
    output reg        rx_busy
);
    localparam integer BaudDiv = CLK_HZ / BAUD;

    localparam logic [2:0] SIdle  = 3'd0;
    localparam logic [2:0] SStart = 3'd1;
    localparam logic [2:0] SData  = 3'd2;
    localparam logic [2:0] SStop  = 3'd3;

    reg [2:0] state;
    reg [$clog2(BaudDiv)-1:0] baud_cnt;
    reg [2:0] bit_idx;
    reg [7:0] shift_reg;
    reg       stop_ok;

    wire baud_mid  = (baud_cnt == (BaudDiv / 2));
    wire baud_tick = (baud_cnt == BaudDiv - 1);

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
            rx_valid <= 1'b0;
            case (state)
                SIdle: begin
                    rx_busy  <= 1'b0;
                    baud_cnt <= {($clog2(BaudDiv)){1'b0}};
                    bit_idx  <= 3'd0;
                    stop_ok  <= 1'b1;
                    if (rx_serial == 1'b0) begin
                        state   <= SStart;
                        rx_busy <= 1'b1;
                    end
                end

                SStart: begin
                    rx_busy <= 1'b1;
                    if (baud_mid && (rx_serial == 1'b1)) begin
                        state    <= SIdle;
                        rx_busy  <= 1'b0;
                        baud_cnt <= {($clog2(BaudDiv)){1'b0}};
                    end else if (baud_tick) begin
                        baud_cnt <= {($clog2(BaudDiv)){1'b0}};
                        state    <= SData;
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                SData: begin
                    rx_busy <= 1'b1;
                    if (baud_mid) begin
                        shift_reg[bit_idx] <= rx_serial;
                    end
                    if (baud_tick) begin
                        baud_cnt <= {($clog2(BaudDiv)){1'b0}};
                        if (bit_idx == 3'd7) begin
                            bit_idx <= 3'd0;
                            state   <= SStop;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                SStop: begin
                    rx_busy <= 1'b1;
                    if (baud_mid) begin
                        stop_ok <= rx_serial;
                    end
                    if (baud_tick) begin
                        baud_cnt <= {($clog2(BaudDiv)){1'b0}};
                        state    <= SIdle;
                        rx_busy  <= 1'b0;
                        if (stop_ok) begin
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
