`timescale 1ns/1ps

module tb_up8_add1_loop;
    reg clk = 1'b0;
    reg rst = 1'b1;

    wire [15:0] pc;
    wire z;
    wire c;
    wire halted;
    wire [7:0] r0, r1, r2, r3;

    // 100MHz-ish clock for simulation convenience
    always #5 clk = ~clk;

    up8_cpu #(
        .MEM_INIT_FILE("rom_add1_loop.memh")
    ) dut (
        .clk(clk),
        .rst(rst),
        .pc(pc),
        .z(z),
        .c(c),
        .halted(halted),
        .r0(r0), .r1(r1), .r2(r2), .r3(r3)
    );

    integer cycles;
    string vcd_path;

    initial begin
        vcd_path = "up8_add1_loop.vcd";
        void'($value$plusargs("VCD=%s", vcd_path));
        $dumpfile(vcd_path);
        $dumpvars(0, tb_up8_add1_loop);

        cycles = 0;

        // Reset for a couple cycles
        repeat (3) @(posedge clk);
        rst <= 1'b0;

        // Run until HALT or timeout
        while (!halted && cycles < 200) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (!halted) begin
            $display("FAIL: timeout waiting for HALT (pc=%h r0=%0d r1=%0d)", pc, r0, r1);
            $finish(1);
        end

        // Program sets N=10; sum should end at 10 and counter at 0
        if (r0 !== 8'd10) begin
            $display("FAIL: R0 expected 10, got %0d (0x%02h)", r0, r0);
            $finish(1);
        end
        if (r1 !== 8'd0) begin
            $display("FAIL: R1 expected 0, got %0d (0x%02h)", r1, r1);
            $finish(1);
        end

        $display("PASS: halted after %0d cycles; R0=%0d R1=%0d", cycles, r0, r1);
        $finish(0);
    end

endmodule
