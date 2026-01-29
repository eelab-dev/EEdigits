`timescale 1ns/1ps

module uart_tx #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer BAUD   = 115_200
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx_busy,
    output reg        tx_serial
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
                    tx_serial <= 1'b1;
                    tx_busy   <= 1'b0;
                    baud_cnt  <= {($clog2(BaudDiv)){1'b0}};
                    bit_idx   <= 3'd0;
                    if (tx_start) begin
                        shift_reg <= tx_data;
                        tx_busy   <= 1'b1;
                        state     <= SStart;
                    end
                end

                SStart: begin
                    tx_serial <= 1'b0;
                    if (baud_tick) begin
                        baud_cnt <= {($clog2(BaudDiv)){1'b0}};
                        state    <= SData;
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                SData: begin
                    tx_serial <= shift_reg[0];
                    if (baud_tick) begin
                        baud_cnt  <= {($clog2(BaudDiv)){1'b0}};
                        shift_reg <= {1'b0, shift_reg[7:1]};
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
                    tx_serial <= 1'b1;
                    if (baud_tick) begin
                        baud_cnt <= {($clog2(BaudDiv)){1'b0}};
                        state    <= SIdle;
                        tx_busy  <= 1'b0;
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
