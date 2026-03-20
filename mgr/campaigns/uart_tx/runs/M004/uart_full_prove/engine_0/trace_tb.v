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
  uart_full_formal UUT (

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
    UUT.dut.u_uart_rx.baud_cnt = 4'b0000;
    UUT.dut.u_uart_rx.bit_idx = 3'b000;
    UUT.dut.u_uart_rx.rx_busy = 1'b0;
    UUT.dut.u_uart_rx.rx_data = 8'b00000000;
    UUT.dut.u_uart_rx.rx_valid = 1'b0;
    UUT.dut.u_uart_rx.shift_reg = 8'b00000000;
    UUT.dut.u_uart_rx.state = 3'b000;
    UUT.dut.u_uart_rx.stop_ok = 1'b0;
    UUT.dut.u_uart_tx.baud_cnt = 4'b0000;
    UUT.dut.u_uart_tx.bit_idx = 3'b000;
    UUT.dut.u_uart_tx.shift_reg = 8'b00000000;
    UUT.dut.u_uart_tx.state = 3'b000;
    UUT.dut.u_uart_tx.tx_busy = 1'b0;
    UUT.dut.u_uart_tx.tx_serial = 1'b0;
    UUT.fired = 1'b0;
    UUT.tx_latched = 8'b10000000;

    // state 0
    UUT.tx_payload = 8'b00000000;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      UUT.tx_payload <= 8'b10000000;
    end

    // state 2
    if (cycle == 1) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 3
    if (cycle == 2) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 4
    if (cycle == 3) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 5
    if (cycle == 4) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 6
    if (cycle == 5) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 7
    if (cycle == 6) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 8
    if (cycle == 7) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 9
    if (cycle == 8) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 10
    if (cycle == 9) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 11
    if (cycle == 10) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 12
    if (cycle == 11) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 13
    if (cycle == 12) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 14
    if (cycle == 13) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 15
    if (cycle == 14) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 16
    if (cycle == 15) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 17
    if (cycle == 16) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 18
    if (cycle == 17) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 19
    if (cycle == 18) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 20
    if (cycle == 19) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 21
    if (cycle == 20) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 22
    if (cycle == 21) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 23
    if (cycle == 22) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 24
    if (cycle == 23) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 25
    if (cycle == 24) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 26
    if (cycle == 25) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 27
    if (cycle == 26) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 28
    if (cycle == 27) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 29
    if (cycle == 28) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 30
    if (cycle == 29) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 31
    if (cycle == 30) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 32
    if (cycle == 31) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 33
    if (cycle == 32) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 34
    if (cycle == 33) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 35
    if (cycle == 34) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 36
    if (cycle == 35) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 37
    if (cycle == 36) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 38
    if (cycle == 37) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 39
    if (cycle == 38) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 40
    if (cycle == 39) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 41
    if (cycle == 40) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 42
    if (cycle == 41) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 43
    if (cycle == 42) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 44
    if (cycle == 43) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 45
    if (cycle == 44) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 46
    if (cycle == 45) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 47
    if (cycle == 46) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 48
    if (cycle == 47) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 49
    if (cycle == 48) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 50
    if (cycle == 49) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 51
    if (cycle == 50) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 52
    if (cycle == 51) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 53
    if (cycle == 52) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 54
    if (cycle == 53) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 55
    if (cycle == 54) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 56
    if (cycle == 55) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 57
    if (cycle == 56) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 58
    if (cycle == 57) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 59
    if (cycle == 58) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 60
    if (cycle == 59) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 61
    if (cycle == 60) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 62
    if (cycle == 61) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 63
    if (cycle == 62) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 64
    if (cycle == 63) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 65
    if (cycle == 64) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 66
    if (cycle == 65) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 67
    if (cycle == 66) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 68
    if (cycle == 67) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 69
    if (cycle == 68) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 70
    if (cycle == 69) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 71
    if (cycle == 70) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 72
    if (cycle == 71) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 73
    if (cycle == 72) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 74
    if (cycle == 73) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 75
    if (cycle == 74) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 76
    if (cycle == 75) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 77
    if (cycle == 76) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 78
    if (cycle == 77) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 79
    if (cycle == 78) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 80
    if (cycle == 79) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 81
    if (cycle == 80) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 82
    if (cycle == 81) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 83
    if (cycle == 82) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 84
    if (cycle == 83) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 85
    if (cycle == 84) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 86
    if (cycle == 85) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 87
    if (cycle == 86) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 88
    if (cycle == 87) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 89
    if (cycle == 88) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 90
    if (cycle == 89) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 91
    if (cycle == 90) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 92
    if (cycle == 91) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 93
    if (cycle == 92) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 94
    if (cycle == 93) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 95
    if (cycle == 94) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 96
    if (cycle == 95) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 97
    if (cycle == 96) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 98
    if (cycle == 97) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 99
    if (cycle == 98) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 100
    if (cycle == 99) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 101
    if (cycle == 100) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 102
    if (cycle == 101) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 103
    if (cycle == 102) begin
      UUT.tx_payload <= 8'b00000000;
    end

    // state 104
    if (cycle == 103) begin
      UUT.tx_payload <= 8'b00000000;
    end

    genclock <= cycle < 104;
    cycle <= cycle + 1;
  end
endmodule
