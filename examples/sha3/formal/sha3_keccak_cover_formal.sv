`default_nettype none

module sha3_keccak_cover_formal;
  (* gclk *) logic clk;

  (* anyseq *) logic reset;
  logic [63:0] in;
  logic in_ready;
  logic is_last;
  logic [2:0] byte_num;

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

  localparam logic [1:0] StSendLast = 2'd0;
  localparam logic [1:0] StWaitDone = 2'd1;
  localparam logic [1:0] StIdle = 2'd2;

  logic [1:0] state;

  always @(posedge clk) begin
    if ($initstate) begin
      assume(reset);
    end else begin
      assume(!reset);
    end
  end

  always_comb begin
    in = 64'h0123_4567_89ab_cdef;
    in_ready = 1'b0;
    is_last = 1'b0;
    byte_num = 3'd3;

    case (state)
      StSendLast: begin
        in_ready = 1'b1;
        is_last = 1'b1;
      end
      default: begin
      end
    endcase
  end

  always @(posedge clk) begin
    if (reset) begin
      state <= StSendLast;
    end else begin
      case (state)
        StSendLast: state <= StWaitDone;
        StWaitDone: if (out_ready) state <= StIdle;
        default: state <= StIdle;
      endcase
    end
  end

  always @(posedge clk) begin
    if (!$initstate && $past(reset)) begin
      assert(!out_ready);
    end

    if (!$initstate && !$past(reset) && !reset && $past(out_ready)) begin
      assert(out_ready);
    end
  end

  always @(posedge clk) begin
    if (!reset) begin
      cover(state == StWaitDone);
      cover(buffer_full);
      cover(out_ready);
      cover(state == StIdle);
    end
  end
endmodule

`default_nettype wire
