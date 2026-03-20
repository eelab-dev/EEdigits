`default_nettype none

module fft256_prove_formal;
  (* gclk *) logic CLK;

  (* anyseq *) logic RST;
  (* anyseq *) logic ED;
  (* anyseq *) logic START;
  (* anyseq *) logic [3:0] SHIFT;
  (* anyseq *) logic [9:0] DR;
  (* anyseq *) logic [9:0] DI;

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
      assume(RST);
    end else begin
      assume(!RST);
    end
  end

  always @(posedge CLK) begin
    if (!$initstate && RST) begin
      assert(!RDY);
      assert(ADDR == 8'h00);
    end
  end

  always @(posedge CLK) begin
    if (!$initstate && !RST) begin
      cover(ED);
      cover(START);
      cover(ADDR != 8'h00);
    end
  end
endmodule

`default_nettype wire
