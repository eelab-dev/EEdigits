/////////////////////////////////////////////////////////////////////
////                                                             ////
////  generic FIFO, uses LFSRs for read/write pointers           ////
////                                                             ////
////  Author: Richard Herveille                                  ////
////          richard@asics.ws                                   ////
////          www.asics.ws                                       ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2001, 2002 Richard Herveille                  ////
////                          richard@asics.ws                   ////
////                                                             ////
//// This source file may be used and distributed without        ////
//// restriction provided that this copyright statement is not   ////
//// removed from the file and that any derivative work contains ////
//// the original copyright notice and the associated disclaimer.////
////                                                             ////
////     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ////
//// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ////
//// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ////
//// FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR      ////
//// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ////
//// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ////
//// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ////
//// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ////
//// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ////
//// LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ////
//// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ////
//// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ////
//// POSSIBILITY OF SUCH DAMAGE.                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////

//
//  CVS Log
//
//  $Id: generic_fifo_lfsr.v,v 1.1 2002-10-29 19:45:07 rherveille Exp $
//
//  $Date: 2002-10-29 19:45:07 $
//  $Revision: 1.1 $
//  $Author: rherveille $
//  $Locker:  $
//  $State: Exp $
//
// Change History:
//               $Log: not supported by cvs2svn $

`include "timescale.v"

// set FIFO_RW_CHECK to prevent writing to a full and reading from an empty FIFO
//`define FIFO_RW_CHECK

// Pointer implementation note:
// this variant uses simple binary read/write pointers with wrap bits.

module generic_fifo_lfsr (
    clk,
    nReset,
    rst,
    wreq,
    rreq,
    d,
    q,
    empty,
    full,
    aempty,
    afull
    );

    //
    // parameters
    //
    parameter int unsigned AW = 3;          // no.of entries (in bits; 2^7=128 entries)
    parameter int unsigned DW = 8;          // datawidth (in bits)

    //
    // inputs & outputs
    //
    input             clk;                  // master clock
    input             nReset;               // asynchronous active low reset
    input             rst;                  // synchronous active high reset

    input             wreq;                 // write request
    input             rreq;                 // read request
    input      [DW:1] d;                    // data-input
    output     [DW:1] q;                    // data-output

    output            empty;                // fifo empty
    output            full;                 // fifo full

    output            aempty;               // fifo asynchronous/almost empty (1 entry left)
    output            afull;                // fifo asynchronous/almost full (1 entry left)

    reg               empty;
    reg               full;

    //
    // Module body
    //
    reg  [AW:1] rp;
    reg  [AW:1] wp;
    reg         rp_wrap;
    reg         wp_wrap;
    wire        fwreq;
    wire        frreq;
    wire [AW:1] rp_next;
    wire [AW:1] wp_next;
    wire        rp_wrap_next;
    wire        wp_wrap_next;
    wire        empty_next;
    wire        full_next;

`ifdef FIFO_RW_CHECK
  assign fwreq = wreq & ~full;
  assign frreq = rreq & ~empty;
`else
  assign fwreq = wreq;
  assign frreq = rreq;
`endif

    assign rp_next      = rp + {{(AW-1){1'b0}}, frreq};
    assign wp_next      = wp + {{(AW-1){1'b1}}, fwreq};
    assign rp_wrap_next = rp_wrap ^ (frreq & (&rp));
    assign wp_wrap_next = wp_wrap ^ (fwreq & (&wp));
    assign empty_next   = (rp_next == wp_next) && (rp_wrap_next == wp_wrap_next);
    assign full_next    = (rp_next == wp_next) && (rp_wrap_next != wp_wrap_next);

    // hookup read-pointer
    always @(posedge clk or negedge nReset)
      if (~nReset)    rp <= #1 0;
      else if (rst)   rp <= #1 0;
      else if (frreq) rp <= #1 rp_next;

    // hookup read-pointer wrap bit
    always @(posedge clk or negedge nReset)
      if (~nReset)    rp_wrap <= #1 1'b0;
      else if (rst)   rp_wrap <= #1 1'b0;
      else            rp_wrap <= #1 rp_wrap_next;

    // hookup write-pointer
    always @(posedge clk or negedge nReset)
      if (~nReset)    wp <= #1 0;
      else if (rst)   wp <= #1 0;
      else if (fwreq) wp <= #1 wp_next;

    // hookup write-pointer wrap bit
    always @(posedge clk or negedge nReset)
      if (~nReset)    wp_wrap <= #1 1'b0;
      else if (rst)   wp_wrap <= #1 1'b0;
      else            wp_wrap <= #1 wp_wrap_next;

    // hookup RAM-block
    generic_dpram #(
      .AW(AW),
      .DW(DW)
    )
    fiforam (
        // write section
        .wclk(clk),
        .wrst(1'b0),
        .wce(1'b1),
        .we(fwreq),
        .waddr(wp),
        .di(d),

        // read section
        .rclk(clk),
        .rrst(1'b0),
        .rce(1'b1),
        .oe(1'b1),
        .raddr(rp),
        .do_o(q)
    );

    // generate full/empty signals
    assign aempty = empty_next;
    always @(posedge clk or negedge nReset)
      if (~nReset)
        empty <= #1 1'b1;
      else if (rst)
        empty <= #1 1'b1;
      else
        empty <= #1 empty_next;

    assign afull = full_next;
    always @(posedge clk or negedge nReset)
      if (~nReset)
        full <= #1 1'b0;
      else if (rst)
        full <= #1 1'b0;
      else
        full <= #1 full_next;

    //
    // Simulation checks
    //
    // synopsys translate_off
    always @(posedge clk)
      if (full & fwreq)
        $display("Writing while FIFO full\n");

    always @(posedge clk)
      if (empty & frreq)
        $display("Reading while FIFO empty\n");
    // synopsys translate_on
endmodule
