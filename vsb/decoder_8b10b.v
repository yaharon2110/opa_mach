// ============================================================================
// Module Name:  decoder_8b10b
// Description:  Standard synthesizable 8b/10b decoder.
//               Translates 10-bit TBI code-words back into raw 8-bit bytes.
// Standards:    Verilog-2001 Standard Baseline
// ============================================================================

`timescale 1ns / 1ps

module decoder_8b10b (
    input  wire        clk,       // 81 MHz Recovered Clock (serdes_rbc0)
    input  wire        rst_n,     // Active-low synchronized reset
    input  wire [9:0]  din,       // Comma-aligned 10-bit input word
    output reg  [7:0]  dout,      // Decoded 8-bit output byte
    output reg         kout,      // Control character flag (1 = K-code, 0 = Data)
    output reg         code_err   // High for illegal 8b/10b symbol sequences
);

    // Unpack the 10-bit codeword into standard sub-block notation
    // 6b sub-block bits: abcdei -> din[5:0]
    // 4b sub-block bits: fghj   -> din[9:6]
    wire a = din[0];
    wire b = din[1];
    wire c = din[2];
    wire d = din[3];
    wire e = din[4];
    wire i = din[5];
    wire f = din[6];
    wire g = din[7];
    wire h = din[8];
    wire j = din[9];

    // Internal pre-decode classification gates
    wire missing_lock = (din == 10'b0);
    
    // Disparity classification properties for the 6b block
    wire a7_b7_c7 = (a & b & c);
    wire a0_b0_c0 = (!a & !b & !c);
    
    // Combinational Decoding Logic Trees
    wire [4:0] decode_5b;
    wire [2:0] decode_3b;
    wire       is_k_character;
    wire       error_detected;

    // ========================================================================
    // 1. Combinational Mapping Tables (5b/6b & 3b/4b Recovery)
    // ========================================================================
    assign decode_5b[0] = (a ^ b) ? !a : (c & d & (e ^ i));
    assign decode_5b[1] = (a & b & !c & !d & !e & !i) | (!a & !b & c & d & e & i) | (b & (c ^ d) ? !b : (a & c & (e ^ i)));
    assign decode_5b[2] = (c ^ d) ? !c : (a & b & (e ^ i));
    assign decode_5b[3] = (a & b & c & !d & !e & !i)  | (!a & !b & !c & d & e & i) | (d & (a ^ b) ? !d : (b & c & (e ^ i)));
    assign decode_5b[4] = (e ^ i) ? !e : (a & b & c & d);

    assign decode_3b[0] = (f ^ g) ? !f : (h & j);
    assign decode_3b[1] = (f & g & !h & !j) | (!f & !g & h & j) | (g & (h ^ j) ? !g : (f & h));
    assign decode_3b[2] = (h ^ j) ? !h : (f & g);

    // K28.5 detection criteria: (abcdei = 001111 or 110000) and (fghj = 1010 or 0101)
    assign is_k_character = ((!a & !b & c & d & e & i)  || (a & b & !c & !d & !e & !i)) && 
                            ((f & !g & h & !j) || (!f & g & !h & j));

    // Basic legal symbol sequence evaluation validation gate
    assign error_detected = (a7_b7_c7 & d & e & i) || (a0_b0_c0 & !d & !e & !i) ||
                            (f & g & h & j)        || (!f & !g & !h & !j);

    // ========================================================================
    // 2. Synchronous Pipeline Output Registers
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout     <= 8'h00;
            kout     <= 1'b0;
            code_err <= 1'b0;
        end else if (missing_lock) begin
            dout     <= 8'h00;
            kout     <= 1'b0;
            code_err <= 1'b0;
        end else begin
            dout     <= {decode_3b, decode_5b};
            kout     <= is_k_character;
            code_err <= error_detected;
        end
    end

endmodule
