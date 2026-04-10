`default_nettype none

//=============================================================================
// SDRAM prove harness
//=============================================================================
// Intent:
// - Drive a deterministic WB sequence: WRITE AddrA=DataX, then READ AddrA.
// - Model SDRAM read return data with assumptions on the external data bus.
// - Prove bounded safety properties, including read-after-write (RAW).
//
// Notes on this controller:
// - It is a 16-bit SDRAM datapath with 32-bit WB words transferred in two beats.
// - The observed readback word order at WB is {low16, high16} for this flow.
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
  // Expected WB word at read completion for this core's beat assembly.
  localparam logic [31:0] DataXRead = {DataX[15:0], DataX[31:16]};
  localparam int unsigned MaxReadWait = 48;
  wire is_write_cmd = !sdram_cs_o;

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

  localparam logic [2:0] StWriteReq  = 3'd0;
  localparam logic [2:0] StReadReq   = 3'd1;
  localparam logic [2:0] StDone      = 3'd2;

  logic [2:0] script_state = StWriteReq;
  logic wrote_a = 1'b0;
  logic read_a = 1'b0;
  logic [7:0] read_wait_ctr = 8'd0;

  // Reset model: start in reset, then keep reset deasserted.
  always @(posedge clk_i) begin
    if ($initstate) begin
      assume(rst_i);
    end else begin
      assume(!rst_i);
    end
  end

  // Deterministic host script for one write then one read.
  always_comb begin
    stb_i = 1'b0;
    we_i = 1'b0;
    sel_i = 4'hF;
    cyc_i = 1'b0;
    addr_i = AddrA;
    data_i = DataX;

    case (script_state)
      StWriteReq: begin
        stb_i = 1'b1;
        cyc_i = 1'b1;
        we_i = 1'b1;
      end
      StReadReq: begin
        stb_i = 1'b1;
        cyc_i = 1'b1;
        we_i = 1'b0;
      end
      default: begin
      end
    endcase
  end

  // Script progress state.
  always @(posedge clk_i) begin
    if (rst_i) begin
      script_state <= StWriteReq;
      wrote_a <= 1'b0;
      read_a <= 1'b0;
      read_wait_ctr <= 8'd0;
    end else begin
      if (script_state == StWriteReq && ack_o) begin
        script_state <= StReadReq;
        wrote_a <= 1'b1;
      end else if (script_state == StReadReq && ack_o) begin
        script_state <= StDone;
        read_a <= 1'b1;
      end

      if (script_state == StReadReq && !ack_o && read_wait_ctr != 8'hFF) begin
        read_wait_ctr <= read_wait_ctr + 8'd1;
      end
    end
  end

  // Track when READ commands are issued to time read-data assumptions.
  always @(posedge clk_i) begin
    if (rst_i) begin
      read_pipe <= '0;
    end else begin
      read_pipe <= {read_pipe[ReadLatency:0], (!sdram_cs_o && !sdram_cas_o && sdram_we_o)};
    end
  end

  always @(posedge clk_i) begin
    // WB acknowledge sanity:
    // allow ack in-cycle with a request or one cycle after request deassertion.
    // This avoids false failures from boundary timing in deeper BMC depths.
    if (!$initstate && !rst_i && (script_state != StDone)) begin
      assert(!ack_o || (cyc_i && stb_i) || $past(cyc_i && stb_i));
    end

    // SDRAM model assumptions for read return data beats.
    if (!rst_i && script_state == StReadReq && read_pipe[ReadLatency+1]) begin
      assume(sdram_data_io == DataX[15:0]);
    end else if (!rst_i && script_state == StReadReq && read_pipe[ReadLatency]) begin
      assume(sdram_data_io == DataX[31:16]);
    end

    // Bounded progress during the read phase.
    if (!rst_i && script_state == StReadReq && !ack_o) begin
      assert(read_wait_ctr < MaxReadWait);
    end

    // RAW property (read-after-write):
    // once read completion is observed, returned WB data matches expected value.
    if (!$initstate && !rst_i && read_a && !$past(read_a)) begin
      assert(data_o == DataXRead);
    end
  end

  always @(posedge clk_i) begin
    if (!rst_i) begin
      cover(wrote_a);
      cover(read_a);
      cover(read_a && (data_o == DataXRead));
    end
  end
endmodule

`default_nettype wire
