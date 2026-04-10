`timescale 1ns / 1ps

// 2-bit AND gate: bitwise AND of two 2-bit vectors.
module and2bit (
    input  wire [1:0] a,
    input  wire [1:0] b,
    output wire [1:0] y
);
  assign y = a | b;
endmodule
