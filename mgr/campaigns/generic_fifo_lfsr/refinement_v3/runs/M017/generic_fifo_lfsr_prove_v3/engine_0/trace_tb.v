`ifndef VERILATOR
module testbench;
  reg [4095:0] vcdfile;
  reg clock;
`else
module testbench(input clock, output reg genclock);
  initial genclock = 1;
`endif
  reg genclock = 1;
  reg [31:0] cycle = 0;
  generic_fifo_lfsr_prove_formal_v2 UUT (

  );
`ifndef VERILATOR
  initial begin
    if ($value$plusargs("vcd=%s", vcdfile)) begin
      $dumpfile(vcdfile);
      $dumpvars(0, testbench);
    end
    #5 clock = 0;
    while (genclock) begin
      #5 clock = 0;
      #5 clock = 1;
    end
  end
`endif
  initial begin
`ifndef VERILATOR
    #1;
`endif
    UUT._witness_.anyinit_procdff_310 = 1'b0;
    UUT._witness_.anyinit_procdff_311 = 1'b0;
    UUT._witness_.anyinit_procdff_312 = 1'b0;
    UUT._witness_.anyinit_procdff_313 = 1'b0;
    UUT._witness_.anyinit_procdff_314 = 1'b0;
    UUT.ahead_count = 17'b00000000000000000;
    UUT.dut._witness_.anyinit_procdff_284 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_289 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_294 = 1'b1;
    UUT.dut._witness_.anyinit_procdff_299 = 16'b0000000100000000;
    UUT.dut._witness_.anyinit_procdff_304 = 1'b1;
    UUT.dut._witness_.anyinit_procdff_309 = 16'b0000000000000100;
    UUT.dut.fiforam.do_o = 8'b00000000;
    UUT.phase = 6'b000010;
    UUT.shadow_count = 17'b00000000000000000;
    UUT.watched_pending = 1'b0;
    UUT.watched_data = 8'b00000000;
    UUT.dut.fiforam.mem[16'b0000000000000000] = 8'b00000001;

    // state 0
    UUT.nReset = 1'b0;
    UUT.rst = 1'b1;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      UUT.nReset <= 1'b1;
      UUT.rst <= 1'b0;
    end

    // state 2
    if (cycle == 1) begin
      UUT.nReset <= 1'b1;
      UUT.rst <= 1'b0;
    end

    genclock <= cycle < 2;
    cycle <= cycle + 1;
  end
endmodule
