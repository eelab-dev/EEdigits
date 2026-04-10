`default_nettype none

module up8_add1_formal;
  (* gclk *) logic clk;
  logic rst;

  wire [15:0] pc;
  wire z;
  wire c;
  wire halted;
  wire [7:0] r0, r1, r2, r3;

    // Keep memory small for tractable proofs; program only touches low addresses.
    up8_cpu #(
      .MEM_SIZE(256),
      .MEM_INIT_FILE("")
    ) dut (
      .clk(clk),
      .rst(rst),
      .pc(pc),
      .z(z),
      .c(c),
      .halted(halted),
      .r0(r0),
      .r1(r1),
      .r2(r2),
      .r3(r3)
  );

  // Reset assumptions: asserted in initstate only
  always_ff @(posedge clk) begin
    if ($initstate) begin
      assume(rst);
    end else begin
      assume(!rst);
    end
  end

  // With MEM_SIZE=256, constrain the control flow to remain in range.
  always_ff @(posedge clk) begin
    if (!rst) begin
      assume(pc < 16'd256);
    end
  end

  // Cycle counter after reset is released
  logic [7:0] cyc;
  always_ff @(posedge clk) begin
    if (rst) begin
      cyc <= 8'd0;
    end else begin
      cyc <= cyc + 8'd1;
    end
  end

  // Bounded correctness:
  // By cycle 40 after reset deassertion, the program must have halted and
  // produced the expected registers.
  always_ff @(posedge clk) begin
    if (!rst) begin
      cover(halted);

      if (cyc == 8'd40) begin
        assert(halted);
        assert(r0 == 8'd10);
        assert(r1 == 8'd0);
      end
    end
  end
endmodule

`default_nettype wire
