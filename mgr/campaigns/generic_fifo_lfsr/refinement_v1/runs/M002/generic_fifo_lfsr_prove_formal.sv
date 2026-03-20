`default_nettype none

module generic_fifo_lfsr_prove_formal;
  localparam int unsigned FifoAw = 16;
  localparam int unsigned FifoDw = 8;
  localparam int unsigned FifoDepth = (1 << FifoAw);
  localparam int unsigned WatchdogMax = FifoDepth + 32;

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

  // Reset model: start in reset, then run with reset deasserted.
  always @(posedge clk) begin
    if ($initstate) begin
      assume(!nReset);
      assume(rst);
    end else begin
      assume(nReset);
      assume(!rst);
    end
  end

  // Keep stimulus legal: no read from empty / write to full.
  always @(posedge clk) begin
    if (!$initstate && nReset && !rst) begin
      assume(!(wreq && full));
      assume(!(rreq && empty));
    end
  end

  // Shadow occupancy model for FIFO sanity checks.
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

  // Data-integrity monitor:
  // Track one symbolic value and ensure FIFO order preserves it.
  (* anyconst *) logic [FifoDw:1] watched_data;
  (* anyseq *) logic choose_watch_push;

  logic watched_seen;
  logic watched_pending;
  logic [FifoAw:0] ahead_count;
  logic [$clog2(WatchdogMax+1)-1:0] watchdog;

  always @(posedge clk) begin
    if (!nReset || rst) begin
      watched_seen <= 1'b0;
      watched_pending <= 1'b0;
      ahead_count <= '0;
      watchdog <= '0;
    end else begin
      if (!watched_seen && push_evt && choose_watch_push && (d == watched_data)) begin
        watched_seen <= 1'b1;
        watched_pending <= 1'b1;
        ahead_count <= shadow_count - (pop_evt ? 1'b1 : 1'b0);
        watchdog <= '0;
      end else if (watched_pending) begin
        if (pop_evt) begin
          if (ahead_count != 0) begin
            ahead_count <= ahead_count - 1'b1;
          end else begin
            watched_pending <= 1'b0;
          end
        end

        if (watchdog != WatchdogMax[$clog2(WatchdogMax+1)-1:0]) begin
          watchdog <= watchdog + 1'b1;
        end
      end
    end
  end

  always @(posedge clk) begin
    if (!$initstate && nReset && !rst) begin
      // Synchronous-read RAM: popped data is observed on q one cycle later.
      if ($past(nReset && !rst) &&
          $past(watched_pending && (ahead_count == 0) && pop_evt)) begin
        assert(q == watched_data);
      end

      // Bounded liveness under legal traffic: once tracked, it cannot stall forever.
      if (watched_pending) begin
        assert(watchdog < WatchdogMax);
      end
    end
  end

  // Non-vacuity covers.
  always @(posedge clk) begin
    if (nReset && !rst) begin
      cover(watched_seen);
      cover(watched_seen && watched_pending && (ahead_count > 0));
      cover(watched_seen && !watched_pending);
    end
  end
endmodule

`default_nettype wire
