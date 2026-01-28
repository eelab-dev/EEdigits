`timescale 1ns / 1ps

module tb_and2bit;
  reg  [1:0] a;
  reg  [1:0] b;
  wire [1:0] y;

  and2bit dut (
      .a(a),
      .b(b),
      .y(y)
  );

  task automatic apply_and_check(input logic [1:0] aa, input logic [1:0] bb);
    reg [1:0] exp;
    begin
      a = aa;
      b = bb;
      #1;
      exp = (aa & bb);
      $display("t=%0t a=%b b=%b y=%b exp=%b %s", $time, a, b, y, exp, (y === exp) ? "OK" : "FAIL");
      if (y !== exp) begin
        $fatal(1, "Mismatch: a=%b b=%b y=%b exp=%b", a, b, y, exp);
      end
    end
  endtask

  initial begin
    integer ia;
    integer ib;

    // Waveform dump (VCD) for viewing in Surfer.
    $dumpfile("and2bit.vcd");
    $dumpvars(0, tb_and2bit);

    $display("--- tb_and2bit starting ---");

    // Exhaustively test all 2-bit combinations: 4x4 = 16.
    for (ia = 0; ia < 4; ia = ia + 1) begin
      for (ib = 0; ib < 4; ib = ib + 1) begin
        apply_and_check(ia[1:0], ib[1:0]);
      end
    end

    $display("--- tb_and2bit done ---");
    $finish;
  end
endmodule
