`default_nettype none

//=============================================================================
// SDRAM prove harness – R4
//=============================================================================
// Changes over R3:
//   Script extended to W1 → W2 → R1:
//     W1 (StWrite1Req): cold-start write, opens row via ACTIVATE.
//     W2 (StWrite2Req): second write to same address immediately after W1.
//                       Row is still open → row-hit path is taken.
//                       M012 (we_i inversion in row-hit) diverts W2 to READ.
//   A9b – No CMD_READ during W2 phase: catches M012.
//   A5b – W2 liveness: write2_wait_ctr < MaxWrite2Wait.
//   A6b – CMD_WRITE must appear before W2 ACK.
//=============================================================================
module sdram_prove_formal;
  (* gclk *) logic clk_i;

  (* anyseq *) logic rst_i;
  logic stb_i;
  logic we_i;
  logic [3:0] sel_i;
  logic cyc_i;
  logic [31:0] addr_i;
  logic [31:0] data_i;
  wire [31:0] data_o;
  wire stall_o;
  wire ack_o;

  wire sdram_clk_o;
  wire sdram_cke_o;
  wire sdram_cs_o;
  wire sdram_ras_o;
  wire sdram_cas_o;
  wire sdram_we_o;
  wire [1:0] sdram_dqm_o;
  wire [12:0] sdram_addr_o;
  wire [1:0] sdram_ba_o;
  wire [15:0] sdram_data_io;

  localparam int unsigned ReadLatency = 2;
  logic [ReadLatency+1:0] read_pipe = '0;

  localparam logic [31:0] AddrA = 32'h0000_0040;
  localparam logic [31:0] DataX = 32'hCAFE_BABE;
  // Expected WB read-back: core assembles beats as {low16, high16}.
  localparam logic [31:0] DataXRead = {DataX[15:0], DataX[31:16]};

  // Liveness bounds
  localparam int unsigned MaxWrite1Wait = 135; // A5:  init ~101 cy + ACTIVATE + WRITE0/1
  localparam int unsigned MaxWrite2Wait = 40;  // A5b: row-hit fast path, possible refresh overhead
  localparam int unsigned MaxReadWait   = 60;  // A2:  READ + READ_WAIT + possible refresh

  sdram #(
      .SDRAM_START_DELAY(1),
      .SDRAM_REFRESH_CYCLES(10),   // short period: refresh fires between write & read
      .SDRAM_TARGET("GENRIC")
  ) dut (
      .clk_i(clk_i),
      .rst_i(rst_i),
      .stb_i(stb_i),
      .we_i(we_i),
      .sel_i(sel_i),
      .cyc_i(cyc_i),
      .addr_i(addr_i),
      .data_i(data_i),
      .data_o(data_o),
      .stall_o(stall_o),
      .ack_o(ack_o),
      .sdram_clk_o(sdram_clk_o),
      .sdram_cke_o(sdram_cke_o),
      .sdram_cs_o(sdram_cs_o),
      .sdram_ras_o(sdram_ras_o),
      .sdram_cas_o(sdram_cas_o),
      .sdram_we_o(sdram_we_o),
      .sdram_dqm_o(sdram_dqm_o),
      .sdram_addr_o(sdram_addr_o),
      .sdram_ba_o(sdram_ba_o),
      .sdram_data_io(sdram_data_io)
  );

  //-------------------------------------------------------------------------
  // SDRAM command decode
  //  {sdram_cs_o, sdram_ras_o, sdram_cas_o, sdram_we_o}
  //  CMD_ACTIVE = 0011  CMD_READ  = 0101
  //  CMD_WRITE  = 0100  CMD_NOP   = 0111
  //  CMD_PRCHG  = 0010  CMD_RFSH  = 0001
  //-------------------------------------------------------------------------
  wire is_write_cmd  = !sdram_cs_o &&  sdram_ras_o && !sdram_cas_o && !sdram_we_o;
  wire is_read_cmd   = !sdram_cs_o &&  sdram_ras_o && !sdram_cas_o &&  sdram_we_o;
  wire is_active_cmd = !sdram_cs_o && !sdram_ras_o &&  sdram_cas_o &&  sdram_we_o;

  //-------------------------------------------------------------------------
  // Script FSM:  W1 → W2 (row-hit, same addr) → R1 → Done
  //-------------------------------------------------------------------------
  localparam logic [2:0] StWrite1Req = 3'd0;  // cold-start write (opens row)
  localparam logic [2:0] StWrite2Req = 3'd1;  // second write, row-hit
  localparam logic [2:0] StReadReq   = 3'd2;  // read-back
  localparam logic [2:0] StDone      = 3'd3;

  logic [2:0] script_state = StWrite1Req;
  logic wrote1_a = 1'b0;
  logic wrote2_a = 1'b0;
  logic read_a   = 1'b0;

  // A5 / A5b – liveness counters
  logic [7:0] write1_wait_ctr = 8'd0;
  logic [7:0] write2_wait_ctr = 8'd0;
  logic [7:0] read_wait_ctr   = 8'd0;

  // A6 / A6b – CMD_WRITE seen per phase
  logic sdram_write1_cmd_seen = 1'b0;
  logic sdram_write2_cmd_seen = 1'b0;

  // A7 – CMD_ACTIVE seen before first CMD_WRITE
  logic sdram_active_before_write = 1'b0;

  // A8 – beat-2 latch for W1
  logic write1_cmd_prev = 1'b0;

  //-------------------------------------------------------------------------
  // Reset model: start in reset, hold de-asserted thereafter
  //-------------------------------------------------------------------------
  always @(posedge clk_i) begin
    if ($initstate)
      assume(rst_i);
    else
      assume(!rst_i);
  end

  //-------------------------------------------------------------------------
  // Deterministic host script
  //-------------------------------------------------------------------------
  always_comb begin
    stb_i  = 1'b0;
    we_i   = 1'b0;
    sel_i  = 4'hF;
    cyc_i  = 1'b0;
    addr_i = AddrA;
    data_i = DataX;
    case (script_state)
      StWrite1Req: begin stb_i = 1'b1; cyc_i = 1'b1; we_i = 1'b1; end
      StWrite2Req: begin stb_i = 1'b1; cyc_i = 1'b1; we_i = 1'b1; end
      StReadReq:   begin stb_i = 1'b1; cyc_i = 1'b1; we_i = 1'b0; end
      default:     begin end
    endcase
  end

  //-------------------------------------------------------------------------
  // Tracking registers
  //-------------------------------------------------------------------------
  always @(posedge clk_i) begin
    if (rst_i) begin
      script_state              <= StWrite1Req;
      wrote1_a                  <= 1'b0;
      wrote2_a                  <= 1'b0;
      read_a                    <= 1'b0;
      write1_wait_ctr           <= 8'd0;
      write2_wait_ctr           <= 8'd0;
      read_wait_ctr             <= 8'd0;
      sdram_write1_cmd_seen     <= 1'b0;
      sdram_write2_cmd_seen     <= 1'b0;
      sdram_active_before_write <= 1'b0;
      write1_cmd_prev           <= 1'b0;
    end else begin
      // A7 tracker: CMD_ACTIVE during W1 phase
      if (is_active_cmd && script_state == StWrite1Req)
        sdram_active_before_write <= 1'b1;

      // A6 / A6b: CMD_WRITE seen per phase
      if (is_write_cmd && script_state == StWrite1Req)
        sdram_write1_cmd_seen <= 1'b1;
      if (is_write_cmd && script_state == StWrite2Req)
        sdram_write2_cmd_seen <= 1'b1;

      // A8: beat-2 latch for W1
      write1_cmd_prev <= is_write_cmd && (script_state == StWrite1Req);

      // Script advance
      if (script_state == StWrite1Req && ack_o) begin
        script_state <= StWrite2Req;
        wrote1_a     <= 1'b1;
      end else if (script_state == StWrite2Req && ack_o) begin
        script_state <= StReadReq;
        wrote2_a     <= 1'b1;
      end else if (script_state == StReadReq && ack_o) begin
        script_state <= StDone;
        read_a       <= 1'b1;
      end

      // Liveness counters
      if (script_state == StWrite1Req && !ack_o && write1_wait_ctr != 8'hFF)
        write1_wait_ctr <= write1_wait_ctr + 8'd1;
      if (script_state == StWrite2Req && !ack_o && write2_wait_ctr != 8'hFF)
        write2_wait_ctr <= write2_wait_ctr + 8'd1;
      if (script_state == StReadReq && !ack_o && read_wait_ctr != 8'hFF)
        read_wait_ctr <= read_wait_ctr + 8'd1;
    end
  end

  //-------------------------------------------------------------------------
  // Read-data modelling (assumptions on SDRAM data bus during read return)
  //-------------------------------------------------------------------------
  always @(posedge clk_i) begin
    if (rst_i)
      read_pipe <= '0;
    else
      read_pipe <= {read_pipe[ReadLatency:0], is_read_cmd};
  end

  always @(posedge clk_i) begin
    if (!rst_i && script_state == StReadReq) begin
      // if (read_pipe[ReadLatency+1])
      //  assume(sdram_data_io == DataX[15:0]);
      // else if (read_pipe[ReadLatency])
      //  assume(sdram_data_io == DataX[31:16]);
    end
  end

  //=========================================================================
  // Assertions
  //=========================================================================
  always @(posedge clk_i) begin
    if (!$initstate && !rst_i) begin

      // A1 – WB ACK sanity
      if (script_state != StDone)
        assert(!ack_o || (cyc_i && stb_i) || $past(cyc_i && stb_i));

      // A2 – Bounded read progress
      if (script_state == StReadReq && !ack_o)
        assert(read_wait_ctr < MaxReadWait);

      // A3 – RAW: returned data matches expected value on read completion
      if (read_a && !$past(read_a))
        assert(data_o == DataXRead);

      // A5 – W1 liveness
      if (script_state == StWrite1Req && !ack_o)
        assert(write1_wait_ctr < MaxWrite1Wait);

      // A5b – W2 liveness (row-hit write should be fast)
      if (script_state == StWrite2Req && !ack_o)
        assert(write2_wait_ctr < MaxWrite2Wait);

      // A6 – CMD_WRITE must appear before W1 ACK
      if (wrote1_a && !$past(wrote1_a))
        assert(sdram_write1_cmd_seen);

      // A6b – CMD_WRITE must appear before W2 ACK
      if (wrote2_a && !$past(wrote2_a))
        assert(sdram_write2_cmd_seen);

      // A7 – CMD_ACTIVE must precede first CMD_WRITE (cold start)
      if (is_write_cmd && !wrote1_a)
        assert(sdram_active_before_write);

      // A8 – Write bus data beat-1 for W1
      if (is_write_cmd && script_state == StWrite1Req)
        assert(sdram_data_io == DataX[15:0]);

      // A8 cont – Write bus data beat-2 for W1
      if (write1_cmd_prev)
        assert(sdram_data_io == DataX[31:16]);

      // A9 – No CMD_READ during W1 phase
      if (script_state == StWrite1Req)
        assert(!is_read_cmd);

      // A9b – No CMD_READ during W2 phase
      //       M012 (we_i inversion in row-hit) sends W2 to READ → caught here.
      if (script_state == StWrite2Req)
        assert(!is_read_cmd);

      // A12 – CKE must be high before first CMD_WRITE (init must complete)
      if (is_write_cmd && !wrote1_a)
        assert(sdram_cke_o);

    end
  end

  //=========================================================================
  // Cover goals
  //=========================================================================
  always @(posedge clk_i) begin
    if (!rst_i) begin
      cover(wrote1_a);
      cover(wrote2_a);
      cover(read_a);
      cover(read_a && (data_o == DataXRead));
    end
  end

endmodule

`default_nettype wire
