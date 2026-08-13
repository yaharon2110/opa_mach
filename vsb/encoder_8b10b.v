// ============================================================================
// Module Name:  encoder_8b10b
// Description:  8b/10b encoder implemented as an explicit lookup table,
//               generated mechanically from a verified reference table
//               (freecores/1000base-x testbench/data/8b10b.dat, itself
//               cross-checked against the TLK1221 datasheet's own quoted
//               K28.5 comma pattern). Replaces the earlier hand-derived
//               boolean-equation implementation (see V-13/V-14 -- that
//               version failed exhaustive round-trip verification and
//               did not produce a TLK1221-recognizable K28.5 comma).
//               Every (kin,byte) entry below was exhaustively round-trip
//               verified in Python against this same table before this
//               file was generated -- see gen_8b10b.py / run_full_check_v2.py.
// Standards:    Verilog-2001 Standard Baseline
// ============================================================================

`timescale 1ns / 1ps

module encoder_8b10b (
    input  wire        clk,      // 81 MHz primary transmit clock
    input  wire        rst_n,    // Active-low synchronized reset
    input  wire [7:0]  din,      // 8-bit input character byte
    input  wire        kin,      // Control bit (1 = K-character, 0 = D-data)
    output reg  [9:0]  dout      // 10-bit balanced output TBI codeword
);

    reg disparity;   // Running disparity: 0 = RD-, 1 = RD+

    reg [9:0] cw_rd_minus;
    reg [9:0] cw_rd_plus;
    reg       disp_changes;

    always @(*) begin
        case ({kin, din})
            9'b000000000: begin cw_rd_minus = 10'b0010111001; cw_rd_plus = 10'b1101000110; disp_changes = 1'b0; end  // D byte=0x00
            9'b000000001: begin cw_rd_minus = 10'b0010101110; cw_rd_plus = 10'b1101010001; disp_changes = 1'b0; end  // D byte=0x01
            9'b000000010: begin cw_rd_minus = 10'b0010101101; cw_rd_plus = 10'b1101010010; disp_changes = 1'b0; end  // D byte=0x02
            9'b000000011: begin cw_rd_minus = 10'b1101100011; cw_rd_plus = 10'b0010100011; disp_changes = 1'b1; end  // D byte=0x03
            9'b000000100: begin cw_rd_minus = 10'b0010101011; cw_rd_plus = 10'b1101010100; disp_changes = 1'b0; end  // D byte=0x04
            9'b000000101: begin cw_rd_minus = 10'b1101100101; cw_rd_plus = 10'b0010100101; disp_changes = 1'b1; end  // D byte=0x05
            9'b000000110: begin cw_rd_minus = 10'b1101100110; cw_rd_plus = 10'b0010100110; disp_changes = 1'b1; end  // D byte=0x06
            9'b000000111: begin cw_rd_minus = 10'b1101000111; cw_rd_plus = 10'b0010111000; disp_changes = 1'b1; end  // D byte=0x07
            9'b000001000: begin cw_rd_minus = 10'b0010100111; cw_rd_plus = 10'b1101011000; disp_changes = 1'b0; end  // D byte=0x08
            9'b000001001: begin cw_rd_minus = 10'b1101101001; cw_rd_plus = 10'b0010101001; disp_changes = 1'b1; end  // D byte=0x09
            9'b000001010: begin cw_rd_minus = 10'b1101101010; cw_rd_plus = 10'b0010101010; disp_changes = 1'b1; end  // D byte=0x0A
            9'b000001011: begin cw_rd_minus = 10'b1101001011; cw_rd_plus = 10'b0010001011; disp_changes = 1'b1; end  // D byte=0x0B
            9'b000001100: begin cw_rd_minus = 10'b1101101100; cw_rd_plus = 10'b0010101100; disp_changes = 1'b1; end  // D byte=0x0C
            9'b000001101: begin cw_rd_minus = 10'b1101001101; cw_rd_plus = 10'b0010001101; disp_changes = 1'b1; end  // D byte=0x0D
            9'b000001110: begin cw_rd_minus = 10'b1101001110; cw_rd_plus = 10'b0010001110; disp_changes = 1'b1; end  // D byte=0x0E
            9'b000001111: begin cw_rd_minus = 10'b0010111010; cw_rd_plus = 10'b1101000101; disp_changes = 1'b0; end  // D byte=0x0F
            9'b000010000: begin cw_rd_minus = 10'b0010110110; cw_rd_plus = 10'b1101001001; disp_changes = 1'b0; end  // D byte=0x10
            9'b000010001: begin cw_rd_minus = 10'b1101110001; cw_rd_plus = 10'b0010110001; disp_changes = 1'b1; end  // D byte=0x11
            9'b000010010: begin cw_rd_minus = 10'b1101110010; cw_rd_plus = 10'b0010110010; disp_changes = 1'b1; end  // D byte=0x12
            9'b000010011: begin cw_rd_minus = 10'b1101010011; cw_rd_plus = 10'b0010010011; disp_changes = 1'b1; end  // D byte=0x13
            9'b000010100: begin cw_rd_minus = 10'b1101110100; cw_rd_plus = 10'b0010110100; disp_changes = 1'b1; end  // D byte=0x14
            9'b000010101: begin cw_rd_minus = 10'b1101010101; cw_rd_plus = 10'b0010010101; disp_changes = 1'b1; end  // D byte=0x15
            9'b000010110: begin cw_rd_minus = 10'b1101010110; cw_rd_plus = 10'b0010010110; disp_changes = 1'b1; end  // D byte=0x16
            9'b000010111: begin cw_rd_minus = 10'b0010010111; cw_rd_plus = 10'b1101101000; disp_changes = 1'b0; end  // D byte=0x17
            9'b000011000: begin cw_rd_minus = 10'b0010110011; cw_rd_plus = 10'b1101001100; disp_changes = 1'b0; end  // D byte=0x18
            9'b000011001: begin cw_rd_minus = 10'b1101011001; cw_rd_plus = 10'b0010011001; disp_changes = 1'b1; end  // D byte=0x19
            9'b000011010: begin cw_rd_minus = 10'b1101011010; cw_rd_plus = 10'b0010011010; disp_changes = 1'b1; end  // D byte=0x1A
            9'b000011011: begin cw_rd_minus = 10'b0010011011; cw_rd_plus = 10'b1101100100; disp_changes = 1'b0; end  // D byte=0x1B
            9'b000011100: begin cw_rd_minus = 10'b1101011100; cw_rd_plus = 10'b0010011100; disp_changes = 1'b1; end  // D byte=0x1C
            9'b000011101: begin cw_rd_minus = 10'b0010011101; cw_rd_plus = 10'b1101100010; disp_changes = 1'b0; end  // D byte=0x1D
            9'b000011110: begin cw_rd_minus = 10'b0010011110; cw_rd_plus = 10'b1101100001; disp_changes = 1'b0; end  // D byte=0x1E
            9'b000011111: begin cw_rd_minus = 10'b0010110101; cw_rd_plus = 10'b1101001010; disp_changes = 1'b0; end  // D byte=0x1F
            9'b000100000: begin cw_rd_minus = 10'b1001111001; cw_rd_plus = 10'b1001000110; disp_changes = 1'b1; end  // D byte=0x20
            9'b000100001: begin cw_rd_minus = 10'b1001101110; cw_rd_plus = 10'b1001010001; disp_changes = 1'b1; end  // D byte=0x21
            9'b000100010: begin cw_rd_minus = 10'b1001101101; cw_rd_plus = 10'b1001010010; disp_changes = 1'b1; end  // D byte=0x22
            9'b000100011: begin cw_rd_minus = 10'b1001100011; cw_rd_plus = 10'b1001100011; disp_changes = 1'b0; end  // D byte=0x23
            9'b000100100: begin cw_rd_minus = 10'b1001101011; cw_rd_plus = 10'b1001010100; disp_changes = 1'b1; end  // D byte=0x24
            9'b000100101: begin cw_rd_minus = 10'b1001100101; cw_rd_plus = 10'b1001100101; disp_changes = 1'b0; end  // D byte=0x25
            9'b000100110: begin cw_rd_minus = 10'b1001100110; cw_rd_plus = 10'b1001100110; disp_changes = 1'b0; end  // D byte=0x26
            9'b000100111: begin cw_rd_minus = 10'b1001000111; cw_rd_plus = 10'b1001111000; disp_changes = 1'b0; end  // D byte=0x27
            9'b000101000: begin cw_rd_minus = 10'b1001100111; cw_rd_plus = 10'b1001011000; disp_changes = 1'b1; end  // D byte=0x28
            9'b000101001: begin cw_rd_minus = 10'b1001101001; cw_rd_plus = 10'b1001101001; disp_changes = 1'b0; end  // D byte=0x29
            9'b000101010: begin cw_rd_minus = 10'b1001101010; cw_rd_plus = 10'b1001101010; disp_changes = 1'b0; end  // D byte=0x2A
            9'b000101011: begin cw_rd_minus = 10'b1001001011; cw_rd_plus = 10'b1001001011; disp_changes = 1'b0; end  // D byte=0x2B
            9'b000101100: begin cw_rd_minus = 10'b1001101100; cw_rd_plus = 10'b1001101100; disp_changes = 1'b0; end  // D byte=0x2C
            9'b000101101: begin cw_rd_minus = 10'b1001001101; cw_rd_plus = 10'b1001001101; disp_changes = 1'b0; end  // D byte=0x2D
            9'b000101110: begin cw_rd_minus = 10'b1001001110; cw_rd_plus = 10'b1001001110; disp_changes = 1'b0; end  // D byte=0x2E
            9'b000101111: begin cw_rd_minus = 10'b1001111010; cw_rd_plus = 10'b1001000101; disp_changes = 1'b1; end  // D byte=0x2F
            9'b000110000: begin cw_rd_minus = 10'b1001110110; cw_rd_plus = 10'b1001001001; disp_changes = 1'b1; end  // D byte=0x30
            9'b000110001: begin cw_rd_minus = 10'b1001110001; cw_rd_plus = 10'b1001110001; disp_changes = 1'b0; end  // D byte=0x31
            9'b000110010: begin cw_rd_minus = 10'b1001110010; cw_rd_plus = 10'b1001110010; disp_changes = 1'b0; end  // D byte=0x32
            9'b000110011: begin cw_rd_minus = 10'b1001010011; cw_rd_plus = 10'b1001010011; disp_changes = 1'b0; end  // D byte=0x33
            9'b000110100: begin cw_rd_minus = 10'b1001110100; cw_rd_plus = 10'b1001110100; disp_changes = 1'b0; end  // D byte=0x34
            9'b000110101: begin cw_rd_minus = 10'b1001010101; cw_rd_plus = 10'b1001010101; disp_changes = 1'b0; end  // D byte=0x35
            9'b000110110: begin cw_rd_minus = 10'b1001010110; cw_rd_plus = 10'b1001010110; disp_changes = 1'b0; end  // D byte=0x36
            9'b000110111: begin cw_rd_minus = 10'b1001010111; cw_rd_plus = 10'b1001101000; disp_changes = 1'b1; end  // D byte=0x37
            9'b000111000: begin cw_rd_minus = 10'b1001110011; cw_rd_plus = 10'b1001001100; disp_changes = 1'b1; end  // D byte=0x38
            9'b000111001: begin cw_rd_minus = 10'b1001011001; cw_rd_plus = 10'b1001011001; disp_changes = 1'b0; end  // D byte=0x39
            9'b000111010: begin cw_rd_minus = 10'b1001011010; cw_rd_plus = 10'b1001011010; disp_changes = 1'b0; end  // D byte=0x3A
            9'b000111011: begin cw_rd_minus = 10'b1001011011; cw_rd_plus = 10'b1001100100; disp_changes = 1'b1; end  // D byte=0x3B
            9'b000111100: begin cw_rd_minus = 10'b1001011100; cw_rd_plus = 10'b1001011100; disp_changes = 1'b0; end  // D byte=0x3C
            9'b000111101: begin cw_rd_minus = 10'b1001011101; cw_rd_plus = 10'b1001100010; disp_changes = 1'b1; end  // D byte=0x3D
            9'b000111110: begin cw_rd_minus = 10'b1001011110; cw_rd_plus = 10'b1001100001; disp_changes = 1'b1; end  // D byte=0x3E
            9'b000111111: begin cw_rd_minus = 10'b1001110101; cw_rd_plus = 10'b1001001010; disp_changes = 1'b1; end  // D byte=0x3F
            9'b001000000: begin cw_rd_minus = 10'b1010111001; cw_rd_plus = 10'b1010000110; disp_changes = 1'b1; end  // D byte=0x40
            9'b001000001: begin cw_rd_minus = 10'b1010101110; cw_rd_plus = 10'b1010010001; disp_changes = 1'b1; end  // D byte=0x41
            9'b001000010: begin cw_rd_minus = 10'b1010101101; cw_rd_plus = 10'b1010010010; disp_changes = 1'b1; end  // D byte=0x42
            9'b001000011: begin cw_rd_minus = 10'b1010100011; cw_rd_plus = 10'b1010100011; disp_changes = 1'b0; end  // D byte=0x43
            9'b001000100: begin cw_rd_minus = 10'b1010101011; cw_rd_plus = 10'b1010010100; disp_changes = 1'b1; end  // D byte=0x44
            9'b001000101: begin cw_rd_minus = 10'b1010100101; cw_rd_plus = 10'b1010100101; disp_changes = 1'b0; end  // D byte=0x45
            9'b001000110: begin cw_rd_minus = 10'b1010100110; cw_rd_plus = 10'b1010100110; disp_changes = 1'b0; end  // D byte=0x46
            9'b001000111: begin cw_rd_minus = 10'b1010000111; cw_rd_plus = 10'b1010111000; disp_changes = 1'b0; end  // D byte=0x47
            9'b001001000: begin cw_rd_minus = 10'b1010100111; cw_rd_plus = 10'b1010011000; disp_changes = 1'b1; end  // D byte=0x48
            9'b001001001: begin cw_rd_minus = 10'b1010101001; cw_rd_plus = 10'b1010101001; disp_changes = 1'b0; end  // D byte=0x49
            9'b001001010: begin cw_rd_minus = 10'b1010101010; cw_rd_plus = 10'b1010101010; disp_changes = 1'b0; end  // D byte=0x4A
            9'b001001011: begin cw_rd_minus = 10'b1010001011; cw_rd_plus = 10'b1010001011; disp_changes = 1'b0; end  // D byte=0x4B
            9'b001001100: begin cw_rd_minus = 10'b1010101100; cw_rd_plus = 10'b1010101100; disp_changes = 1'b0; end  // D byte=0x4C
            9'b001001101: begin cw_rd_minus = 10'b1010001101; cw_rd_plus = 10'b1010001101; disp_changes = 1'b0; end  // D byte=0x4D
            9'b001001110: begin cw_rd_minus = 10'b1010001110; cw_rd_plus = 10'b1010001110; disp_changes = 1'b0; end  // D byte=0x4E
            9'b001001111: begin cw_rd_minus = 10'b1010111010; cw_rd_plus = 10'b1010000101; disp_changes = 1'b1; end  // D byte=0x4F
            9'b001010000: begin cw_rd_minus = 10'b1010110110; cw_rd_plus = 10'b1010001001; disp_changes = 1'b1; end  // D byte=0x50
            9'b001010001: begin cw_rd_minus = 10'b1010110001; cw_rd_plus = 10'b1010110001; disp_changes = 1'b0; end  // D byte=0x51
            9'b001010010: begin cw_rd_minus = 10'b1010110010; cw_rd_plus = 10'b1010110010; disp_changes = 1'b0; end  // D byte=0x52
            9'b001010011: begin cw_rd_minus = 10'b1010010011; cw_rd_plus = 10'b1010010011; disp_changes = 1'b0; end  // D byte=0x53
            9'b001010100: begin cw_rd_minus = 10'b1010110100; cw_rd_plus = 10'b1010110100; disp_changes = 1'b0; end  // D byte=0x54
            9'b001010101: begin cw_rd_minus = 10'b1010010101; cw_rd_plus = 10'b1010010101; disp_changes = 1'b0; end  // D byte=0x55
            9'b001010110: begin cw_rd_minus = 10'b1010010110; cw_rd_plus = 10'b1010010110; disp_changes = 1'b0; end  // D byte=0x56
            9'b001010111: begin cw_rd_minus = 10'b1010010111; cw_rd_plus = 10'b1010101000; disp_changes = 1'b1; end  // D byte=0x57
            9'b001011000: begin cw_rd_minus = 10'b1010110011; cw_rd_plus = 10'b1010001100; disp_changes = 1'b1; end  // D byte=0x58
            9'b001011001: begin cw_rd_minus = 10'b1010011001; cw_rd_plus = 10'b1010011001; disp_changes = 1'b0; end  // D byte=0x59
            9'b001011010: begin cw_rd_minus = 10'b1010011010; cw_rd_plus = 10'b1010011010; disp_changes = 1'b0; end  // D byte=0x5A
            9'b001011011: begin cw_rd_minus = 10'b1010011011; cw_rd_plus = 10'b1010100100; disp_changes = 1'b1; end  // D byte=0x5B
            9'b001011100: begin cw_rd_minus = 10'b1010011100; cw_rd_plus = 10'b1010011100; disp_changes = 1'b0; end  // D byte=0x5C
            9'b001011101: begin cw_rd_minus = 10'b1010011101; cw_rd_plus = 10'b1010100010; disp_changes = 1'b1; end  // D byte=0x5D
            9'b001011110: begin cw_rd_minus = 10'b1010011110; cw_rd_plus = 10'b1010100001; disp_changes = 1'b1; end  // D byte=0x5E
            9'b001011111: begin cw_rd_minus = 10'b1010110101; cw_rd_plus = 10'b1010001010; disp_changes = 1'b1; end  // D byte=0x5F
            9'b001100000: begin cw_rd_minus = 10'b1100111001; cw_rd_plus = 10'b0011000110; disp_changes = 1'b1; end  // D byte=0x60
            9'b001100001: begin cw_rd_minus = 10'b1100101110; cw_rd_plus = 10'b0011010001; disp_changes = 1'b1; end  // D byte=0x61
            9'b001100010: begin cw_rd_minus = 10'b1100101101; cw_rd_plus = 10'b0011010010; disp_changes = 1'b1; end  // D byte=0x62
            9'b001100011: begin cw_rd_minus = 10'b0011100011; cw_rd_plus = 10'b1100100011; disp_changes = 1'b0; end  // D byte=0x63
            9'b001100100: begin cw_rd_minus = 10'b1100101011; cw_rd_plus = 10'b0011010100; disp_changes = 1'b1; end  // D byte=0x64
            9'b001100101: begin cw_rd_minus = 10'b0011100101; cw_rd_plus = 10'b1100100101; disp_changes = 1'b0; end  // D byte=0x65
            9'b001100110: begin cw_rd_minus = 10'b0011100110; cw_rd_plus = 10'b1100100110; disp_changes = 1'b0; end  // D byte=0x66
            9'b001100111: begin cw_rd_minus = 10'b0011000111; cw_rd_plus = 10'b1100111000; disp_changes = 1'b0; end  // D byte=0x67
            9'b001101000: begin cw_rd_minus = 10'b1100100111; cw_rd_plus = 10'b0011011000; disp_changes = 1'b1; end  // D byte=0x68
            9'b001101001: begin cw_rd_minus = 10'b0011101001; cw_rd_plus = 10'b1100101001; disp_changes = 1'b0; end  // D byte=0x69
            9'b001101010: begin cw_rd_minus = 10'b0011101010; cw_rd_plus = 10'b1100101010; disp_changes = 1'b0; end  // D byte=0x6A
            9'b001101011: begin cw_rd_minus = 10'b0011001011; cw_rd_plus = 10'b1100001011; disp_changes = 1'b0; end  // D byte=0x6B
            9'b001101100: begin cw_rd_minus = 10'b0011101100; cw_rd_plus = 10'b1100101100; disp_changes = 1'b0; end  // D byte=0x6C
            9'b001101101: begin cw_rd_minus = 10'b0011001101; cw_rd_plus = 10'b1100001101; disp_changes = 1'b0; end  // D byte=0x6D
            9'b001101110: begin cw_rd_minus = 10'b0011001110; cw_rd_plus = 10'b1100001110; disp_changes = 1'b0; end  // D byte=0x6E
            9'b001101111: begin cw_rd_minus = 10'b1100111010; cw_rd_plus = 10'b0011000101; disp_changes = 1'b1; end  // D byte=0x6F
            9'b001110000: begin cw_rd_minus = 10'b1100110110; cw_rd_plus = 10'b0011001001; disp_changes = 1'b1; end  // D byte=0x70
            9'b001110001: begin cw_rd_minus = 10'b0011110001; cw_rd_plus = 10'b1100110001; disp_changes = 1'b0; end  // D byte=0x71
            9'b001110010: begin cw_rd_minus = 10'b0011110010; cw_rd_plus = 10'b1100110010; disp_changes = 1'b0; end  // D byte=0x72
            9'b001110011: begin cw_rd_minus = 10'b0011010011; cw_rd_plus = 10'b1100010011; disp_changes = 1'b0; end  // D byte=0x73
            9'b001110100: begin cw_rd_minus = 10'b0011110100; cw_rd_plus = 10'b1100110100; disp_changes = 1'b0; end  // D byte=0x74
            9'b001110101: begin cw_rd_minus = 10'b0011010101; cw_rd_plus = 10'b1100010101; disp_changes = 1'b0; end  // D byte=0x75
            9'b001110110: begin cw_rd_minus = 10'b0011010110; cw_rd_plus = 10'b1100010110; disp_changes = 1'b0; end  // D byte=0x76
            9'b001110111: begin cw_rd_minus = 10'b1100010111; cw_rd_plus = 10'b0011101000; disp_changes = 1'b1; end  // D byte=0x77
            9'b001111000: begin cw_rd_minus = 10'b1100110011; cw_rd_plus = 10'b0011001100; disp_changes = 1'b1; end  // D byte=0x78
            9'b001111001: begin cw_rd_minus = 10'b0011011001; cw_rd_plus = 10'b1100011001; disp_changes = 1'b0; end  // D byte=0x79
            9'b001111010: begin cw_rd_minus = 10'b0011011010; cw_rd_plus = 10'b1100011010; disp_changes = 1'b0; end  // D byte=0x7A
            9'b001111011: begin cw_rd_minus = 10'b1100011011; cw_rd_plus = 10'b0011100100; disp_changes = 1'b1; end  // D byte=0x7B
            9'b001111100: begin cw_rd_minus = 10'b0011011100; cw_rd_plus = 10'b1100011100; disp_changes = 1'b0; end  // D byte=0x7C
            9'b001111101: begin cw_rd_minus = 10'b1100011101; cw_rd_plus = 10'b0011100010; disp_changes = 1'b1; end  // D byte=0x7D
            9'b001111110: begin cw_rd_minus = 10'b1100011110; cw_rd_plus = 10'b0011100001; disp_changes = 1'b1; end  // D byte=0x7E
            9'b001111111: begin cw_rd_minus = 10'b1100110101; cw_rd_plus = 10'b0011001010; disp_changes = 1'b1; end  // D byte=0x7F
            9'b010000000: begin cw_rd_minus = 10'b0100111001; cw_rd_plus = 10'b1011000110; disp_changes = 1'b0; end  // D byte=0x80
            9'b010000001: begin cw_rd_minus = 10'b0100101110; cw_rd_plus = 10'b1011010001; disp_changes = 1'b0; end  // D byte=0x81
            9'b010000010: begin cw_rd_minus = 10'b0100101101; cw_rd_plus = 10'b1011010010; disp_changes = 1'b0; end  // D byte=0x82
            9'b010000011: begin cw_rd_minus = 10'b1011100011; cw_rd_plus = 10'b0100100011; disp_changes = 1'b1; end  // D byte=0x83
            9'b010000100: begin cw_rd_minus = 10'b0100101011; cw_rd_plus = 10'b1011010100; disp_changes = 1'b0; end  // D byte=0x84
            9'b010000101: begin cw_rd_minus = 10'b1011100101; cw_rd_plus = 10'b0100100101; disp_changes = 1'b1; end  // D byte=0x85
            9'b010000110: begin cw_rd_minus = 10'b1011100110; cw_rd_plus = 10'b0100100110; disp_changes = 1'b1; end  // D byte=0x86
            9'b010000111: begin cw_rd_minus = 10'b1011000111; cw_rd_plus = 10'b0100111000; disp_changes = 1'b1; end  // D byte=0x87
            9'b010001000: begin cw_rd_minus = 10'b0100100111; cw_rd_plus = 10'b1011011000; disp_changes = 1'b0; end  // D byte=0x88
            9'b010001001: begin cw_rd_minus = 10'b1011101001; cw_rd_plus = 10'b0100101001; disp_changes = 1'b1; end  // D byte=0x89
            9'b010001010: begin cw_rd_minus = 10'b1011101010; cw_rd_plus = 10'b0100101010; disp_changes = 1'b1; end  // D byte=0x8A
            9'b010001011: begin cw_rd_minus = 10'b1011001011; cw_rd_plus = 10'b0100001011; disp_changes = 1'b1; end  // D byte=0x8B
            9'b010001100: begin cw_rd_minus = 10'b1011101100; cw_rd_plus = 10'b0100101100; disp_changes = 1'b1; end  // D byte=0x8C
            9'b010001101: begin cw_rd_minus = 10'b1011001101; cw_rd_plus = 10'b0100001101; disp_changes = 1'b1; end  // D byte=0x8D
            9'b010001110: begin cw_rd_minus = 10'b1011001110; cw_rd_plus = 10'b0100001110; disp_changes = 1'b1; end  // D byte=0x8E
            9'b010001111: begin cw_rd_minus = 10'b0100111010; cw_rd_plus = 10'b1011000101; disp_changes = 1'b0; end  // D byte=0x8F
            9'b010010000: begin cw_rd_minus = 10'b0100110110; cw_rd_plus = 10'b1011001001; disp_changes = 1'b0; end  // D byte=0x90
            9'b010010001: begin cw_rd_minus = 10'b1011110001; cw_rd_plus = 10'b0100110001; disp_changes = 1'b1; end  // D byte=0x91
            9'b010010010: begin cw_rd_minus = 10'b1011110010; cw_rd_plus = 10'b0100110010; disp_changes = 1'b1; end  // D byte=0x92
            9'b010010011: begin cw_rd_minus = 10'b1011010011; cw_rd_plus = 10'b0100010011; disp_changes = 1'b1; end  // D byte=0x93
            9'b010010100: begin cw_rd_minus = 10'b1011110100; cw_rd_plus = 10'b0100110100; disp_changes = 1'b1; end  // D byte=0x94
            9'b010010101: begin cw_rd_minus = 10'b1011010101; cw_rd_plus = 10'b0100010101; disp_changes = 1'b1; end  // D byte=0x95
            9'b010010110: begin cw_rd_minus = 10'b1011010110; cw_rd_plus = 10'b0100010110; disp_changes = 1'b1; end  // D byte=0x96
            9'b010010111: begin cw_rd_minus = 10'b0100010111; cw_rd_plus = 10'b1011101000; disp_changes = 1'b0; end  // D byte=0x97
            9'b010011000: begin cw_rd_minus = 10'b0100110011; cw_rd_plus = 10'b1011001100; disp_changes = 1'b0; end  // D byte=0x98
            9'b010011001: begin cw_rd_minus = 10'b1011011001; cw_rd_plus = 10'b0100011001; disp_changes = 1'b1; end  // D byte=0x99
            9'b010011010: begin cw_rd_minus = 10'b1011011010; cw_rd_plus = 10'b0100011010; disp_changes = 1'b1; end  // D byte=0x9A
            9'b010011011: begin cw_rd_minus = 10'b0100011011; cw_rd_plus = 10'b1011100100; disp_changes = 1'b0; end  // D byte=0x9B
            9'b010011100: begin cw_rd_minus = 10'b1011011100; cw_rd_plus = 10'b0100011100; disp_changes = 1'b1; end  // D byte=0x9C
            9'b010011101: begin cw_rd_minus = 10'b0100011101; cw_rd_plus = 10'b1011100010; disp_changes = 1'b0; end  // D byte=0x9D
            9'b010011110: begin cw_rd_minus = 10'b0100011110; cw_rd_plus = 10'b1011100001; disp_changes = 1'b0; end  // D byte=0x9E
            9'b010011111: begin cw_rd_minus = 10'b0100110101; cw_rd_plus = 10'b1011001010; disp_changes = 1'b0; end  // D byte=0x9F
            9'b010100000: begin cw_rd_minus = 10'b0101111001; cw_rd_plus = 10'b0101000110; disp_changes = 1'b1; end  // D byte=0xA0
            9'b010100001: begin cw_rd_minus = 10'b0101101110; cw_rd_plus = 10'b0101010001; disp_changes = 1'b1; end  // D byte=0xA1
            9'b010100010: begin cw_rd_minus = 10'b0101101101; cw_rd_plus = 10'b0101010010; disp_changes = 1'b1; end  // D byte=0xA2
            9'b010100011: begin cw_rd_minus = 10'b0101100011; cw_rd_plus = 10'b0101100011; disp_changes = 1'b0; end  // D byte=0xA3
            9'b010100100: begin cw_rd_minus = 10'b0101101011; cw_rd_plus = 10'b0101010100; disp_changes = 1'b1; end  // D byte=0xA4
            9'b010100101: begin cw_rd_minus = 10'b0101100101; cw_rd_plus = 10'b0101100101; disp_changes = 1'b0; end  // D byte=0xA5
            9'b010100110: begin cw_rd_minus = 10'b0101100110; cw_rd_plus = 10'b0101100110; disp_changes = 1'b0; end  // D byte=0xA6
            9'b010100111: begin cw_rd_minus = 10'b0101000111; cw_rd_plus = 10'b0101111000; disp_changes = 1'b0; end  // D byte=0xA7
            9'b010101000: begin cw_rd_minus = 10'b0101100111; cw_rd_plus = 10'b0101011000; disp_changes = 1'b1; end  // D byte=0xA8
            9'b010101001: begin cw_rd_minus = 10'b0101101001; cw_rd_plus = 10'b0101101001; disp_changes = 1'b0; end  // D byte=0xA9
            9'b010101010: begin cw_rd_minus = 10'b0101101010; cw_rd_plus = 10'b0101101010; disp_changes = 1'b0; end  // D byte=0xAA
            9'b010101011: begin cw_rd_minus = 10'b0101001011; cw_rd_plus = 10'b0101001011; disp_changes = 1'b0; end  // D byte=0xAB
            9'b010101100: begin cw_rd_minus = 10'b0101101100; cw_rd_plus = 10'b0101101100; disp_changes = 1'b0; end  // D byte=0xAC
            9'b010101101: begin cw_rd_minus = 10'b0101001101; cw_rd_plus = 10'b0101001101; disp_changes = 1'b0; end  // D byte=0xAD
            9'b010101110: begin cw_rd_minus = 10'b0101001110; cw_rd_plus = 10'b0101001110; disp_changes = 1'b0; end  // D byte=0xAE
            9'b010101111: begin cw_rd_minus = 10'b0101111010; cw_rd_plus = 10'b0101000101; disp_changes = 1'b1; end  // D byte=0xAF
            9'b010110000: begin cw_rd_minus = 10'b0101110110; cw_rd_plus = 10'b0101001001; disp_changes = 1'b1; end  // D byte=0xB0
            9'b010110001: begin cw_rd_minus = 10'b0101110001; cw_rd_plus = 10'b0101110001; disp_changes = 1'b0; end  // D byte=0xB1
            9'b010110010: begin cw_rd_minus = 10'b0101110010; cw_rd_plus = 10'b0101110010; disp_changes = 1'b0; end  // D byte=0xB2
            9'b010110011: begin cw_rd_minus = 10'b0101010011; cw_rd_plus = 10'b0101010011; disp_changes = 1'b0; end  // D byte=0xB3
            9'b010110100: begin cw_rd_minus = 10'b0101110100; cw_rd_plus = 10'b0101110100; disp_changes = 1'b0; end  // D byte=0xB4
            9'b010110101: begin cw_rd_minus = 10'b0101010101; cw_rd_plus = 10'b0101010101; disp_changes = 1'b0; end  // D byte=0xB5
            9'b010110110: begin cw_rd_minus = 10'b0101010110; cw_rd_plus = 10'b0101010110; disp_changes = 1'b0; end  // D byte=0xB6
            9'b010110111: begin cw_rd_minus = 10'b0101010111; cw_rd_plus = 10'b0101101000; disp_changes = 1'b1; end  // D byte=0xB7
            9'b010111000: begin cw_rd_minus = 10'b0101110011; cw_rd_plus = 10'b0101001100; disp_changes = 1'b1; end  // D byte=0xB8
            9'b010111001: begin cw_rd_minus = 10'b0101011001; cw_rd_plus = 10'b0101011001; disp_changes = 1'b0; end  // D byte=0xB9
            9'b010111010: begin cw_rd_minus = 10'b0101011010; cw_rd_plus = 10'b0101011010; disp_changes = 1'b0; end  // D byte=0xBA
            9'b010111011: begin cw_rd_minus = 10'b0101011011; cw_rd_plus = 10'b0101100100; disp_changes = 1'b1; end  // D byte=0xBB
            9'b010111100: begin cw_rd_minus = 10'b0101011100; cw_rd_plus = 10'b0101011100; disp_changes = 1'b0; end  // D byte=0xBC
            9'b010111101: begin cw_rd_minus = 10'b0101011101; cw_rd_plus = 10'b0101100010; disp_changes = 1'b1; end  // D byte=0xBD
            9'b010111110: begin cw_rd_minus = 10'b0101011110; cw_rd_plus = 10'b0101100001; disp_changes = 1'b1; end  // D byte=0xBE
            9'b010111111: begin cw_rd_minus = 10'b0101110101; cw_rd_plus = 10'b0101001010; disp_changes = 1'b1; end  // D byte=0xBF
            9'b011000000: begin cw_rd_minus = 10'b0110111001; cw_rd_plus = 10'b0110000110; disp_changes = 1'b1; end  // D byte=0xC0
            9'b011000001: begin cw_rd_minus = 10'b0110101110; cw_rd_plus = 10'b0110010001; disp_changes = 1'b1; end  // D byte=0xC1
            9'b011000010: begin cw_rd_minus = 10'b0110101101; cw_rd_plus = 10'b0110010010; disp_changes = 1'b1; end  // D byte=0xC2
            9'b011000011: begin cw_rd_minus = 10'b0110100011; cw_rd_plus = 10'b0110100011; disp_changes = 1'b0; end  // D byte=0xC3
            9'b011000100: begin cw_rd_minus = 10'b0110101011; cw_rd_plus = 10'b0110010100; disp_changes = 1'b1; end  // D byte=0xC4
            9'b011000101: begin cw_rd_minus = 10'b0110100101; cw_rd_plus = 10'b0110100101; disp_changes = 1'b0; end  // D byte=0xC5
            9'b011000110: begin cw_rd_minus = 10'b0110100110; cw_rd_plus = 10'b0110100110; disp_changes = 1'b0; end  // D byte=0xC6
            9'b011000111: begin cw_rd_minus = 10'b0110000111; cw_rd_plus = 10'b0110111000; disp_changes = 1'b0; end  // D byte=0xC7
            9'b011001000: begin cw_rd_minus = 10'b0110100111; cw_rd_plus = 10'b0110011000; disp_changes = 1'b1; end  // D byte=0xC8
            9'b011001001: begin cw_rd_minus = 10'b0110101001; cw_rd_plus = 10'b0110101001; disp_changes = 1'b0; end  // D byte=0xC9
            9'b011001010: begin cw_rd_minus = 10'b0110101010; cw_rd_plus = 10'b0110101010; disp_changes = 1'b0; end  // D byte=0xCA
            9'b011001011: begin cw_rd_minus = 10'b0110001011; cw_rd_plus = 10'b0110001011; disp_changes = 1'b0; end  // D byte=0xCB
            9'b011001100: begin cw_rd_minus = 10'b0110101100; cw_rd_plus = 10'b0110101100; disp_changes = 1'b0; end  // D byte=0xCC
            9'b011001101: begin cw_rd_minus = 10'b0110001101; cw_rd_plus = 10'b0110001101; disp_changes = 1'b0; end  // D byte=0xCD
            9'b011001110: begin cw_rd_minus = 10'b0110001110; cw_rd_plus = 10'b0110001110; disp_changes = 1'b0; end  // D byte=0xCE
            9'b011001111: begin cw_rd_minus = 10'b0110111010; cw_rd_plus = 10'b0110000101; disp_changes = 1'b1; end  // D byte=0xCF
            9'b011010000: begin cw_rd_minus = 10'b0110110110; cw_rd_plus = 10'b0110001001; disp_changes = 1'b1; end  // D byte=0xD0
            9'b011010001: begin cw_rd_minus = 10'b0110110001; cw_rd_plus = 10'b0110110001; disp_changes = 1'b0; end  // D byte=0xD1
            9'b011010010: begin cw_rd_minus = 10'b0110110010; cw_rd_plus = 10'b0110110010; disp_changes = 1'b0; end  // D byte=0xD2
            9'b011010011: begin cw_rd_minus = 10'b0110010011; cw_rd_plus = 10'b0110010011; disp_changes = 1'b0; end  // D byte=0xD3
            9'b011010100: begin cw_rd_minus = 10'b0110110100; cw_rd_plus = 10'b0110110100; disp_changes = 1'b0; end  // D byte=0xD4
            9'b011010101: begin cw_rd_minus = 10'b0110010101; cw_rd_plus = 10'b0110010101; disp_changes = 1'b0; end  // D byte=0xD5
            9'b011010110: begin cw_rd_minus = 10'b0110010110; cw_rd_plus = 10'b0110010110; disp_changes = 1'b0; end  // D byte=0xD6
            9'b011010111: begin cw_rd_minus = 10'b0110010111; cw_rd_plus = 10'b0110101000; disp_changes = 1'b1; end  // D byte=0xD7
            9'b011011000: begin cw_rd_minus = 10'b0110110011; cw_rd_plus = 10'b0110001100; disp_changes = 1'b1; end  // D byte=0xD8
            9'b011011001: begin cw_rd_minus = 10'b0110011001; cw_rd_plus = 10'b0110011001; disp_changes = 1'b0; end  // D byte=0xD9
            9'b011011010: begin cw_rd_minus = 10'b0110011010; cw_rd_plus = 10'b0110011010; disp_changes = 1'b0; end  // D byte=0xDA
            9'b011011011: begin cw_rd_minus = 10'b0110011011; cw_rd_plus = 10'b0110100100; disp_changes = 1'b1; end  // D byte=0xDB
            9'b011011100: begin cw_rd_minus = 10'b0110011100; cw_rd_plus = 10'b0110011100; disp_changes = 1'b0; end  // D byte=0xDC
            9'b011011101: begin cw_rd_minus = 10'b0110011101; cw_rd_plus = 10'b0110100010; disp_changes = 1'b1; end  // D byte=0xDD
            9'b011011110: begin cw_rd_minus = 10'b0110011110; cw_rd_plus = 10'b0110100001; disp_changes = 1'b1; end  // D byte=0xDE
            9'b011011111: begin cw_rd_minus = 10'b0110110101; cw_rd_plus = 10'b0110001010; disp_changes = 1'b1; end  // D byte=0xDF
            9'b011100000: begin cw_rd_minus = 10'b1000111001; cw_rd_plus = 10'b0111000110; disp_changes = 1'b0; end  // D byte=0xE0
            9'b011100001: begin cw_rd_minus = 10'b1000101110; cw_rd_plus = 10'b0111010001; disp_changes = 1'b0; end  // D byte=0xE1
            9'b011100010: begin cw_rd_minus = 10'b1000101101; cw_rd_plus = 10'b0111010010; disp_changes = 1'b0; end  // D byte=0xE2
            9'b011100011: begin cw_rd_minus = 10'b0111100011; cw_rd_plus = 10'b1000100011; disp_changes = 1'b1; end  // D byte=0xE3
            9'b011100100: begin cw_rd_minus = 10'b1000101011; cw_rd_plus = 10'b0111010100; disp_changes = 1'b0; end  // D byte=0xE4
            9'b011100101: begin cw_rd_minus = 10'b0111100101; cw_rd_plus = 10'b1000100101; disp_changes = 1'b1; end  // D byte=0xE5
            9'b011100110: begin cw_rd_minus = 10'b0111100110; cw_rd_plus = 10'b1000100110; disp_changes = 1'b1; end  // D byte=0xE6
            9'b011100111: begin cw_rd_minus = 10'b0111000111; cw_rd_plus = 10'b1000111000; disp_changes = 1'b1; end  // D byte=0xE7
            9'b011101000: begin cw_rd_minus = 10'b1000100111; cw_rd_plus = 10'b0111011000; disp_changes = 1'b0; end  // D byte=0xE8
            9'b011101001: begin cw_rd_minus = 10'b0111101001; cw_rd_plus = 10'b1000101001; disp_changes = 1'b1; end  // D byte=0xE9
            9'b011101010: begin cw_rd_minus = 10'b0111101010; cw_rd_plus = 10'b1000101010; disp_changes = 1'b1; end  // D byte=0xEA
            9'b011101011: begin cw_rd_minus = 10'b0111001011; cw_rd_plus = 10'b0001001011; disp_changes = 1'b1; end  // D byte=0xEB
            9'b011101100: begin cw_rd_minus = 10'b0111101100; cw_rd_plus = 10'b1000101100; disp_changes = 1'b1; end  // D byte=0xEC
            9'b011101101: begin cw_rd_minus = 10'b0111001101; cw_rd_plus = 10'b0001001101; disp_changes = 1'b1; end  // D byte=0xED
            9'b011101110: begin cw_rd_minus = 10'b0111001110; cw_rd_plus = 10'b0001001110; disp_changes = 1'b1; end  // D byte=0xEE
            9'b011101111: begin cw_rd_minus = 10'b1000111010; cw_rd_plus = 10'b0111000101; disp_changes = 1'b0; end  // D byte=0xEF
            9'b011110000: begin cw_rd_minus = 10'b1000110110; cw_rd_plus = 10'b0111001001; disp_changes = 1'b0; end  // D byte=0xF0
            9'b011110001: begin cw_rd_minus = 10'b1110110001; cw_rd_plus = 10'b1000110001; disp_changes = 1'b1; end  // D byte=0xF1
            9'b011110010: begin cw_rd_minus = 10'b1110110010; cw_rd_plus = 10'b1000110010; disp_changes = 1'b1; end  // D byte=0xF2
            9'b011110011: begin cw_rd_minus = 10'b0111010011; cw_rd_plus = 10'b1000010011; disp_changes = 1'b1; end  // D byte=0xF3
            9'b011110100: begin cw_rd_minus = 10'b1110110100; cw_rd_plus = 10'b1000110100; disp_changes = 1'b1; end  // D byte=0xF4
            9'b011110101: begin cw_rd_minus = 10'b0111010101; cw_rd_plus = 10'b1000010101; disp_changes = 1'b1; end  // D byte=0xF5
            9'b011110110: begin cw_rd_minus = 10'b0111010110; cw_rd_plus = 10'b1000010110; disp_changes = 1'b1; end  // D byte=0xF6
            9'b011110111: begin cw_rd_minus = 10'b1000010111; cw_rd_plus = 10'b0111101000; disp_changes = 1'b0; end  // D byte=0xF7
            9'b011111000: begin cw_rd_minus = 10'b1000110011; cw_rd_plus = 10'b0111001100; disp_changes = 1'b0; end  // D byte=0xF8
            9'b011111001: begin cw_rd_minus = 10'b0111011001; cw_rd_plus = 10'b1000011001; disp_changes = 1'b1; end  // D byte=0xF9
            9'b011111010: begin cw_rd_minus = 10'b0111011010; cw_rd_plus = 10'b1000011010; disp_changes = 1'b1; end  // D byte=0xFA
            9'b011111011: begin cw_rd_minus = 10'b1000011011; cw_rd_plus = 10'b0111100100; disp_changes = 1'b0; end  // D byte=0xFB
            9'b011111100: begin cw_rd_minus = 10'b0111011100; cw_rd_plus = 10'b1000011100; disp_changes = 1'b1; end  // D byte=0xFC
            9'b011111101: begin cw_rd_minus = 10'b1000011101; cw_rd_plus = 10'b0111100010; disp_changes = 1'b0; end  // D byte=0xFD
            9'b011111110: begin cw_rd_minus = 10'b1000011110; cw_rd_plus = 10'b0111100001; disp_changes = 1'b0; end  // D byte=0xFE
            9'b011111111: begin cw_rd_minus = 10'b1000110101; cw_rd_plus = 10'b0111001010; disp_changes = 1'b0; end  // D byte=0xFF
            9'b100011100: begin cw_rd_minus = 10'b0010111100; cw_rd_plus = 10'b1101000011; disp_changes = 1'b0; end  // K byte=0x1C
            9'b100111100: begin cw_rd_minus = 10'b1001111100; cw_rd_plus = 10'b0110000011; disp_changes = 1'b1; end  // K byte=0x3C
            9'b101011100: begin cw_rd_minus = 10'b1010111100; cw_rd_plus = 10'b0101000011; disp_changes = 1'b1; end  // K byte=0x5C
            9'b101111100: begin cw_rd_minus = 10'b1100111100; cw_rd_plus = 10'b0011000011; disp_changes = 1'b1; end  // K byte=0x7C
            9'b110011100: begin cw_rd_minus = 10'b0100111100; cw_rd_plus = 10'b1011000011; disp_changes = 1'b0; end  // K byte=0x9C
            9'b110111100: begin cw_rd_minus = 10'b0101111100; cw_rd_plus = 10'b1010000011; disp_changes = 1'b1; end  // K byte=0xBC
            9'b111011100: begin cw_rd_minus = 10'b0110111100; cw_rd_plus = 10'b1001000011; disp_changes = 1'b1; end  // K byte=0xDC
            9'b111111100: begin cw_rd_minus = 10'b0001111100; cw_rd_plus = 10'b1110000011; disp_changes = 1'b0; end  // K byte=0xFC
            9'b111110111: begin cw_rd_minus = 10'b0001010111; cw_rd_plus = 10'b1110101000; disp_changes = 1'b0; end  // K byte=0xF7
            9'b111111011: begin cw_rd_minus = 10'b0001011011; cw_rd_plus = 10'b1110100100; disp_changes = 1'b0; end  // K byte=0xFB
            9'b111111101: begin cw_rd_minus = 10'b0001011101; cw_rd_plus = 10'b1110100010; disp_changes = 1'b0; end  // K byte=0xFD
            9'b111111110: begin cw_rd_minus = 10'b0001011110; cw_rd_plus = 10'b1110100001; disp_changes = 1'b0; end  // K byte=0xFE
            default: begin cw_rd_minus = 10'b0000000000; cw_rd_plus = 10'b0000000000; disp_changes = 1'b0; end
        endcase
    end

    wire [9:0] selected_codeword = disparity ? cw_rd_plus : cw_rd_minus;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout      <= 10'b0000000000;
            disparity <= 1'b0;
        end else begin
            dout      <= selected_codeword;
            disparity <= disparity ^ disp_changes;
        end
    end

endmodule
