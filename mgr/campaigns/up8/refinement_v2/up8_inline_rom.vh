// Inline ROM contents for the add-1 loop program (N=10).
// This file is included inside the uP8 CPU's memory init when UP8_INLINE_ROM is defined.

mem[16'h0000] = 8'h20; // MOVI R0, 0x00
mem[16'h0001] = 8'h00;
mem[16'h0002] = 8'h21; // MOVI R1, 0x0A
mem[16'h0003] = 8'h0A;
mem[16'h0004] = 8'h60; // ADDI R0, 0x01
mem[16'h0005] = 8'h01;
mem[16'h0006] = 8'h81; // SUBI R1, 0x01
mem[16'h0007] = 8'h01;
mem[16'h0008] = 8'h92; // JNZ  0x0004
mem[16'h0009] = 8'h04;
mem[16'h000A] = 8'h00;
mem[16'h000B] = 8'hFF; // HALT
