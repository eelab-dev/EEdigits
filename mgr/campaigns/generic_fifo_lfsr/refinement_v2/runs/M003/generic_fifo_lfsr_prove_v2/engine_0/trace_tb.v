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
  generic_fifo_lfsr_prove_formal UUT (

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
    UUT._witness_.anyinit_procdff_291 = 1'b1;
    UUT._witness_.anyinit_procdff_292 = 1'b0;
    UUT.ahead_count = 17'b00000000000000000;
    UUT.dut._witness_.anyinit_procdff_265 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_270 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_275 = 1'b1;
    UUT.dut._witness_.anyinit_procdff_280 = 16'b0000000100000000;
    UUT.dut._witness_.anyinit_procdff_285 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_290 = 16'b0001000000000000;
    UUT.dut.fiforam.do_o = 8'b00000000;
    UUT.shadow_count = 17'b00000000000000000;
    UUT.watchdog = 17'b00000000000000000;
    UUT.watched_pending = 1'b0;
    UUT.watched_seen = 1'b1;
    UUT.watched_data = 8'b00000010;
    UUT.dut.fiforam.mem[16'b0000000000000000] = 8'b00000000;

    // state 0
    UUT.d = 8'b00010000;
    UUT.nReset = 1'b0;
    UUT.rreq = 1'b1;
    UUT.wreq = 1'b0;
    UUT.rst = 1'b1;
    UUT.choose_watch_push = 1'b1;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      UUT.d <= 8'b00000010;
      UUT.nReset <= 1'b1;
      UUT.rreq <= 1'b0;
      UUT.wreq <= 1'b1;
      UUT.rst <= 1'b0;
      UUT.choose_watch_push <= 1'b1;
    end

    // state 2
    if (cycle == 1) begin
      UUT.d <= 8'b00000010;
      UUT.nReset <= 1'b1;
      UUT.rreq <= 1'b1;
      UUT.wreq <= 1'b0;
      UUT.rst <= 1'b0;
      UUT.choose_watch_push <= 1'b1;
    end

    // state 3
    if (cycle == 2) begin
      UUT.d <= 8'b00000000;
      UUT.nReset <= 1'b1;
      UUT.rreq <= 1'b0;
      UUT.wreq <= 1'b0;
      UUT.rst <= 1'b0;
      UUT.choose_watch_push <= 1'b0;
    end

    // state 4
    if (cycle == 3) begin
      UUT.d <= 8'b00000000;
      UUT.nReset <= 1'b1;
      UUT.rreq <= 1'b0;
      UUT.wreq <= 1'b1;
      UUT.rst <= 1'b0;
      UUT.choose_watch_push <= 1'b1;
    end

    genclock <= cycle < 4;
    cycle <= cycle + 1;
  end
endmodule
