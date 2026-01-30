`timescale 1ns/1ps

module tb_uart_rx;
    localparam integer ClkHz    = 1_000_000;
    localparam integer Baud     = 9_600;
    localparam integer ClkPerNs = 1_000_000_000 / ClkHz;
    localparam integer BitPerNs = 1_000_000_000 / Baud;

    reg clk;
    reg rst;
    reg rx_serial;
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

    always #(ClkPerNs/2) clk = ~clk;

    task automatic drive_bit(input bit value);
        begin
            rx_serial = value;
            #(BitPerNs);
        end
    endtask

    task automatic send_byte(input logic [7:0] data);
        integer i;
        begin
            drive_bit(1'b0); // start bit
            for (i = 0; i < 8; i = i + 1) begin
                drive_bit(data[i]);
            end
            drive_bit(1'b1); // stop bit
        end
    endtask

    task automatic wait_for_valid;
        integer cycles;
        begin
            cycles = 0;
            while (!rx_valid) begin
                @(posedge clk);
                cycles = cycles + 1;
                if (cycles > 3000) begin
                    $display("ERROR: timeout waiting for rx_valid");
                    $fatal(1);
                end
            end
        end
    endtask

    initial begin
        clk       = 1'b0;
        rst       = 1'b1;
        rx_serial = 1'b1;

        #(10*ClkPerNs);
        rst = 1'b0;

        @(posedge clk);
        send_byte(8'hA5);
        wait_for_valid();

        if (rx_data !== 8'hA5) begin
            $display("ERROR: expected 0xA5, got 0x%0h", rx_data);
            $fatal(1);
        end

        repeat (5) @(posedge clk);
        if (rx_busy !== 1'b0) begin
            $display("ERROR: rx_busy stuck high");
            $fatal(1);
        end

        $display("UART RX test PASSED");
        $finish;
    end
endmodule
