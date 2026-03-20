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
  i2c_master_top_prove_formal UUT (

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
    UUT._witness_.anyinit_procdff_965 = 1'b0;
    UUT.cmd_watchdog = 10'b1000000000;
    UUT.cmd_watchdog_active = 1'b0;
    UUT.dut._witness_.anyinit_procdff_921 = 1'b1;
    UUT.dut._witness_.anyinit_procdff_926 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_931 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_936 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_941 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_946 = 8'b00000000;
    UUT.dut._witness_.anyinit_procdff_951 = 16'b0000000000000000;
    UUT.dut._witness_.anyinit_procdff_956 = 8'b00000000;
    UUT.dut._witness_.anyinit_procdff_961 = 8'b00000000;
    UUT.dut.byte_controller._witness_.anyinit_procdff_876 = 1'b0;
    UUT.dut.byte_controller._witness_.anyinit_procdff_881 = 1'b0;
    UUT.dut.byte_controller._witness_.anyinit_procdff_886 = 4'b0000;
    UUT.dut.byte_controller._witness_.anyinit_procdff_891 = 1'b0;
    UUT.dut.byte_controller._witness_.anyinit_procdff_896 = 1'b0;
    UUT.dut.byte_controller._witness_.anyinit_procdff_901 = 1'b0;
    UUT.dut.byte_controller._witness_.anyinit_procdff_906 = 5'b00000;
    UUT.dut.byte_controller._witness_.anyinit_procdff_911 = 3'b000;
    UUT.dut.byte_controller._witness_.anyinit_procdff_916 = 8'b00000000;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_764 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_769 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_774 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_779 = 18'b000000000000000000;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_784 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_790 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_795 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_800 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_805 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_810 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_815 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_820 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_825 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_830 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_835 = 3'b000;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_840 = 3'b000;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_845 = 14'b00000000000000;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_850 = 2'b00;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_855 = 2'b00;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_860 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_865 = 16'b0000000000000000;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_870 = 1'b0;
    UUT.dut.byte_controller.bit_controller.dout = 1'b0;
    UUT.dut.byte_controller.bit_controller.dscl_oen = 1'b0;
    UUT.dut.wb_ack_o = 1'b0;
    UUT.dut.wb_dat_o = 8'b00000000;
    UUT.tip_q = 1'b0;
    UUT.tip_watchdog = 10'b1000000000;
    UUT.tip_watchdog_active = 1'b0;

    // state 0
    UUT.arst_i = 1'b0;
    UUT.wb_adr_i = 3'b000;
    UUT.wb_cyc_i = 1'b0;
    UUT.wb_stb_i = 1'b0;
    UUT.wb_we_i = 1'b0;
    UUT.wb_dat_i = 8'b00000000;
    UUT.wb_rst_i = 1'b1;
    UUT.ext_scl_low = 1'b0;
    UUT.ext_sda_low = 1'b0;
  end
  always @(posedge clock) begin
    genclock <= cycle < 0;
    cycle <= cycle + 1;
  end
endmodule
