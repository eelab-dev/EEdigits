`default_nettype none

module generic_fifo_lfsr_cover_formal;
  localparam int unsigned FifoAw = 10;
  localparam int unsigned FifoDw = 8;
  localparam int unsigned FifoDepth = (1 << FifoAw);

  (* gclk *) logic clk;

  (* anyseq *) logic nReset;
  (* anyseq *) logic rst;
  (* anyseq *) logic wreq;
  (* anyseq *) logic rreq;
  (* anyseq *) logic [FifoDw:1] d;

  wire [FifoDw:1] q;
  wire empty;
  wire full;
  wire aempty;
  wire afull;

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

  always @(posedge clk) begin
    if ($initstate) begin
      assume(!nReset);
      assume(rst);
    end else begin
      assume(nReset);
      assume(!rst);
    end
  end

  always @(posedge clk) begin
    if (!$initstate && nReset && !rst) begin
      assume(!(wreq && full));
      assume(!(rreq && empty));
    end
  end

  logic [FifoAw:0] shadow_count;
  wire push_evt = wreq && !full;
  wire pop_evt = rreq && !empty;

  always @(posedge clk) begin
    if (!nReset || rst) begin
      shadow_count <= '0;
    end else begin
      case ({push_evt, pop_evt})
        2'b10: shadow_count <= shadow_count + 1'b1;
        2'b01: shadow_count <= shadow_count - 1'b1;
        default: shadow_count <= shadow_count;
      endcase
    end
  end

  always @(posedge clk) begin
    if (!$initstate && nReset && !rst) begin
      assert(shadow_count <= FifoDepth);
      assert(empty == (shadow_count == 0));
      assert(full == (shadow_count == FifoDepth));
    end
  end

  (* anyconst *) logic [FifoDw:1] watched_data;
  (* anyseq *) logic choose_watch_push;

  logic watched_seen;
  logic watched_pending;
  logic [FifoAw:0] ahead_count;

  always @(posedge clk) begin
    if (!nReset || rst) begin
      watched_seen <= 1'b0;
      watched_pending <= 1'b0;
      ahead_count <= '0;
    end else begin
      if (!watched_seen && push_evt && choose_watch_push && (d == watched_data)) begin
        watched_seen <= 1'b1;
        watched_pending <= 1'b1;
        ahead_count <= shadow_count - (pop_evt ? 1'b1 : 1'b0);
      end else if (watched_pending && pop_evt) begin
        if (ahead_count != 0) begin
          ahead_count <= ahead_count - 1'b1;
        end else begin
          watched_pending <= 1'b0;
        end
      end
    end
  end

  always @(posedge clk) begin
    if (nReset && !rst) begin
      cover(shadow_count == 0);
      cover(shadow_count >= 16);
      cover(watched_seen);
      cover(watched_seen && watched_pending && (ahead_count > 8));
      cover(watched_pending && (ahead_count == 0) && pop_evt && (q == watched_data));
      cover(watched_seen && !watched_pending);
    end
  end
endmodule

`default_nettype wire
