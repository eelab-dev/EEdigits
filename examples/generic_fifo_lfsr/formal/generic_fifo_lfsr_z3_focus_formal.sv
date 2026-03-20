`default_nettype none

module generic_fifo_lfsr_z3_focus_formal;
  localparam int unsigned FifoAw = 16;
  localparam int unsigned FifoDw = 8;

  (* gclk *) logic clk;

  logic nReset;
  logic rst;
  logic wreq;
  logic rreq;
  logic [FifoDw:1] d;

  wire [FifoDw:1] q;
  wire empty;
  wire full;
  wire aempty;
  wire afull;

  (* anyconst *) logic [FifoDw:1] watched_data;

  generic_fifo_lfsr #(
      .AW(FifoAw),
      .DW(FifoDw)
  ) dut (
      .clk(clk),
      .nReset(nReset),
      .rst(rst),
      .wreq(wreq),
      .rreq(rreq),
      .d(d),
      .q(q),
      .empty(empty),
      .full(full),
      .aempty(aempty),
      .afull(afull)
  );

  localparam logic [1:0] StPush = 2'd0;
  localparam logic [1:0] StGap  = 2'd1;
  localparam logic [1:0] StPop  = 2'd2;
  localparam logic [1:0] StDone = 2'd3;

  logic [1:0] state;
  wire push_evt = wreq && !full;
  wire pop_evt = rreq && !empty;

  always @(posedge clk) begin
    if ($initstate) begin
      nReset <= 1'b0;
      rst <= 1'b1;
      state <= StPush;
    end else begin
      nReset <= 1'b1;
      rst <= 1'b0;

      case (state)
        StPush: if (push_evt) state <= StGap;
        StGap: state <= StPop;
        StPop: if (pop_evt) state <= StDone;
        default: state <= StDone;
      endcase
    end
  end

  always_comb begin
    wreq = 1'b0;
    rreq = 1'b0;
    d = watched_data;

    case (state)
      StPush: wreq = 1'b1;
      StPop: rreq = 1'b1;
      default: begin
      end
    endcase
  end

  always @(posedge clk) begin
    if (!$initstate && nReset && !rst) begin
      assert(!(empty && full));
    end
  end

  always @(posedge clk) begin
    if (nReset && !rst) begin
      cover(push_evt);
      cover(pop_evt);
      cover(state == StDone);
    end
  end
endmodule

`default_nettype wire
