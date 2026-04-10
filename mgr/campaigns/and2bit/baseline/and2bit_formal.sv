`default_nettype none

// Formal harness for and2bit.
// Proves the combinational identity: y == (a & b).
module and2bit_formal;
  // Unconstrained inputs in formal.
  logic [1:0] a;
  logic [1:0] b;
  wire  [1:0] y;

  and2bit dut (
      .a(a),
      .b(b),
      .y(y)
  );

  // With no clock, the design is purely combinational. Assert the relation holds.
  always_comb begin
    assert (y == (a & b));

    // Sanity covers: ensure the solver can find some non-trivial cases.
    cover (a == 2'b11 && b == 2'b01 && y == 2'b01);
    cover (a == 2'b10 && b == 2'b01 && y == 2'b00);
  end
endmodule

`default_nettype wire
