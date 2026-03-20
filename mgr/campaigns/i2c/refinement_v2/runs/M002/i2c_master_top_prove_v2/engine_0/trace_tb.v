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
    UUT._witness_.anyinit_procdff_1080 = 1'b0;
    UUT._witness_.anyinit_procdff_1081 = 1'b0;
    UUT._witness_.anyinit_procdff_1082 = 1'b0;
    UUT._witness_.anyinit_procdff_1083 = 1'b0;
    UUT._witness_.anyinit_procdff_1084 = 8'b10000000;
    UUT._witness_.anyinit_procdff_1085 = 1'b0;
    UUT._witness_.anyinit_procdff_1086 = 8'b10000000;
    UUT._witness_.anyinit_procdff_1087 = 1'b0;
    UUT._witness_.anyinit_procdff_1088 = 8'b10000000;
    UUT._witness_.anyinit_procdff_1089 = 1'b0;
    UUT._witness_.anyinit_procdff_1090 = 8'b10000000;
    UUT._witness_.anyinit_procdff_1091 = 1'b0;
    UUT._witness_.anyinit_procdff_1092 = 8'b10000000;
    UUT._witness_.anyinit_procdff_1093 = 1'b0;
    UUT._witness_.anyinit_procdff_1094 = 1'b0;
    UUT._witness_.anyinit_procdff_1095 = 1'b0;
    UUT.cmd_watchdog = 10'b1000000000;
    UUT.cmd_watchdog_active = 1'b0;
    UUT.dut._witness_.anyinit_procdff_1036 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_1041 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_1046 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_1051 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_1056 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_1061 = 8'b00000000;
    UUT.dut._witness_.anyinit_procdff_1066 = 16'b0000000000000000;
    UUT.dut._witness_.anyinit_procdff_1071 = 8'b00000000;
    UUT.dut._witness_.anyinit_procdff_1076 = 8'b00000000;
    UUT.dut.byte_controller._witness_.anyinit_procdff_1001 = 4'b0000;
    UUT.dut.byte_controller._witness_.anyinit_procdff_1006 = 1'b0;
    UUT.dut.byte_controller._witness_.anyinit_procdff_1011 = 1'b0;
    UUT.dut.byte_controller._witness_.anyinit_procdff_1016 = 1'b0;
    UUT.dut.byte_controller._witness_.anyinit_procdff_1021 = 5'b00000;
    UUT.dut.byte_controller._witness_.anyinit_procdff_1026 = 3'b000;
    UUT.dut.byte_controller._witness_.anyinit_procdff_1031 = 8'b00000000;
    UUT.dut.byte_controller._witness_.anyinit_procdff_991 = 1'b0;
    UUT.dut.byte_controller._witness_.anyinit_procdff_996 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_879 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_884 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_889 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_894 = 18'b000000000000000000;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_899 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_905 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_910 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_915 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_920 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_925 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_930 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_935 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_940 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_945 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_950 = 3'b000;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_955 = 3'b000;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_960 = 14'b00000000000000;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_965 = 2'b00;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_970 = 2'b00;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_975 = 1'b0;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_980 = 16'b0000000000000000;
    UUT.dut.byte_controller.bit_controller._witness_.anyinit_procdff_985 = 1'b0;
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
    UUT.wb_cyc_i = 1'b1;
    UUT.wb_stb_i = 1'b1;
    UUT.wb_we_i = 1'b0;
    UUT.wb_dat_i = 8'b00000000;
    UUT.wb_rst_i = 1'b1;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      UUT.arst_i <= 1'b1;
      UUT.ext_scl_low <= 1'b0;
      UUT.ext_sda_low <= 1'b0;
      UUT.wb_adr_i <= 3'b000;
      UUT.wb_cyc_i <= 1'b0;
      UUT.wb_stb_i <= 1'b0;
      UUT.wb_we_i <= 1'b0;
      UUT.wb_dat_i <= 8'b00000000;
      UUT.wb_rst_i <= 1'b0;
    end

    // state 2
    if (cycle == 1) begin
      UUT.arst_i <= 1'b1;
      UUT.ext_scl_low <= 1'b0;
      UUT.ext_sda_low <= 1'b0;
      UUT.wb_adr_i <= 3'b000;
      UUT.wb_cyc_i <= 1'b0;
      UUT.wb_stb_i <= 1'b0;
      UUT.wb_we_i <= 1'b0;
      UUT.wb_dat_i <= 8'b00000000;
      UUT.wb_rst_i <= 1'b0;
    end

    genclock <= cycle < 2;
    cycle <= cycle + 1;
  end
endmodule
