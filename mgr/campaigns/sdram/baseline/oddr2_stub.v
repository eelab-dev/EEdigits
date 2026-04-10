module ODDR2 #(
    parameter DDR_ALIGNMENT = "NONE",
    parameter INIT = 1'b0,
    parameter SRTYPE = "SYNC"
) (
    output Q,
    input  C0,
    input  C1,
    input  CE,
    input  D0,
    input  D1,
    input  R,
    input  S
);
endmodule