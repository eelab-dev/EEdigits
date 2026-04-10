// Formal harness for CNORM normalisation unit
// Target module : CNORM (cnorm.v, nb=10 from FFT256_CONFIG.inc)
// Campaign      : pipelined_fft_256 / refinement_v1
//
// CNORM port summary (nb=10):
//   Inputs : CLK, ED, START, DR[13:0], DI[13:0], SHIFT[1:0]
//   Outputs: OVF, RDY, DOR[11:0], DOI[11:0]
//
// Pipeline depth: 1 clock when ED=1.
// All assertions are 1-cycle properties using $past().
`default_nettype none

module cnorm_prove_formal;

    // ---------- free variables ----------
    (* gclk *) logic CLK;

    (* anyseq *) logic        ED;
    (* anyseq *) logic        START;
    (* anyseq *) logic [13:0] DR;   // nb+3:0 = 13:0
    (* anyseq *) logic [13:0] DI;
    (* anyseq *) logic [1:0]  SHIFT;

    // ---------- DUT outputs ----------
    wire        OVF;
    wire        RDY;
    wire [11:0] DOR;   // nb+1:0 = 11:0
    wire [11:0] DOI;

    // ---------- DUT instantiation ----------
    CNORM dut (
        .CLK   (CLK),
        .ED    (ED),
        .START (START),
        .DR    (DR),
        .DI    (DI),
        .SHIFT (SHIFT),
        .OVF   (OVF),
        .RDY   (RDY),
        .DOR   (DOR),
        .DOI   (DOI)
    );

    // ---------- convenience aliases (nb=10) ----------
    localparam NB = 10;

    // =========================================================
    // ASSERTIONS
    // All use $past() – fire only after at least one clock edge.
    // Written as always @(posedge CLK) procedural assertions.
    // =========================================================

    // A_rdy : RDY is START delayed by exactly one ED-gated cycle.
    //         Kills M005 (ED inversion in OVF/RDY block).
    always @(posedge CLK) begin
        if (!$initstate && $past(ED))
            A_rdy: assert(RDY == $past(START));
    end

    // A_ovf_clr : OVF must be 0 one cycle after START=1 (with ED=1).
    //             Kills M006 (START condition inversion).
    always @(posedge CLK) begin
        if (!$initstate && $past(START) && $past(ED))
            A_ovf_clr: assert(OVF == 1'b0);
    end

    // A_ovf_shift1_ok : SHIFT=01, no sign-extension bits lost → OVF=0.
    //   Checks DR[nb+3]==DR[nb+2] and DI[nb+3]==DI[nb+2] (1-bit check).
    //   Kills M007 (flips != to == so OVF fires on equal signs).
    always @(posedge CLK) begin
        if (!$initstate && $past(ED) && !$past(START) && $past(SHIFT) == 2'b01 &&
            $past(DR[NB+3]) == $past(DR[NB+2]) &&
            $past(DI[NB+3]) == $past(DI[NB+2]))
            A_ovf_shift1_ok: assert(OVF == 1'b0);
    end

    // A_ovf_shift2_ok : SHIFT=10, all sign+guard bits match → OVF=0.
    //   Checks DR[13]==DR[12]==DR[11] and DI equivalents.
    //   Kills M008, M009 (equality flips) and M015 (index DR[11]→DR[10]).
    always @(posedge CLK) begin
        if (!$initstate && $past(ED) && !$past(START) && $past(SHIFT) == 2'b10 &&
            $past(DR[NB+3]) == $past(DR[NB+2]) &&
            $past(DI[NB+3]) == $past(DI[NB+2]) &&
            $past(DR[NB+3]) == $past(DR[NB+1]) &&
            $past(DI[NB+3]) == $past(DI[NB+1]))
            A_ovf_shift2_ok: assert(OVF == 1'b0);
    end

    // A_ovf_shift3_ok : SHIFT=11, all three sign+guard bits match → OVF=0.
    //   Checks DR[13]==DR[12]==DR[11]==DR[10] and DI equivalents.
    //   Kills M010 (flip != to == on first DR check),
    //         M011 (flip != to == on DR[nb] = DR[10] check),
    //         M012 (flip != to == on DR[nb+1] = DR[11] check),
    //         M016 (index DR[11]→DR[10]).
    always @(posedge CLK) begin
        if (!$initstate && $past(ED) && !$past(START) && $past(SHIFT) == 2'b11 &&
            $past(DR[NB+3]) == $past(DR[NB+2]) &&
            $past(DI[NB+3]) == $past(DI[NB+2]) &&
            $past(DR[NB+3]) == $past(DR[NB+1]) &&
            $past(DI[NB+3]) == $past(DI[NB+1]) &&
            $past(DR[NB+3]) == $past(DR[NB])   &&
            $past(DI[NB+3]) == $past(DI[NB]))
            A_ovf_shift3_ok: assert(OVF == 1'b0);
    end

    // A_shift0_neg_even_dr : SHIFT=00, negative (DR[13]=1) even (DR[0]=0) input.
    //   Truncation path's negative-and-even branch takes dir=diri (no round-up).
    //   DOR should equal DR[13:2] exactly.
    //   Kills M002 (ED inversion in truncation block),
    //         M003 (predicate inversion on rounding condition for DR),
    //         M013/M019 (output width narrowed – MSB bit 11 lost),
    //         M017 (index DR[0]→DR[1] in rounding condition).
    always @(posedge CLK) begin
        if (!$initstate && $past(ED) &&
            $past(SHIFT) == 2'b00 &&
            $past(DR[NB+3]) == 1'b1 &&    // negative
            $past(DR[0])    == 1'b0)        // even (LSB=0)
            A_shift0_neg_even_dr: assert(DOR == $past(DR[NB+3:2]));
    end

    // A_shift0_neg_even_di : same guarantee for the DI/DOI path.
    //   Kills M002, M004, M014/M020, M018.
    always @(posedge CLK) begin
        if (!$initstate && $past(ED) &&
            $past(SHIFT) == 2'b00 &&
            $past(DI[NB+3]) == 1'b1 &&
            $past(DI[0])    == 1'b0)
            A_shift0_neg_even_di: assert(DOI == $past(DI[NB+3:2]));
    end

endmodule

`default_nettype wire
