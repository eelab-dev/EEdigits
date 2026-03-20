`default_nettype none

//=============================================================================
// SDRAM cover harness
//=============================================================================
// Intent:
// - Exercise one WB write then one WB read to the same address.
// - Cover transaction milestones and successful readback.
// - Keep the same bus/model assumptions as the prove harness.
//=============================================================================
module sdram_cover_formal;
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
  // Expected WB read word ordering for this core's two-beat assembly.
  localparam logic [31:0] DataXRead = {DataX[15:0], DataX[31:16]};

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
    end else begin
      if (script_state == StWriteReq && ack_o) begin
        script_state <= StReadReq;
        wrote_a <= 1'b1;
      end else if (script_state == StReadReq && ack_o) begin
        script_state <= StDone;
        read_a <= 1'b1;
      end
    end
  end

  // Track READ command issue timing for read data assumptions.
  always @(posedge clk_i) begin
    if (rst_i) begin
      read_pipe <= '0;
    end else begin
      read_pipe <= {read_pipe[ReadLatency:0], (!sdram_cs_o && !sdram_cas_o && sdram_we_o)};
    end
  end

  always @(posedge clk_i) begin
    // Basic WB acknowledge sanity.
    if (!$initstate) begin
      assert(!ack_o || (cyc_i && stb_i));
    end

    // SDRAM read-data modeling assumptions.
    if (!rst_i && script_state == StReadReq && read_pipe[ReadLatency+1]) begin
      assume(sdram_data_io == DataX[15:0]);
    end else if (!rst_i && script_state == StReadReq && read_pipe[ReadLatency]) begin
      assume(sdram_data_io == DataX[31:16]);
    end
  end

  always @(posedge clk_i) begin
    if (!rst_i) begin
      cover(wrote_a);
      cover(read_a);
      cover(read_a && (data_o == DataXRead));
      cover(script_state == StDone);
    end
  end
endmodule

`default_nettype wire
