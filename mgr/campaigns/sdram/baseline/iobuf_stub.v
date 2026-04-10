module IOBUF #(
    parameter DRIVE = 12,
    parameter IOSTANDARD = "LVTTL",
    parameter SLEW = "FAST"
) (
    output O,
    inout  IO,
    input  I,
    input  T
);
endmodule