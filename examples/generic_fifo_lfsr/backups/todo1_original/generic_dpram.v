`default_nettype none

module generic_dpram #(
  parameter int unsigned AW = 8,
  parameter int unsigned DW = 8
) (
    input                wclk,
    input                wrst,
    input                wce,
    input                we,
    input      [AW:1]    waddr,
    input      [DW:1]    di,
    input                rclk,
    input                rrst,
    input                rce,
    input                oe,
    input      [AW:1]    raddr,
    output reg [DW:1]    do_o
);

  localparam int unsigned DEPTH = (1 << AW);
  reg [DW:1] mem [DEPTH];

  integer idx;
  always @(posedge wclk or posedge wrst) begin
    if (wrst) begin
      for (idx = 0; idx < DEPTH; idx = idx + 1) begin
        mem[idx] <= {DW{1'b0}};
      end
    end else if (wce && we) begin
      mem[waddr] <= di;
    end
  end

  always @(posedge rclk or posedge rrst) begin
    if (rrst) begin
      do_o <= {DW{1'b0}};
    end else if (rce && oe) begin
      do_o <= mem[raddr];
    end
  end
endmodule

`default_nettype wire
