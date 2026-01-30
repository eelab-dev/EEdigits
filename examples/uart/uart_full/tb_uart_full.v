`timescale 1ns/1ps

module tb_uart_full;
    localparam integer ClkHz    = 1_000_000;
    localparam integer Baud     = 9_600;
    localparam integer ClkPerNs = 1_000_000_000 / ClkHz;
    localparam integer BitPerNs = 1_000_000_000 / Baud;

    reg clk;
    reg rst;
    reg tx_start;
    reg [7:0] tx_data;
    wire tx_busy;
    wire tx_serial;
    wire rx_serial;
    wire [7:0] rx_data;
    wire rx_valid;
    wire rx_busy;

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
        .tx_data(tx_data),
        .tx_busy(tx_busy),
        .tx_serial(tx_serial)
    );

    always #(ClkPerNs/2) clk = ~clk;

    task automatic wait_for_valid;
        integer cycles;
        begin
            cycles = 0;
            while (!rx_valid) begin
                @(posedge clk);
                cycles = cycles + 1;
                if (cycles > 5000) begin
                    $display("ERROR: timeout waiting for rx_valid");
                    $fatal(1);
                end
            end
        end
    endtask

    initial begin
        clk      = 1'b0;
        rst      = 1'b1;
        tx_start = 1'b0;
        tx_data  = 8'h00;

        #(10*ClkPerNs);
        rst = 1'b0;

        @(posedge clk);
        tx_data  <= 8'h3C;
        tx_start <= 1'b1;
        @(posedge clk);
        tx_start <= 1'b0;

        wait_for_valid();

        if (rx_data !== 8'h3C) begin
            $display("ERROR: expected 0x3C, got 0x%0h", rx_data);
            $fatal(1);
        end

        repeat (5) @(posedge clk);
        if (tx_busy !== 1'b0) begin
            $display("ERROR: tx_busy stuck high");
            $fatal(1);
        end
        if (rx_busy !== 1'b0) begin
            $display("ERROR: rx_busy stuck high");
            $fatal(1);
        end

        $display("UART FULL loopback test PASSED");
        $finish;
    end
endmodule
