`default_nettype none

module generic_fifo_lfsr_prove_formal_v2;
  localparam int unsigned FifoAw = 16;
  localparam int unsigned FifoDw = 8;
  localparam int unsigned FifoDepth = (1 << FifoAw);
  localparam int unsigned ScenarioLen = 20;

  (* gclk *) logic clk;

  (* anyseq *) logic nReset;
  (* anyseq *) logic rst;

  logic wreq;
  logic rreq;
  logic [FifoDw:1] d;

  wire [FifoDw:1] q;
  wire empty;
  wire full;
  wire aempty;
  wire afull;

  (* anyconst *) logic [FifoDw:1] watched_data;

  logic [5:0] phase;

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

  // Directed traffic scenario to avoid vacuity:
  // cycles 1..4  : write 4 words
  // cycles 8..11 : read 4 words
  always @(posedge clk) begin
    if (!nReset || rst) begin
      phase <= '0;
    end else if (phase < ScenarioLen[5:0]) begin
      phase <= phase + 1'b1;
    end
  end

  always @(*) begin
    wreq = 1'b0;
    rreq = 1'b0;
    d = {FifoDw{1'b0}};

    if ((phase >= 6'd1) && (phase <= 6'd4)) begin
      wreq = 1'b1;
      if (phase == 6'd2)
        d = watched_data;
      else
        d = phase[FifoDw:1];
    end

    if ((phase >= 6'd8) && (phase <= 6'd11)) begin
      rreq = 1'b1;
    end
  end

  // Occupancy shadow model.
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

  // Track the watched token through FIFO order.
  logic watched_pending;
  logic [FifoAw:0] ahead_count;

  always @(posedge clk) begin
    if (!nReset || rst) begin
      watched_pending <= 1'b0;
      ahead_count <= '0;
    end else begin
      if (!watched_pending && push_evt && (d == watched_data)) begin
        watched_pending <= 1'b1;
        ahead_count <= shadow_count - (pop_evt ? 1'b1 : 1'b0);
      end else if (watched_pending && pop_evt) begin
        if (ahead_count != 0)
          ahead_count <= ahead_count - 1'b1;
        else
          watched_pending <= 1'b0;
      end
    end
  end

  always @(posedge clk) begin
    if (!$initstate && nReset && !rst) begin
      // FIFO consistency
      assert(shadow_count <= FifoDepth);
      assert(empty == (shadow_count == 0));
      assert(full == (shadow_count == FifoDepth));

      // Pointer step semantics under legal transfers
      if ($past(nReset && !rst && push_evt)) begin
        assert(dut.wp == ($past(dut.wp) + 1'b1));
      end
      if ($past(nReset && !rst && pop_evt)) begin
        assert(dut.rp == ($past(dut.rp) + 1'b1));
      end

      // Synchronous-read RAM check: popped watched word appears one cycle later.
      if ($past(nReset && !rst && watched_pending && (ahead_count == 0) && pop_evt)) begin
        assert(q == watched_data);
      end

      // Scenario checkpoints
      if (phase == 6'd6) begin
        assert(!empty);
      end
      if (phase == 6'd13) begin
        assert(empty);
      end
    end
  end

  // Non-vacuity covers.
  always @(posedge clk) begin
    if (nReset && !rst) begin
      cover(phase == 6'd4 && !empty);
      cover(phase == 6'd11 && watched_pending);
      cover(phase == 6'd13 && empty);
    end
  end
endmodule

`default_nettype wire
