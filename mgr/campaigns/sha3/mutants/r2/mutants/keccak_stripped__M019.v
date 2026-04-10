

`define LOW_POS(w,b)      ((w)*64 + (b)*8)
`define LOW_POS2(w,b)     `LOW_POS(w,7-b)
`define HIGH_POS(w,b)     (`LOW_POS(w,b) + 7)
`define HIGH_POS2(w,b)    (`LOW_POS2(w,b) + 7)

module keccak(clk, reset, in, in_ready, is_last, byte_num, buffer_full, out, out_ready);
    input              clk, reset;
    input      [63:0]  in;
    input              in_ready, is_last;
    input      [2:0]   byte_num;
    output             buffer_full; 
    output     [511:0] out;
    output reg         out_ready;

    reg                state;     
    wire       [575:0] padder_out,
                       padder_out_1; 
    wire               padder_out_ready;
    wire               f_ack;
    wire      [1599:0] f_out;
    wire               f_out_ready;
    wire       [511:0] out1;      
    reg        [10:0]  i;         
    genvar w, b;

    assign out1 = f_out[1599:1599-511];

    always @ (posedge clk)
      if (reset)
        i <= 0;
      else
        i <= {i[9:0], state & f_ack};

    always @ (posedge clk)
      if (reset)
        state <= 0;
      else if (is_last)
        state <= 1;

    
    generate
      for(w=0; w<8; w=w+1)
        begin : g_l0
          for(b=0; b<8; b=b+1)
            begin : g_l1
              assign out[`HIGH_POS(w,b):`LOW_POS(w,b)] =
                     out1[`HIGH_POS2(w,b):`LOW_POS2(w,b)];
            end
        end
    endgenerate

    generate
      for(w=0; w<9; w=w+1)
        begin : g_l2
          for(b=1; b<8; b=b+1)
            begin : g_l3
              assign padder_out[`HIGH_POS(w,b):`LOW_POS(w,b)] =
                     padder_out_1[`HIGH_POS2(w,b):`LOW_POS2(w,b)];
            end
        end
    endgenerate

    always @ (posedge clk)
      if (reset)
        out_ready <= 0;
      else if (i[10])
        out_ready <= 1;

    padder padder_ (
      .clk         (clk),
      .reset       (reset),
      .in          (in),
      .in_ready    (in_ready),
      .is_last     (is_last),
      .byte_num    (byte_num),
      .buffer_full (buffer_full),
      .out         (padder_out_1),
      .out_ready   (padder_out_ready),
      .f_ack       (f_ack)
    );

    f_permutation f_permutation_ (
      .clk      (clk),
      .reset    (reset),
      .in       (padder_out),
      .in_ready (padder_out_ready),
      .ack      (f_ack),
      .out      (f_out),
      .out_ready(f_out_ready)
    );
endmodule

`undef LOW_POS
`undef LOW_POS2
`undef HIGH_POS
`undef HIGH_POS2
