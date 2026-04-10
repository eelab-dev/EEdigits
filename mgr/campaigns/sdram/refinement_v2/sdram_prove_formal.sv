`default_nettype none

//=============================================================================
// SDRAM prove harness – R2
//=============================================================================
// Additions over R1:
//   A5 – Write liveness:    write ACK arrives within MaxWriteWait cycles.
//   A6 – CMD_WRITE seen:    SDRAM CMD_WRITE issued during StWriteReq phase
//                           before write ACK (kills we_i-inversion mutants).
//   A7 – ACTIVATE first:    CMD_ACTIVE on SDRAM before first CMD_WRITE
//                           (kills row-hit-skip mutants bypassing ACTIVATE).
//   A9 – No spurious READ:  CMD_READ while in StWriteReq phase is an error.
//
// Note on A8 (write bus data): sdram_data_io is an inout resolved via
// tristate in the generic target; SMT2 backend cannot assert() on it.
// Deferred to R3 via a formal SDRAM memory model.
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
  localparam int unsigned MaxReadWait  = 48;
  localparam int unsigned MaxWriteWait = 130; // A5: must be > normal ~106-cycle write path

  sdram #(
      .SDRAM_START_DELAY(1),
      .SDRAM_REFRESH_CYCLES(16),
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
  // SDRAM command decode wires
  //  Command bus: {CS, RAS, CAS, WE}
  //  CMD_NOP       = 0111  CMD_ACTIVE  = 0011
  //  CMD_READ      = 0101  CMD_WRITE   = 0100
  //  CMD_PRECHARGE = 0010  CMD_REFRESH = 0001
  //-------------------------------------------------------------------------
  wire is_write_cmd  = !sdram_cs_o &&  sdram_ras_o && !sdram_cas_o && !sdram_we_o;
  wire is_read_cmd   = !sdram_cs_o &&  sdram_ras_o && !sdram_cas_o &&  sdram_we_o;
  wire is_active_cmd = !sdram_cs_o && !sdram_ras_o &&  sdram_cas_o &&  sdram_we_o;

  //-------------------------------------------------------------------------
  // Script FSM
  //-------------------------------------------------------------------------
  localparam logic [2:0] StWriteReq  = 3'd0;
  localparam logic [2:0] StReadReq   = 3'd1;
  localparam logic [2:0] StDone      = 3'd2;

  logic [2:0] script_state = StWriteReq;
  logic wrote_a = 1'b0;
  logic read_a  = 1'b0;

  // A5 – write-phase liveness counter
  logic [7:0] write_wait_ctr = 8'd0;
  // A6 – flag: CMD_WRITE seen during write phase (before write ACK)
  logic sdram_write_cmd_seen = 1'b0;
  // A7 – flag: CMD_ACTIVE seen before first write completes
  logic sdram_active_before_write = 1'b0;
  // R1 read liveness counter
  logic [7:0] read_wait_ctr = 8'd0;

  //-------------------------------------------------------------------------
  // Reset model
  //-------------------------------------------------------------------------
  always @(posedge clk_i) begin
    if ($initstate)
      assume(rst_i);
    else
      assume(!rst_i);
  end

  //-------------------------------------------------------------------------
  // Deterministic host script: one write then one read
  //-------------------------------------------------------------------------
  always_comb begin
    stb_i  = 1'b0;
    we_i   = 1'b0;
    sel_i  = 4'hF;
    cyc_i  = 1'b0;
    addr_i = AddrA;
    data_i = DataX;
    case (script_state)
      StWriteReq: begin stb_i = 1'b1; cyc_i = 1'b1; we_i = 1'b1; end
      StReadReq:  begin stb_i = 1'b1; cyc_i = 1'b1; we_i = 1'b0; end
      default:    begin end
    endcase
  end

  //-------------------------------------------------------------------------
  // Script + tracking state update
  //-------------------------------------------------------------------------
  always @(posedge clk_i) begin
    if (rst_i) begin
      script_state              <= StWriteReq;
      wrote_a                   <= 1'b0;
      read_a                    <= 1'b0;
      write_wait_ctr            <= 8'd0;
      sdram_write_cmd_seen      <= 1'b0;
      sdram_active_before_write <= 1'b0;
      read_wait_ctr             <= 8'd0;
    end else begin
      // Track SDRAM bus events this clock
      if (is_active_cmd && script_state == StWriteReq)
        sdram_active_before_write <= 1'b1;

      if (is_write_cmd && script_state == StWriteReq)
        sdram_write_cmd_seen <= 1'b1;

      // Script advance
      if (script_state == StWriteReq && ack_o) begin
        script_state <= StReadReq;
        wrote_a      <= 1'b1;
      end else if (script_state == StReadReq && ack_o) begin
        script_state <= StDone;
        read_a       <= 1'b1;
      end

      // Counters
      if (script_state == StWriteReq && !ack_o && write_wait_ctr != 8'hFF)
        write_wait_ctr <= write_wait_ctr + 8'd1;

      if (script_state == StReadReq && !ack_o && read_wait_ctr != 8'hFF)
        read_wait_ctr <= read_wait_ctr + 8'd1;
    end
  end

  //-------------------------------------------------------------------------
  // Read-data modelling (assumptions on SDRAM data bus during read return)
  //-------------------------------------------------------------------------
  always @(posedge clk_i) begin
    if (!rst_i && script_state == StReadReq && read_pipe[ReadLatency+1])
      assume(sdram_data_io == DataX[15:0]);
    else if (!rst_i && script_state == StReadReq && read_pipe[ReadLatency])
      assume(sdram_data_io == DataX[31:16]);
  end

  always @(posedge clk_i) begin
    if (rst_i)
      read_pipe <= '0;
    else
      read_pipe <= {read_pipe[ReadLatency:0], is_read_cmd};
  end

  //=========================================================================
  // Assertions
  //=========================================================================
  always @(posedge clk_i) begin
    if (!$initstate && !rst_i) begin

      // A1 – WB ACK sanity: ACK only when a request is pending (or just ended)
      if (script_state != StDone)
        assert(!ack_o || (cyc_i && stb_i) || $past(cyc_i && stb_i));

      // A2 – Bounded read progress
      if (script_state == StReadReq && !ack_o)
        assert(read_wait_ctr < MaxReadWait);

      // A3 – RAW: data matches expected value on read completion
      if (read_a && !$past(read_a))
        assert(data_o == DataXRead);

      // A5 – Write liveness: write ACK must arrive before MaxWriteWait
      if (script_state == StWriteReq && !ack_o)
        assert(write_wait_ctr < MaxWriteWait);

      // A6 – CMD_WRITE must have appeared on the SDRAM bus before write ACK
      if (wrote_a && !$past(wrote_a))
        assert(sdram_write_cmd_seen);

      // A7 – CMD_ACTIVE must precede CMD_WRITE on a cold start
      //      (no row is open after reset; skipping ACTIVATE is wrong)
      //      Kills row-hit-skip mutants that jump directly to WRITE0
      if (is_write_cmd && !wrote_a)
        assert(sdram_active_before_write);

      // A9 – No spurious CMD_READ while still in the write phase
      //      Redundant with A6 but gives earlier counterexample traces
      if (script_state == StWriteReq)
        assert(!is_read_cmd);

    end
  end

  //=========================================================================
  // Cover goals
  //=========================================================================
  always @(posedge clk_i) begin
    if (!rst_i) begin
      cover(wrote_a);
      cover(read_a);
      cover(read_a && (data_o == DataXRead));
    end
  end

endmodule

`default_nettype wire
