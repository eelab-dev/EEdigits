`default_nettype none

module sha3_keccak_prove_formal;
  (* gclk *) logic clk;

  (* anyseq *) logic reset;
  (* anyseq *) logic [63:0] in;
  (* anyseq *) logic in_ready;
  (* anyseq *) logic is_last;
  (* anyseq *) logic [2:0] byte_num;

  wire buffer_full;
  wire [511:0] out;
  wire out_ready;

  keccak dut (
      .clk(clk),
      .reset(reset),
      .in(in),
      .in_ready(in_ready),
      .is_last(is_last),
      .byte_num(byte_num),
      .buffer_full(buffer_full),
      .out(out),
      .out_ready(out_ready)
  );

  logic seen_last;

  always @(posedge clk) begin
    if ($initstate) begin
      assume(reset);
    end else begin
      assume(!reset);
    end
  end

  always @(posedge clk) begin
    if (!in_ready) begin
      assume(!is_last);
    end
  end

  always @(posedge clk) begin
    if (reset) begin
      seen_last <= 1'b0;
    end else if (in_ready && is_last) begin
      seen_last <= 1'b1;
    end
  end

  always @(posedge clk) begin
    if (!$initstate && $past(reset)) begin
      assert(!out_ready);
    end

    if (!reset && !seen_last) begin
      assert(!out_ready);
    end

    if (!$initstate && !$past(reset) && !reset && $past(out_ready)) begin
      assert(out_ready);
    end

    if (!$initstate && out_ready) begin
      assert(seen_last);
    end
  end

  always @(posedge clk) begin
    if (!reset) begin
      cover(seen_last);
      cover(buffer_full);
      cover(out_ready);
    end
  end
endmodule

`default_nettype wire
