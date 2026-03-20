`default_nettype none

module vga_enh_top_prove_formal;
  (* gclk *) logic CLK;

  logic wb_clk_i;
  logic clk_p_i;

  (* anyseq *) logic wb_rst_i;
  (* anyseq *) logic rst_i;
  (* anyseq *) logic [11:0] wbs_adr_i;
  (* anyseq *) logic [31:0] wbs_dat_i;
  (* anyseq *) logic [3:0] wbs_sel_i;
  (* anyseq *) logic wbs_we_i;
  (* anyseq *) logic wbs_stb_i;
  (* anyseq *) logic wbs_cyc_i;

  (* anyseq *) logic [31:0] wbm_dat_i;
  (* anyseq *) logic wbm_ack_i;
  (* anyseq *) logic wbm_err_i;

  wire wb_inta_o;
  wire [31:0] wbs_dat_o;
  wire wbs_ack_o;
  wire wbs_rty_o;
  wire wbs_err_o;

  wire [31:0] wbm_adr_o;
  wire [2:0] wbm_cti_o;
  wire [1:0] wbm_bte_o;
  wire [3:0] wbm_sel_o;
  wire wbm_we_o;
  wire wbm_stb_o;
  wire wbm_cyc_o;

  wire clk_p_o;
  wire hsync_pad_o;
  wire vsync_pad_o;
  wire csync_pad_o;
  wire blank_pad_o;
  wire [7:0] r_pad_o;
  wire [7:0] g_pad_o;
  wire [7:0] b_pad_o;

  vga_enh_top dut (
      .wb_clk_i(wb_clk_i),
      .wb_rst_i(wb_rst_i),
      .rst_i(rst_i),
      .wb_inta_o(wb_inta_o),
      .wbs_adr_i(wbs_adr_i),
      .wbs_dat_i(wbs_dat_i),
      .wbs_dat_o(wbs_dat_o),
      .wbs_sel_i(wbs_sel_i),
      .wbs_we_i(wbs_we_i),
      .wbs_stb_i(wbs_stb_i),
      .wbs_cyc_i(wbs_cyc_i),
      .wbs_ack_o(wbs_ack_o),
      .wbs_rty_o(wbs_rty_o),
      .wbs_err_o(wbs_err_o),
      .wbm_adr_o(wbm_adr_o),
      .wbm_dat_i(wbm_dat_i),
      .wbm_cti_o(wbm_cti_o),
      .wbm_bte_o(wbm_bte_o),
      .wbm_sel_o(wbm_sel_o),
      .wbm_we_o(wbm_we_o),
      .wbm_stb_o(wbm_stb_o),
      .wbm_cyc_o(wbm_cyc_o),
      .wbm_ack_i(wbm_ack_i),
      .wbm_err_i(wbm_err_i),
      .clk_p_i(clk_p_i),
      .clk_p_o(clk_p_o),
      .hsync_pad_o(hsync_pad_o),
      .vsync_pad_o(vsync_pad_o),
      .csync_pad_o(csync_pad_o),
      .blank_pad_o(blank_pad_o),
      .r_pad_o(r_pad_o),
      .g_pad_o(g_pad_o),
      .b_pad_o(b_pad_o)
  );

  assign wb_clk_i = CLK;
  assign clk_p_i = CLK;

  always @(posedge CLK) begin
    if ($initstate) begin
      assume(wb_rst_i);
      assume(rst_i);
    end
    assume(wb_rst_i == rst_i);
    assume(!(wbm_ack_i && wbm_err_i));
  end

  always @(posedge CLK) begin
    assert(wb_clk_i == clk_p_i);
    assert(!(wbm_ack_i && wbm_err_i));
  end

  always @(posedge CLK) begin
    if (!$initstate && !wb_rst_i) begin
      cover(wbs_cyc_i && wbs_stb_i);
      cover(wbs_ack_o);
      cover(wbm_cyc_o);
    end
  end
endmodule

`default_nettype wire
