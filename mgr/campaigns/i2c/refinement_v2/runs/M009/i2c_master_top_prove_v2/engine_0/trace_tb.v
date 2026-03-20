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
  i2c_master_top_prove_formal_v2 UUT (

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
    UUT._witness_.anyinit_procdff_1079 = 1'b0;
    UUT._witness_.anyinit_procdff_1080 = 1'b0;
    UUT._witness_.anyinit_procdff_1081 = 1'b0;
    UUT._witness_.anyinit_procdff_1082 = 1'b0;
    UUT._witness_.anyinit_procdff_1083 = 8'b10000000;
    UUT._witness_.anyinit_procdff_1084 = 1'b0;
    UUT._witness_.anyinit_procdff_1085 = 8'b10000000;
    UUT._witness_.anyinit_procdff_1086 = 1'b0;
    UUT._witness_.anyinit_procdff_1087 = 8'b10000000;
    UUT._witness_.anyinit_procdff_1088 = 1'b0;
    UUT._witness_.anyinit_procdff_1089 = 8'b10000000;
    UUT._witness_.anyinit_procdff_1090 = 1'b0;
    UUT._witness_.anyinit_procdff_1091 = 8'b10000000;
    UUT._witness_.anyinit_procdff_1092 = 1'b0;
    UUT._witness_.anyinit_procdff_1093 = 1'b0;
    UUT._witness_.anyinit_procdff_1094 = 1'b0;
    UUT.cmd_watchdog = 10'b1000000000;
    UUT.cmd_watchdog_active = 1'b0;
    UUT.dut._witness_.anyinit_procdff_1035 = 1'b1;
    UUT.dut._witness_.anyinit_procdff_1040 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_1045 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_1050 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_1055 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_1060 = 8'b00000000;
    UUT.dut._witness_.anyinit_procdff_1065 = 16'b0000000000000000;
    UUT.dut._witness_.anyinit_procdff_1070 = 8'b00000000;
    UUT.dut._witness_.anyinit_procdff_1075 = 8'b00000000;
    UUT.dut.byte_controller._witness_.anyinit_procdff_1000 = 4'b0000;
    UUT.dut.byte_controller._witness_.anyinit_procdff_1005 = 1'b0;
    UUT.dut.byte_controller._witness_.anyinit_procdff_1010 = 1'b0;
    UUT.dut.byte_controller._witness_.anyinit_procdff_1015 = 1'b0;
    UUT.dut.byte_controller._witness_.anyinit_procdff_1020 = 5'b00000;
    UUT.dut.byte_controller._witness_.anyinit_procdff_1025 = 3'b000;
    UUT.dut.byte_controller._witness_.anyinit_procdff_1030 = 8'b00000000;
    UUT.dut.byte_controller._witness_.anyinit_procdff_990 = 1'b0;
    UUT.dut.byte_controller._witness_.anyinit_procdff_995 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_878 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_883 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_888 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_893 = 18'b000000000000000000;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_898 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_904 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_909 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_914 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_919 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_924 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_929 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_934 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_939 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_944 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_949 = 3'b000;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_954 = 3'b000;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_959 = 14'b00000000000000;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_964 = 2'b00;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_969 = 2'b00;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_974 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_979 = 16'b0000000000000000;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_984 = 1'b0;
    UUT.dut.byte_controller.bit_controller.dout = 1'b0;
    UUT.dut.byte_controller.bit_controller.dscl_oen = 1'b0;
    UUT.dut.wb_ack_o = 1'b0;
    UUT.dut.wb_dat_o = 8'b00000000;
    UUT.tip_q = 1'b0;
    UUT.tip_watchdog = 10'b1000000000;
    UUT.tip_watchdog_active = 1'b0;

    // state 0
    UUT.arst_i = 1'b0;
    UUT.ext_scl_low = 1'b0;
    UUT.ext_sda_low = 1'b0;
    UUT.wb_adr_i = 3'b000;
    UUT.wb_cyc_i = 1'b0;
    UUT.wb_stb_i = 1'b0;
    UUT.wb_we_i = 1'b0;
    UUT.wb_dat_i = 8'b00000000;
    UUT.wb_rst_i = 1'b1;
  end
  always @(posedge clock) begin
    genclock <= cycle < 0;
    cycle <= cycle + 1;
  end
endmodule
