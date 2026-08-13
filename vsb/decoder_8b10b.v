// ============================================================================
// Module Name:  decoder_8b10b
// Description:  8b/10b decoder implemented as an explicit lookup table,
//               generated mechanically from the same verified reference
//               table as encoder_8b10b.v. Replaces the earlier hand-derived
//               boolean-equation implementation (see V-13/V-14). Tracks
//               running disparity and flags code_err both for codewords
//               outside the valid 8b/10b set and for valid codewords whose
//               disparity variant doesn't match the currently tracked
//               running disparity (a real link error, not just an
//               unrecognized bit pattern).
// Standards:    Verilog-2001 Standard Baseline
// ============================================================================

`timescale 1ns / 1ps

module decoder_8b10b (
    input  wire        clk,       // 81 MHz Recovered Clock (serdes_rbc0)
    input  wire        rst_n,     // Active-low synchronized reset
    input  wire [9:0]  din,       // Comma-aligned 10-bit input word
    output reg  [7:0]  dout,      // Decoded 8-bit output byte
    output reg         kout,      // Control character flag (1 = K-code, 0 = Data)
    output reg         code_err   // High for illegal 8b/10b symbol sequences or disparity violations
);

    reg disparity;   // Running disparity: 0 = RD-, 1 = RD+

    reg [7:0] lut_byte;
    reg       lut_kin;
    reg       lut_valid;
    reg       lut_changes;          // does this codeword's byte toggle RD when legally used
    reg       lut_is_rdp_variant;   // is `din` this byte's RD+ representation (vs RD-)

    always @(*) begin
        case (din)
            10'b0001001011: begin lut_byte = 8'hEB; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xEB RD+
            10'b0001001101: begin lut_byte = 8'hED; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xED RD+
            10'b0001001110: begin lut_byte = 8'hEE; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xEE RD+
            10'b0001010111: begin lut_byte = 8'hF7; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // K byte=0xF7 RD-(neutral)
            10'b0001011011: begin lut_byte = 8'hFB; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // K byte=0xFB RD-(neutral)
            10'b0001011101: begin lut_byte = 8'hFD; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // K byte=0xFD RD-(neutral)
            10'b0001011110: begin lut_byte = 8'hFE; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // K byte=0xFE RD-(neutral)
            10'b0001111100: begin lut_byte = 8'hFC; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // K byte=0xFC RD-(neutral)
            10'b0010001011: begin lut_byte = 8'h0B; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x0B RD+
            10'b0010001101: begin lut_byte = 8'h0D; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x0D RD+
            10'b0010001110: begin lut_byte = 8'h0E; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x0E RD+
            10'b0010010011: begin lut_byte = 8'h13; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x13 RD+
            10'b0010010101: begin lut_byte = 8'h15; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x15 RD+
            10'b0010010110: begin lut_byte = 8'h16; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x16 RD+
            10'b0010010111: begin lut_byte = 8'h17; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x17 RD-(neutral)
            10'b0010011001: begin lut_byte = 8'h19; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x19 RD+
            10'b0010011010: begin lut_byte = 8'h1A; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x1A RD+
            10'b0010011011: begin lut_byte = 8'h1B; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x1B RD-(neutral)
            10'b0010011100: begin lut_byte = 8'h1C; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x1C RD+
            10'b0010011101: begin lut_byte = 8'h1D; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x1D RD-(neutral)
            10'b0010011110: begin lut_byte = 8'h1E; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x1E RD-(neutral)
            10'b0010100011: begin lut_byte = 8'h03; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x03 RD+
            10'b0010100101: begin lut_byte = 8'h05; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x05 RD+
            10'b0010100110: begin lut_byte = 8'h06; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x06 RD+
            10'b0010100111: begin lut_byte = 8'h08; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x08 RD-(neutral)
            10'b0010101001: begin lut_byte = 8'h09; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x09 RD+
            10'b0010101010: begin lut_byte = 8'h0A; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x0A RD+
            10'b0010101011: begin lut_byte = 8'h04; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x04 RD-(neutral)
            10'b0010101100: begin lut_byte = 8'h0C; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x0C RD+
            10'b0010101101: begin lut_byte = 8'h02; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x02 RD-(neutral)
            10'b0010101110: begin lut_byte = 8'h01; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x01 RD-(neutral)
            10'b0010110001: begin lut_byte = 8'h11; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x11 RD+
            10'b0010110010: begin lut_byte = 8'h12; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x12 RD+
            10'b0010110011: begin lut_byte = 8'h18; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x18 RD-(neutral)
            10'b0010110100: begin lut_byte = 8'h14; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x14 RD+
            10'b0010110101: begin lut_byte = 8'h1F; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x1F RD-(neutral)
            10'b0010110110: begin lut_byte = 8'h10; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x10 RD-(neutral)
            10'b0010111000: begin lut_byte = 8'h07; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x07 RD+
            10'b0010111001: begin lut_byte = 8'h00; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x00 RD-(neutral)
            10'b0010111010: begin lut_byte = 8'h0F; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x0F RD-(neutral)
            10'b0010111100: begin lut_byte = 8'h1C; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // K byte=0x1C RD-(neutral)
            10'b0011000011: begin lut_byte = 8'h7C; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // K byte=0x7C RD+
            10'b0011000101: begin lut_byte = 8'h6F; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x6F RD+
            10'b0011000110: begin lut_byte = 8'h60; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x60 RD+
            10'b0011000111: begin lut_byte = 8'h67; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x67 RD-(neutral)
            10'b0011001001: begin lut_byte = 8'h70; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x70 RD+
            10'b0011001010: begin lut_byte = 8'h7F; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x7F RD+
            10'b0011001011: begin lut_byte = 8'h6B; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x6B RD-(neutral)
            10'b0011001100: begin lut_byte = 8'h78; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x78 RD+
            10'b0011001101: begin lut_byte = 8'h6D; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x6D RD-(neutral)
            10'b0011001110: begin lut_byte = 8'h6E; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x6E RD-(neutral)
            10'b0011010001: begin lut_byte = 8'h61; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x61 RD+
            10'b0011010010: begin lut_byte = 8'h62; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x62 RD+
            10'b0011010011: begin lut_byte = 8'h73; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x73 RD-(neutral)
            10'b0011010100: begin lut_byte = 8'h64; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x64 RD+
            10'b0011010101: begin lut_byte = 8'h75; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x75 RD-(neutral)
            10'b0011010110: begin lut_byte = 8'h76; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x76 RD-(neutral)
            10'b0011011000: begin lut_byte = 8'h68; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x68 RD+
            10'b0011011001: begin lut_byte = 8'h79; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x79 RD-(neutral)
            10'b0011011010: begin lut_byte = 8'h7A; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x7A RD-(neutral)
            10'b0011011100: begin lut_byte = 8'h7C; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x7C RD-(neutral)
            10'b0011100001: begin lut_byte = 8'h7E; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x7E RD+
            10'b0011100010: begin lut_byte = 8'h7D; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x7D RD+
            10'b0011100011: begin lut_byte = 8'h63; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x63 RD-(neutral)
            10'b0011100100: begin lut_byte = 8'h7B; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x7B RD+
            10'b0011100101: begin lut_byte = 8'h65; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x65 RD-(neutral)
            10'b0011100110: begin lut_byte = 8'h66; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x66 RD-(neutral)
            10'b0011101000: begin lut_byte = 8'h77; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x77 RD+
            10'b0011101001: begin lut_byte = 8'h69; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x69 RD-(neutral)
            10'b0011101010: begin lut_byte = 8'h6A; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x6A RD-(neutral)
            10'b0011101100: begin lut_byte = 8'h6C; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x6C RD-(neutral)
            10'b0011110001: begin lut_byte = 8'h71; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x71 RD-(neutral)
            10'b0011110010: begin lut_byte = 8'h72; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x72 RD-(neutral)
            10'b0011110100: begin lut_byte = 8'h74; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x74 RD-(neutral)
            10'b0100001011: begin lut_byte = 8'h8B; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x8B RD+
            10'b0100001101: begin lut_byte = 8'h8D; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x8D RD+
            10'b0100001110: begin lut_byte = 8'h8E; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x8E RD+
            10'b0100010011: begin lut_byte = 8'h93; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x93 RD+
            10'b0100010101: begin lut_byte = 8'h95; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x95 RD+
            10'b0100010110: begin lut_byte = 8'h96; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x96 RD+
            10'b0100010111: begin lut_byte = 8'h97; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x97 RD-(neutral)
            10'b0100011001: begin lut_byte = 8'h99; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x99 RD+
            10'b0100011010: begin lut_byte = 8'h9A; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x9A RD+
            10'b0100011011: begin lut_byte = 8'h9B; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x9B RD-(neutral)
            10'b0100011100: begin lut_byte = 8'h9C; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x9C RD+
            10'b0100011101: begin lut_byte = 8'h9D; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x9D RD-(neutral)
            10'b0100011110: begin lut_byte = 8'h9E; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x9E RD-(neutral)
            10'b0100100011: begin lut_byte = 8'h83; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x83 RD+
            10'b0100100101: begin lut_byte = 8'h85; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x85 RD+
            10'b0100100110: begin lut_byte = 8'h86; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x86 RD+
            10'b0100100111: begin lut_byte = 8'h88; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x88 RD-(neutral)
            10'b0100101001: begin lut_byte = 8'h89; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x89 RD+
            10'b0100101010: begin lut_byte = 8'h8A; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x8A RD+
            10'b0100101011: begin lut_byte = 8'h84; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x84 RD-(neutral)
            10'b0100101100: begin lut_byte = 8'h8C; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x8C RD+
            10'b0100101101: begin lut_byte = 8'h82; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x82 RD-(neutral)
            10'b0100101110: begin lut_byte = 8'h81; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x81 RD-(neutral)
            10'b0100110001: begin lut_byte = 8'h91; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x91 RD+
            10'b0100110010: begin lut_byte = 8'h92; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x92 RD+
            10'b0100110011: begin lut_byte = 8'h98; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x98 RD-(neutral)
            10'b0100110100: begin lut_byte = 8'h94; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x94 RD+
            10'b0100110101: begin lut_byte = 8'h9F; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x9F RD-(neutral)
            10'b0100110110: begin lut_byte = 8'h90; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x90 RD-(neutral)
            10'b0100111000: begin lut_byte = 8'h87; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x87 RD+
            10'b0100111001: begin lut_byte = 8'h80; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x80 RD-(neutral)
            10'b0100111010: begin lut_byte = 8'h8F; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x8F RD-(neutral)
            10'b0100111100: begin lut_byte = 8'h9C; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // K byte=0x9C RD-(neutral)
            10'b0101000011: begin lut_byte = 8'h5C; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // K byte=0x5C RD+
            10'b0101000101: begin lut_byte = 8'hAF; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xAF RD+
            10'b0101000110: begin lut_byte = 8'hA0; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xA0 RD+
            10'b0101000111: begin lut_byte = 8'hA7; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0xA7 RD-(neutral)
            10'b0101001001: begin lut_byte = 8'hB0; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xB0 RD+
            10'b0101001010: begin lut_byte = 8'hBF; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xBF RD+
            10'b0101001011: begin lut_byte = 8'hAB; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xAB RD+(neutral)
            10'b0101001100: begin lut_byte = 8'hB8; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xB8 RD+
            10'b0101001101: begin lut_byte = 8'hAD; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xAD RD+(neutral)
            10'b0101001110: begin lut_byte = 8'hAE; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xAE RD+(neutral)
            10'b0101010001: begin lut_byte = 8'hA1; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xA1 RD+
            10'b0101010010: begin lut_byte = 8'hA2; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xA2 RD+
            10'b0101010011: begin lut_byte = 8'hB3; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xB3 RD+(neutral)
            10'b0101010100: begin lut_byte = 8'hA4; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xA4 RD+
            10'b0101010101: begin lut_byte = 8'hB5; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xB5 RD+(neutral)
            10'b0101010110: begin lut_byte = 8'hB6; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xB6 RD+(neutral)
            10'b0101010111: begin lut_byte = 8'hB7; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xB7 RD-
            10'b0101011000: begin lut_byte = 8'hA8; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xA8 RD+
            10'b0101011001: begin lut_byte = 8'hB9; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xB9 RD+(neutral)
            10'b0101011010: begin lut_byte = 8'hBA; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xBA RD+(neutral)
            10'b0101011011: begin lut_byte = 8'hBB; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xBB RD-
            10'b0101011100: begin lut_byte = 8'hBC; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xBC RD+(neutral)
            10'b0101011101: begin lut_byte = 8'hBD; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xBD RD-
            10'b0101011110: begin lut_byte = 8'hBE; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xBE RD-
            10'b0101100001: begin lut_byte = 8'hBE; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xBE RD+
            10'b0101100010: begin lut_byte = 8'hBD; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xBD RD+
            10'b0101100011: begin lut_byte = 8'hA3; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xA3 RD+(neutral)
            10'b0101100100: begin lut_byte = 8'hBB; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xBB RD+
            10'b0101100101: begin lut_byte = 8'hA5; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xA5 RD+(neutral)
            10'b0101100110: begin lut_byte = 8'hA6; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xA6 RD+(neutral)
            10'b0101100111: begin lut_byte = 8'hA8; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xA8 RD-
            10'b0101101000: begin lut_byte = 8'hB7; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xB7 RD+
            10'b0101101001: begin lut_byte = 8'hA9; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xA9 RD+(neutral)
            10'b0101101010: begin lut_byte = 8'hAA; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xAA RD+(neutral)
            10'b0101101011: begin lut_byte = 8'hA4; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xA4 RD-
            10'b0101101100: begin lut_byte = 8'hAC; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xAC RD+(neutral)
            10'b0101101101: begin lut_byte = 8'hA2; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xA2 RD-
            10'b0101101110: begin lut_byte = 8'hA1; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xA1 RD-
            10'b0101110001: begin lut_byte = 8'hB1; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xB1 RD+(neutral)
            10'b0101110010: begin lut_byte = 8'hB2; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xB2 RD+(neutral)
            10'b0101110011: begin lut_byte = 8'hB8; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xB8 RD-
            10'b0101110100: begin lut_byte = 8'hB4; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xB4 RD+(neutral)
            10'b0101110101: begin lut_byte = 8'hBF; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xBF RD-
            10'b0101110110: begin lut_byte = 8'hB0; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xB0 RD-
            10'b0101111000: begin lut_byte = 8'hA7; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xA7 RD+(neutral)
            10'b0101111001: begin lut_byte = 8'hA0; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xA0 RD-
            10'b0101111010: begin lut_byte = 8'hAF; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xAF RD-
            10'b0101111100: begin lut_byte = 8'hBC; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // K byte=0xBC RD-
            10'b0110000011: begin lut_byte = 8'h3C; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // K byte=0x3C RD+
            10'b0110000101: begin lut_byte = 8'hCF; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xCF RD+
            10'b0110000110: begin lut_byte = 8'hC0; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xC0 RD+
            10'b0110000111: begin lut_byte = 8'hC7; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0xC7 RD-(neutral)
            10'b0110001001: begin lut_byte = 8'hD0; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xD0 RD+
            10'b0110001010: begin lut_byte = 8'hDF; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xDF RD+
            10'b0110001011: begin lut_byte = 8'hCB; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xCB RD+(neutral)
            10'b0110001100: begin lut_byte = 8'hD8; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xD8 RD+
            10'b0110001101: begin lut_byte = 8'hCD; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xCD RD+(neutral)
            10'b0110001110: begin lut_byte = 8'hCE; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xCE RD+(neutral)
            10'b0110010001: begin lut_byte = 8'hC1; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xC1 RD+
            10'b0110010010: begin lut_byte = 8'hC2; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xC2 RD+
            10'b0110010011: begin lut_byte = 8'hD3; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xD3 RD+(neutral)
            10'b0110010100: begin lut_byte = 8'hC4; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xC4 RD+
            10'b0110010101: begin lut_byte = 8'hD5; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xD5 RD+(neutral)
            10'b0110010110: begin lut_byte = 8'hD6; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xD6 RD+(neutral)
            10'b0110010111: begin lut_byte = 8'hD7; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xD7 RD-
            10'b0110011000: begin lut_byte = 8'hC8; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xC8 RD+
            10'b0110011001: begin lut_byte = 8'hD9; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xD9 RD+(neutral)
            10'b0110011010: begin lut_byte = 8'hDA; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xDA RD+(neutral)
            10'b0110011011: begin lut_byte = 8'hDB; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xDB RD-
            10'b0110011100: begin lut_byte = 8'hDC; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xDC RD+(neutral)
            10'b0110011101: begin lut_byte = 8'hDD; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xDD RD-
            10'b0110011110: begin lut_byte = 8'hDE; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xDE RD-
            10'b0110100001: begin lut_byte = 8'hDE; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xDE RD+
            10'b0110100010: begin lut_byte = 8'hDD; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xDD RD+
            10'b0110100011: begin lut_byte = 8'hC3; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xC3 RD+(neutral)
            10'b0110100100: begin lut_byte = 8'hDB; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xDB RD+
            10'b0110100101: begin lut_byte = 8'hC5; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xC5 RD+(neutral)
            10'b0110100110: begin lut_byte = 8'hC6; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xC6 RD+(neutral)
            10'b0110100111: begin lut_byte = 8'hC8; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xC8 RD-
            10'b0110101000: begin lut_byte = 8'hD7; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xD7 RD+
            10'b0110101001: begin lut_byte = 8'hC9; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xC9 RD+(neutral)
            10'b0110101010: begin lut_byte = 8'hCA; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xCA RD+(neutral)
            10'b0110101011: begin lut_byte = 8'hC4; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xC4 RD-
            10'b0110101100: begin lut_byte = 8'hCC; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xCC RD+(neutral)
            10'b0110101101: begin lut_byte = 8'hC2; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xC2 RD-
            10'b0110101110: begin lut_byte = 8'hC1; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xC1 RD-
            10'b0110110001: begin lut_byte = 8'hD1; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xD1 RD+(neutral)
            10'b0110110010: begin lut_byte = 8'hD2; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xD2 RD+(neutral)
            10'b0110110011: begin lut_byte = 8'hD8; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xD8 RD-
            10'b0110110100: begin lut_byte = 8'hD4; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xD4 RD+(neutral)
            10'b0110110101: begin lut_byte = 8'hDF; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xDF RD-
            10'b0110110110: begin lut_byte = 8'hD0; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xD0 RD-
            10'b0110111000: begin lut_byte = 8'hC7; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xC7 RD+(neutral)
            10'b0110111001: begin lut_byte = 8'hC0; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xC0 RD-
            10'b0110111010: begin lut_byte = 8'hCF; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xCF RD-
            10'b0110111100: begin lut_byte = 8'hDC; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // K byte=0xDC RD-
            10'b0111000101: begin lut_byte = 8'hEF; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xEF RD+(neutral)
            10'b0111000110: begin lut_byte = 8'hE0; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xE0 RD+(neutral)
            10'b0111000111: begin lut_byte = 8'hE7; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xE7 RD-
            10'b0111001001: begin lut_byte = 8'hF0; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xF0 RD+(neutral)
            10'b0111001010: begin lut_byte = 8'hFF; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xFF RD+(neutral)
            10'b0111001011: begin lut_byte = 8'hEB; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xEB RD-
            10'b0111001100: begin lut_byte = 8'hF8; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xF8 RD+(neutral)
            10'b0111001101: begin lut_byte = 8'hED; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xED RD-
            10'b0111001110: begin lut_byte = 8'hEE; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xEE RD-
            10'b0111010001: begin lut_byte = 8'hE1; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xE1 RD+(neutral)
            10'b0111010010: begin lut_byte = 8'hE2; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xE2 RD+(neutral)
            10'b0111010011: begin lut_byte = 8'hF3; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xF3 RD-
            10'b0111010100: begin lut_byte = 8'hE4; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xE4 RD+(neutral)
            10'b0111010101: begin lut_byte = 8'hF5; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xF5 RD-
            10'b0111010110: begin lut_byte = 8'hF6; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xF6 RD-
            10'b0111011000: begin lut_byte = 8'hE8; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xE8 RD+(neutral)
            10'b0111011001: begin lut_byte = 8'hF9; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xF9 RD-
            10'b0111011010: begin lut_byte = 8'hFA; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xFA RD-
            10'b0111011100: begin lut_byte = 8'hFC; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xFC RD-
            10'b0111100001: begin lut_byte = 8'hFE; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xFE RD+(neutral)
            10'b0111100010: begin lut_byte = 8'hFD; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xFD RD+(neutral)
            10'b0111100011: begin lut_byte = 8'hE3; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xE3 RD-
            10'b0111100100: begin lut_byte = 8'hFB; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xFB RD+(neutral)
            10'b0111100101: begin lut_byte = 8'hE5; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xE5 RD-
            10'b0111100110: begin lut_byte = 8'hE6; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xE6 RD-
            10'b0111101000: begin lut_byte = 8'hF7; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0xF7 RD+(neutral)
            10'b0111101001: begin lut_byte = 8'hE9; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xE9 RD-
            10'b0111101010: begin lut_byte = 8'hEA; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xEA RD-
            10'b0111101100: begin lut_byte = 8'hEC; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xEC RD-
            10'b1000010011: begin lut_byte = 8'hF3; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xF3 RD+
            10'b1000010101: begin lut_byte = 8'hF5; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xF5 RD+
            10'b1000010110: begin lut_byte = 8'hF6; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xF6 RD+
            10'b1000010111: begin lut_byte = 8'hF7; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0xF7 RD-(neutral)
            10'b1000011001: begin lut_byte = 8'hF9; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xF9 RD+
            10'b1000011010: begin lut_byte = 8'hFA; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xFA RD+
            10'b1000011011: begin lut_byte = 8'hFB; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0xFB RD-(neutral)
            10'b1000011100: begin lut_byte = 8'hFC; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xFC RD+
            10'b1000011101: begin lut_byte = 8'hFD; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0xFD RD-(neutral)
            10'b1000011110: begin lut_byte = 8'hFE; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0xFE RD-(neutral)
            10'b1000100011: begin lut_byte = 8'hE3; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xE3 RD+
            10'b1000100101: begin lut_byte = 8'hE5; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xE5 RD+
            10'b1000100110: begin lut_byte = 8'hE6; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xE6 RD+
            10'b1000100111: begin lut_byte = 8'hE8; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0xE8 RD-(neutral)
            10'b1000101001: begin lut_byte = 8'hE9; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xE9 RD+
            10'b1000101010: begin lut_byte = 8'hEA; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xEA RD+
            10'b1000101011: begin lut_byte = 8'hE4; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0xE4 RD-(neutral)
            10'b1000101100: begin lut_byte = 8'hEC; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xEC RD+
            10'b1000101101: begin lut_byte = 8'hE2; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0xE2 RD-(neutral)
            10'b1000101110: begin lut_byte = 8'hE1; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0xE1 RD-(neutral)
            10'b1000110001: begin lut_byte = 8'hF1; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xF1 RD+
            10'b1000110010: begin lut_byte = 8'hF2; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xF2 RD+
            10'b1000110011: begin lut_byte = 8'hF8; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0xF8 RD-(neutral)
            10'b1000110100: begin lut_byte = 8'hF4; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xF4 RD+
            10'b1000110101: begin lut_byte = 8'hFF; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0xFF RD-(neutral)
            10'b1000110110: begin lut_byte = 8'hF0; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0xF0 RD-(neutral)
            10'b1000111000: begin lut_byte = 8'hE7; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0xE7 RD+
            10'b1000111001: begin lut_byte = 8'hE0; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0xE0 RD-(neutral)
            10'b1000111010: begin lut_byte = 8'hEF; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0xEF RD-(neutral)
            10'b1001000011: begin lut_byte = 8'hDC; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // K byte=0xDC RD+
            10'b1001000101: begin lut_byte = 8'h2F; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x2F RD+
            10'b1001000110: begin lut_byte = 8'h20; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x20 RD+
            10'b1001000111: begin lut_byte = 8'h27; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x27 RD-(neutral)
            10'b1001001001: begin lut_byte = 8'h30; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x30 RD+
            10'b1001001010: begin lut_byte = 8'h3F; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x3F RD+
            10'b1001001011: begin lut_byte = 8'h2B; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x2B RD+(neutral)
            10'b1001001100: begin lut_byte = 8'h38; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x38 RD+
            10'b1001001101: begin lut_byte = 8'h2D; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x2D RD+(neutral)
            10'b1001001110: begin lut_byte = 8'h2E; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x2E RD+(neutral)
            10'b1001010001: begin lut_byte = 8'h21; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x21 RD+
            10'b1001010010: begin lut_byte = 8'h22; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x22 RD+
            10'b1001010011: begin lut_byte = 8'h33; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x33 RD+(neutral)
            10'b1001010100: begin lut_byte = 8'h24; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x24 RD+
            10'b1001010101: begin lut_byte = 8'h35; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x35 RD+(neutral)
            10'b1001010110: begin lut_byte = 8'h36; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x36 RD+(neutral)
            10'b1001010111: begin lut_byte = 8'h37; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x37 RD-
            10'b1001011000: begin lut_byte = 8'h28; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x28 RD+
            10'b1001011001: begin lut_byte = 8'h39; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x39 RD+(neutral)
            10'b1001011010: begin lut_byte = 8'h3A; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x3A RD+(neutral)
            10'b1001011011: begin lut_byte = 8'h3B; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x3B RD-
            10'b1001011100: begin lut_byte = 8'h3C; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x3C RD+(neutral)
            10'b1001011101: begin lut_byte = 8'h3D; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x3D RD-
            10'b1001011110: begin lut_byte = 8'h3E; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x3E RD-
            10'b1001100001: begin lut_byte = 8'h3E; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x3E RD+
            10'b1001100010: begin lut_byte = 8'h3D; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x3D RD+
            10'b1001100011: begin lut_byte = 8'h23; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x23 RD+(neutral)
            10'b1001100100: begin lut_byte = 8'h3B; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x3B RD+
            10'b1001100101: begin lut_byte = 8'h25; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x25 RD+(neutral)
            10'b1001100110: begin lut_byte = 8'h26; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x26 RD+(neutral)
            10'b1001100111: begin lut_byte = 8'h28; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x28 RD-
            10'b1001101000: begin lut_byte = 8'h37; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x37 RD+
            10'b1001101001: begin lut_byte = 8'h29; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x29 RD+(neutral)
            10'b1001101010: begin lut_byte = 8'h2A; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x2A RD+(neutral)
            10'b1001101011: begin lut_byte = 8'h24; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x24 RD-
            10'b1001101100: begin lut_byte = 8'h2C; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x2C RD+(neutral)
            10'b1001101101: begin lut_byte = 8'h22; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x22 RD-
            10'b1001101110: begin lut_byte = 8'h21; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x21 RD-
            10'b1001110001: begin lut_byte = 8'h31; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x31 RD+(neutral)
            10'b1001110010: begin lut_byte = 8'h32; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x32 RD+(neutral)
            10'b1001110011: begin lut_byte = 8'h38; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x38 RD-
            10'b1001110100: begin lut_byte = 8'h34; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x34 RD+(neutral)
            10'b1001110101: begin lut_byte = 8'h3F; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x3F RD-
            10'b1001110110: begin lut_byte = 8'h30; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x30 RD-
            10'b1001111000: begin lut_byte = 8'h27; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x27 RD+(neutral)
            10'b1001111001: begin lut_byte = 8'h20; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x20 RD-
            10'b1001111010: begin lut_byte = 8'h2F; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x2F RD-
            10'b1001111100: begin lut_byte = 8'h3C; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // K byte=0x3C RD-
            10'b1010000011: begin lut_byte = 8'hBC; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // K byte=0xBC RD+
            10'b1010000101: begin lut_byte = 8'h4F; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x4F RD+
            10'b1010000110: begin lut_byte = 8'h40; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x40 RD+
            10'b1010000111: begin lut_byte = 8'h47; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end  // D byte=0x47 RD-(neutral)
            10'b1010001001: begin lut_byte = 8'h50; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x50 RD+
            10'b1010001010: begin lut_byte = 8'h5F; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x5F RD+
            10'b1010001011: begin lut_byte = 8'h4B; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x4B RD+(neutral)
            10'b1010001100: begin lut_byte = 8'h58; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x58 RD+
            10'b1010001101: begin lut_byte = 8'h4D; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x4D RD+(neutral)
            10'b1010001110: begin lut_byte = 8'h4E; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x4E RD+(neutral)
            10'b1010010001: begin lut_byte = 8'h41; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x41 RD+
            10'b1010010010: begin lut_byte = 8'h42; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x42 RD+
            10'b1010010011: begin lut_byte = 8'h53; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x53 RD+(neutral)
            10'b1010010100: begin lut_byte = 8'h44; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x44 RD+
            10'b1010010101: begin lut_byte = 8'h55; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x55 RD+(neutral)
            10'b1010010110: begin lut_byte = 8'h56; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x56 RD+(neutral)
            10'b1010010111: begin lut_byte = 8'h57; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x57 RD-
            10'b1010011000: begin lut_byte = 8'h48; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x48 RD+
            10'b1010011001: begin lut_byte = 8'h59; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x59 RD+(neutral)
            10'b1010011010: begin lut_byte = 8'h5A; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x5A RD+(neutral)
            10'b1010011011: begin lut_byte = 8'h5B; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x5B RD-
            10'b1010011100: begin lut_byte = 8'h5C; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x5C RD+(neutral)
            10'b1010011101: begin lut_byte = 8'h5D; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x5D RD-
            10'b1010011110: begin lut_byte = 8'h5E; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x5E RD-
            10'b1010100001: begin lut_byte = 8'h5E; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x5E RD+
            10'b1010100010: begin lut_byte = 8'h5D; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x5D RD+
            10'b1010100011: begin lut_byte = 8'h43; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x43 RD+(neutral)
            10'b1010100100: begin lut_byte = 8'h5B; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x5B RD+
            10'b1010100101: begin lut_byte = 8'h45; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x45 RD+(neutral)
            10'b1010100110: begin lut_byte = 8'h46; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x46 RD+(neutral)
            10'b1010100111: begin lut_byte = 8'h48; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x48 RD-
            10'b1010101000: begin lut_byte = 8'h57; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b1; end  // D byte=0x57 RD+
            10'b1010101001: begin lut_byte = 8'h49; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x49 RD+(neutral)
            10'b1010101010: begin lut_byte = 8'h4A; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x4A RD+(neutral)
            10'b1010101011: begin lut_byte = 8'h44; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x44 RD-
            10'b1010101100: begin lut_byte = 8'h4C; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x4C RD+(neutral)
            10'b1010101101: begin lut_byte = 8'h42; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x42 RD-
            10'b1010101110: begin lut_byte = 8'h41; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x41 RD-
            10'b1010110001: begin lut_byte = 8'h51; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x51 RD+(neutral)
            10'b1010110010: begin lut_byte = 8'h52; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x52 RD+(neutral)
            10'b1010110011: begin lut_byte = 8'h58; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x58 RD-
            10'b1010110100: begin lut_byte = 8'h54; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x54 RD+(neutral)
            10'b1010110101: begin lut_byte = 8'h5F; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x5F RD-
            10'b1010110110: begin lut_byte = 8'h50; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x50 RD-
            10'b1010111000: begin lut_byte = 8'h47; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x47 RD+(neutral)
            10'b1010111001: begin lut_byte = 8'h40; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x40 RD-
            10'b1010111010: begin lut_byte = 8'h4F; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x4F RD-
            10'b1010111100: begin lut_byte = 8'h5C; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // K byte=0x5C RD-
            10'b1011000011: begin lut_byte = 8'h9C; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // K byte=0x9C RD+(neutral)
            10'b1011000101: begin lut_byte = 8'h8F; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x8F RD+(neutral)
            10'b1011000110: begin lut_byte = 8'h80; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x80 RD+(neutral)
            10'b1011000111: begin lut_byte = 8'h87; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x87 RD-
            10'b1011001001: begin lut_byte = 8'h90; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x90 RD+(neutral)
            10'b1011001010: begin lut_byte = 8'h9F; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x9F RD+(neutral)
            10'b1011001011: begin lut_byte = 8'h8B; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x8B RD-
            10'b1011001100: begin lut_byte = 8'h98; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x98 RD+(neutral)
            10'b1011001101: begin lut_byte = 8'h8D; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x8D RD-
            10'b1011001110: begin lut_byte = 8'h8E; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x8E RD-
            10'b1011010001: begin lut_byte = 8'h81; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x81 RD+(neutral)
            10'b1011010010: begin lut_byte = 8'h82; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x82 RD+(neutral)
            10'b1011010011: begin lut_byte = 8'h93; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x93 RD-
            10'b1011010100: begin lut_byte = 8'h84; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x84 RD+(neutral)
            10'b1011010101: begin lut_byte = 8'h95; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x95 RD-
            10'b1011010110: begin lut_byte = 8'h96; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x96 RD-
            10'b1011011000: begin lut_byte = 8'h88; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x88 RD+(neutral)
            10'b1011011001: begin lut_byte = 8'h99; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x99 RD-
            10'b1011011010: begin lut_byte = 8'h9A; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x9A RD-
            10'b1011011100: begin lut_byte = 8'h9C; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x9C RD-
            10'b1011100001: begin lut_byte = 8'h9E; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x9E RD+(neutral)
            10'b1011100010: begin lut_byte = 8'h9D; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x9D RD+(neutral)
            10'b1011100011: begin lut_byte = 8'h83; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x83 RD-
            10'b1011100100: begin lut_byte = 8'h9B; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x9B RD+(neutral)
            10'b1011100101: begin lut_byte = 8'h85; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x85 RD-
            10'b1011100110: begin lut_byte = 8'h86; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x86 RD-
            10'b1011101000: begin lut_byte = 8'h97; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x97 RD+(neutral)
            10'b1011101001: begin lut_byte = 8'h89; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x89 RD-
            10'b1011101010: begin lut_byte = 8'h8A; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x8A RD-
            10'b1011101100: begin lut_byte = 8'h8C; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x8C RD-
            10'b1011110001: begin lut_byte = 8'h91; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x91 RD-
            10'b1011110010: begin lut_byte = 8'h92; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x92 RD-
            10'b1011110100: begin lut_byte = 8'h94; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x94 RD-
            10'b1100001011: begin lut_byte = 8'h6B; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x6B RD+(neutral)
            10'b1100001101: begin lut_byte = 8'h6D; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x6D RD+(neutral)
            10'b1100001110: begin lut_byte = 8'h6E; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x6E RD+(neutral)
            10'b1100010011: begin lut_byte = 8'h73; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x73 RD+(neutral)
            10'b1100010101: begin lut_byte = 8'h75; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x75 RD+(neutral)
            10'b1100010110: begin lut_byte = 8'h76; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x76 RD+(neutral)
            10'b1100010111: begin lut_byte = 8'h77; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x77 RD-
            10'b1100011001: begin lut_byte = 8'h79; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x79 RD+(neutral)
            10'b1100011010: begin lut_byte = 8'h7A; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x7A RD+(neutral)
            10'b1100011011: begin lut_byte = 8'h7B; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x7B RD-
            10'b1100011100: begin lut_byte = 8'h7C; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x7C RD+(neutral)
            10'b1100011101: begin lut_byte = 8'h7D; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x7D RD-
            10'b1100011110: begin lut_byte = 8'h7E; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x7E RD-
            10'b1100100011: begin lut_byte = 8'h63; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x63 RD+(neutral)
            10'b1100100101: begin lut_byte = 8'h65; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x65 RD+(neutral)
            10'b1100100110: begin lut_byte = 8'h66; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x66 RD+(neutral)
            10'b1100100111: begin lut_byte = 8'h68; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x68 RD-
            10'b1100101001: begin lut_byte = 8'h69; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x69 RD+(neutral)
            10'b1100101010: begin lut_byte = 8'h6A; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x6A RD+(neutral)
            10'b1100101011: begin lut_byte = 8'h64; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x64 RD-
            10'b1100101100: begin lut_byte = 8'h6C; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x6C RD+(neutral)
            10'b1100101101: begin lut_byte = 8'h62; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x62 RD-
            10'b1100101110: begin lut_byte = 8'h61; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x61 RD-
            10'b1100110001: begin lut_byte = 8'h71; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x71 RD+(neutral)
            10'b1100110010: begin lut_byte = 8'h72; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x72 RD+(neutral)
            10'b1100110011: begin lut_byte = 8'h78; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x78 RD-
            10'b1100110100: begin lut_byte = 8'h74; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x74 RD+(neutral)
            10'b1100110101: begin lut_byte = 8'h7F; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x7F RD-
            10'b1100110110: begin lut_byte = 8'h70; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x70 RD-
            10'b1100111000: begin lut_byte = 8'h67; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x67 RD+(neutral)
            10'b1100111001: begin lut_byte = 8'h60; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x60 RD-
            10'b1100111010: begin lut_byte = 8'h6F; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x6F RD-
            10'b1100111100: begin lut_byte = 8'h7C; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // K byte=0x7C RD-
            10'b1101000011: begin lut_byte = 8'h1C; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // K byte=0x1C RD+(neutral)
            10'b1101000101: begin lut_byte = 8'h0F; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x0F RD+(neutral)
            10'b1101000110: begin lut_byte = 8'h00; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x00 RD+(neutral)
            10'b1101000111: begin lut_byte = 8'h07; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x07 RD-
            10'b1101001001: begin lut_byte = 8'h10; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x10 RD+(neutral)
            10'b1101001010: begin lut_byte = 8'h1F; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x1F RD+(neutral)
            10'b1101001011: begin lut_byte = 8'h0B; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x0B RD-
            10'b1101001100: begin lut_byte = 8'h18; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x18 RD+(neutral)
            10'b1101001101: begin lut_byte = 8'h0D; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x0D RD-
            10'b1101001110: begin lut_byte = 8'h0E; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x0E RD-
            10'b1101010001: begin lut_byte = 8'h01; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x01 RD+(neutral)
            10'b1101010010: begin lut_byte = 8'h02; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x02 RD+(neutral)
            10'b1101010011: begin lut_byte = 8'h13; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x13 RD-
            10'b1101010100: begin lut_byte = 8'h04; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x04 RD+(neutral)
            10'b1101010101: begin lut_byte = 8'h15; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x15 RD-
            10'b1101010110: begin lut_byte = 8'h16; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x16 RD-
            10'b1101011000: begin lut_byte = 8'h08; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x08 RD+(neutral)
            10'b1101011001: begin lut_byte = 8'h19; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x19 RD-
            10'b1101011010: begin lut_byte = 8'h1A; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x1A RD-
            10'b1101011100: begin lut_byte = 8'h1C; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x1C RD-
            10'b1101100001: begin lut_byte = 8'h1E; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x1E RD+(neutral)
            10'b1101100010: begin lut_byte = 8'h1D; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x1D RD+(neutral)
            10'b1101100011: begin lut_byte = 8'h03; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x03 RD-
            10'b1101100100: begin lut_byte = 8'h1B; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x1B RD+(neutral)
            10'b1101100101: begin lut_byte = 8'h05; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x05 RD-
            10'b1101100110: begin lut_byte = 8'h06; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x06 RD-
            10'b1101101000: begin lut_byte = 8'h17; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // D byte=0x17 RD+(neutral)
            10'b1101101001: begin lut_byte = 8'h09; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x09 RD-
            10'b1101101010: begin lut_byte = 8'h0A; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x0A RD-
            10'b1101101100: begin lut_byte = 8'h0C; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x0C RD-
            10'b1101110001: begin lut_byte = 8'h11; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x11 RD-
            10'b1101110010: begin lut_byte = 8'h12; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x12 RD-
            10'b1101110100: begin lut_byte = 8'h14; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0x14 RD-
            10'b1110000011: begin lut_byte = 8'hFC; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // K byte=0xFC RD+(neutral)
            10'b1110100001: begin lut_byte = 8'hFE; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // K byte=0xFE RD+(neutral)
            10'b1110100010: begin lut_byte = 8'hFD; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // K byte=0xFD RD+(neutral)
            10'b1110100100: begin lut_byte = 8'hFB; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // K byte=0xFB RD+(neutral)
            10'b1110101000: begin lut_byte = 8'hF7; lut_kin = 1'b1; lut_valid = 1'b1; lut_changes = 1'b0; lut_is_rdp_variant = 1'b1; end  // K byte=0xF7 RD+(neutral)
            10'b1110110001: begin lut_byte = 8'hF1; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xF1 RD-
            10'b1110110010: begin lut_byte = 8'hF2; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xF2 RD-
            10'b1110110100: begin lut_byte = 8'hF4; lut_kin = 1'b0; lut_valid = 1'b1; lut_changes = 1'b1; lut_is_rdp_variant = 1'b0; end  // D byte=0xF4 RD-
            default: begin lut_byte = 8'h00; lut_kin = 1'b0; lut_valid = 1'b0; lut_changes = 1'b0; lut_is_rdp_variant = 1'b0; end
        endcase
    end

    // A disparity violation only applies to non-neutral entries (lut_changes=1):
    // the specific RD-/RD+ variant received must match the currently tracked
    // running disparity, or the link has a real error even though the bit
    // pattern itself is a legal codeword for *some* disparity state.
    wire disparity_mismatch = lut_valid && lut_changes && (lut_is_rdp_variant != disparity);
    wire missing_lock        = (din == 10'b0);
    wire this_cycle_error    = missing_lock ? 1'b0 : ((!lut_valid) || disparity_mismatch);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout      <= 8'h00;
            kout      <= 1'b0;
            code_err  <= 1'b0;
            disparity <= 1'b0;
        end else if (missing_lock) begin
            dout      <= 8'h00;
            kout      <= 1'b0;
            code_err  <= 1'b0;
            disparity <= 1'b0;   // Resync running disparity on loss of alignment
        end else begin
            dout      <= lut_byte;
            kout      <= lut_kin;
            code_err  <= this_cycle_error;
            disparity <= (lut_valid && !disparity_mismatch) ? (disparity ^ lut_changes) : disparity;
        end
    end

endmodule
