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
    UUT.active = 1'b0;
    UUT.cycle_cnt = 32'b00000000000000000000000000000000;
    UUT.dut.u_uart_rx.baud_cnt = 4'b0000;
    UUT.dut.u_uart_rx.bit_idx = 3'b000;
    UUT.dut.u_uart_rx.rx_busy = 1'b0;
    UUT.dut.u_uart_rx.rx_data = 8'b10000000;
    UUT.dut.u_uart_rx.rx_valid = 1'b0;
    UUT.dut.u_uart_rx.shift_reg = 8'b00000000;
    UUT.dut.u_uart_rx.state = 3'b000;
    UUT.dut.u_uart_rx.stop_ok = 1'b0;
    UUT.dut.u_uart_tx.baud_cnt = 4'b0000;
    UUT.dut.u_uart_tx.bit_idx = 3'b000;
    UUT.dut.u_uart_tx.shift_reg = 8'b00000000;
    UUT.dut.u_uart_tx.state = 3'b100;
    UUT.dut.u_uart_tx.tx_busy = 1'b0;
    UUT.dut.u_uart_tx.tx_serial = 1'b0;
    UUT.fired = 1'b0;
    UUT.phase_cnt = 32'b10000000000000000000000000000000;
    UUT.rx_valid_seen = 1'b0;
    UUT.tx_latched = 8'b00000000;

    // state 0
    UUT.tx_payload = 8'b00000000;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      UUT.tx_payload <= 8'b00000000;
    end

    genclock <= cycle < 1;
    cycle <= cycle + 1;
  end
endmodule
