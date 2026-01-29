`timescale 1ns/1ps

module tb_uart_tx;
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

    always #(ClkPerNs/2) clk = ~clk;

    task automatic wait_bit;
        #(BitPerNs);
    endtask

    task automatic sample_mid;
        #(BitPerNs/2);
    endtask

    task automatic expect_bit(input bit expected);
        begin
            sample_mid();
            if (tx_serial !== expected) begin
                $display("ERROR: expected %0d got %0d at time %0t", expected, tx_serial, $time);
                $fatal(1);
            end
            sample_mid();
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
        tx_data  <= 8'hA5;
        tx_start <= 1'b1;
        @(posedge clk);
        tx_start <= 1'b0;

        expect_bit(1'b0); // start bit
        expect_bit(1'b1); // bit0
        expect_bit(1'b0); // bit1
        expect_bit(1'b1); // bit2
        expect_bit(1'b0); // bit3
        expect_bit(1'b0); // bit4
        expect_bit(1'b1); // bit5
        expect_bit(1'b0); // bit6
        expect_bit(1'b1); // bit7
        expect_bit(1'b1); // stop bit

        if (tx_busy !== 1'b0) begin
            $display("ERROR: tx_busy stuck high");
            $fatal(1);
        end

        $display("UART TX test PASSED");
        $finish;
    end
endmodule
