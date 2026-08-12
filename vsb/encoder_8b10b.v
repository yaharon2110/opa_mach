// ============================================================================
// Module Name:  encoder_8b10b
// Description:  Standard synthesizable 8b/10b encoder based on the IBM patent.
//               Maintains DC balance across the differential transmission lines.
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

    // Track the running disparity status (0 = Negative Disparity, 1 = Positive Disparity)
    reg disparity;

    // Split input byte into standard 5b/6b and 3b/4b nomenclature groups
    wire [4:0] a_b_c_d_e = din[4:0];
    wire [2:0] f_g_h     = din[7:5];

    // Interconnect lines for encoded sub-block partitions
    wire [5:0] sub_block_6b;
    wire [3:0] sub_block_4b;
    
    // Tracking classifications for disparity requirements
    wire complement_6b;
    wire complement_4b;
    wire disp_6b_out;
    wire disp_4b_out;

    // ========================================================================
    // 1. Structural Combinational Combinatorics for 5b/6b Translation
    // ========================================================================
    // Decodes the lower 5 bits into a 6-bit sub-block code, tracking 
    // disparity discrepancies and control-code exception behaviors.
    assign sub_block_6b[0] = a_b_c_d_e[0];
    assign sub_block_6b[1] = a_b_c_d_e[1];
    assign sub_block_6b[2] = a_b_c_d_e[2];
    assign sub_block_6b[3] = a_b_c_d_e[3];
    assign sub_block_6b[4] = (a_b_c_d_e[4] & ~(a_b_c_d_e[0] & a_b_c_d_e[1] & a_b_c_d_e[2] & a_b_c_d_e[3])) | 
                             (~a_b_c_d_e[4] & (a_b_c_d_e[0] & a_b_c_d_e[1] & a_b_c_d_e[2] & a_b_c_d_e[3]));
    assign sub_block_6b[5] = (((a_b_c_d_e[0] ^ a_b_c_d_e[1]) & (a_b_c_d_e[2] ^ a_b_c_d_e[3])) & ~a_b_c_d_e[4]) | 
                             (a_b_c_d_e[4] & (a_b_c_d_e[0] & a_b_c_d_e[1] & a_b_c_d_e[2] & a_b_c_d_e[3])) | kin;

    // Disparity calculation flags for the 6b sub-block
    assign complement_6b = (disparity == 1'b0) ? 
                           (sub_block_6b == 6'b110001 || sub_block_6b == 6'b110010 || sub_block_6b == 6'b110100 || sub_block_6b == 6'b111000) : 
                           (sub_block_6b == 6'b001110 || sub_block_6b == 6'b001101 || sub_block_6b == 6'b001011 || sub_block_6b == 6'b000111);
    
    assign disp_6b_out = disparity ^ (sub_block_6b[5] ^ sub_block_6b[4]);

    // ========================================================================
    // 2. Structural Combinational Combinatorics for 3b/4b Translation
    // ========================================================================
    // Decodes the upper 3 bits into a 4-bit sub-block code based on 
    // the running disparity state exiting the 5b/6b block.
    assign sub_block_4b[0] = f_g_h[0];
    assign sub_block_4b[1] = f_g_h[1];
    assign sub_block_4b[2] = f_g_h[2];
    assign sub_block_4b[3] = (f_g_h[2] & ~(f_g_h[0] & f_g_h[1])) | (~f_g_h[2] & (f_g_h[0] & f_g_h[1])) | (kin & f_g_h[1] & f_g_h[0]);

    // Disparity calculation flags for the 4b sub-block
    assign complement_4b = (disp_6b_out == 1'b0) ? 
                           (sub_block_4b == 4'b1100 || sub_block_4b == 4'b1010 || sub_block_4b == 4'b1001) : 
                           (sub_block_4b == 4'b0011 || sub_block_4b == 4'b0101 || sub_block_4b == 4'b0110);
    
    assign disp_4b_out = disp_6b_out ^ (sub_block_4b[3] ^ sub_block_4b[2]);

    // ========================================================================
    // 3. Sequential Disparity Update and Output Alignment (81 MHz Domain)
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            disparity <= 1'b0; // Default baseline disparity initialization state
            dout      <= 10'b0000000000;
        end else begin
            // Commit dynamic disparity tracking update
            disparity <= disp_4b_out;

            // Assemble final 10-bit structural code package applying corrections
            dout[5:0] <= complement_6b ? ~sub_block_6b : sub_block_6b;
            dout[9:6] <= complement_4b ? ~sub_block_4b : sub_block_4b;
        end
    end

endmodule
