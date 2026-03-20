`default_nettype none

module fft256_cover_formal;
  (* gclk *) logic CLK;

  logic RST;
  logic ED;
  logic START;
  logic [3:0] SHIFT;
  logic [9:0] DR;
  logic [9:0] DI;
  logic [5:0] step;

  wire RDY;
  wire OVF1;
  wire OVF2;
  wire [7:0] ADDR;
  wire [13:0] DOR;
  wire [13:0] DOI;

  FFT256 dut (
      .CLK(CLK),
      .RST(RST),
      .ED(ED),
      .START(START),
      .SHIFT(SHIFT),
      .DR(DR),
      .DI(DI),
      .RDY(RDY),
      .OVF1(OVF1),
      .OVF2(OVF2),
      .ADDR(ADDR),
      .DOR(DOR),
      .DOI(DOI)
  );

  always @(posedge CLK) begin
    if ($initstate) begin
      step <= 6'd0;
    end else begin
      step <= step + 6'd1;
    end
  end

  always_comb begin
    RST = (step == 6'd0);
    ED = (step <= 6'd15);
    START = (step == 6'd1);
    SHIFT = 4'd0;
    DR = {4'd0, step};
    DI = ~{4'd0, step};
  end

  always @(posedge CLK) begin
    if (!RST) begin
      cover(START);
      cover(ED && (ADDR == 8'd1));
      cover(ED && (ADDR == 8'd4));
      cover(OVF1 || OVF2 || RDY);
    end
  end
endmodule

`default_nettype wire
