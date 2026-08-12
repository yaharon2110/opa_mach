// ============================================================================
// Module Name:  tx_payload_mux
// Description:  Bridges 27 MHz parallel data to 81 MHz TBI formatting using
//               a 3-byte multiplexer structure (Video, Controls, and K28.5 Marker).
// Standards:    Verilog-2001 Standard Baseline
// ============================================================================

`timescale 1ns / 1ps

module tx_payload_mux (
    // Clock and Reset Links
    input  wire        clk_81m,        // 81 MHz Transmit Processing Clock
    input  wire        clk_27m,        // 27 MHz Video Sync-Locked Clock
    input  wire        tx_reset_n,     // Synchronized active-low TX reset

    // Video and Local GPIO Signals from ADV7182A
    input  wire [7:0]  dec_data,       // 8-bit Pixel Data (D0-D7)
    input  wire        dec_hsync,      // Horizontal Sync flag
    input  wire        dec_vsync,      // Vertical Sync flag
    input  wire [3:0]  local_gpi,      // 4-bit Downstream GPIO Control inputs

    // Parallel Selected Outputs
    output reg  [7:0]  mux_byte_o,     // 8-bit selected byte to encoder
    output reg         mux_is_k_o      // 1 = K-character symbol, 0 = D-data symbol
);

    // Constant definition for the 8b/10b Comma character (K28.5)
    localparam [7:0] K28_5_BYTE = 8'hBC;

    // ========================================================================
    // 1. Synchronous Video Payload Capture (27 MHz Domain)
    // ========================================================================
    reg [7:0] reg_byte0;  // Holds D[7:0] (Video Data)
    reg [7:0] reg_byte1;  // Holds HSYNC + VSYNC + GPI[3:0] + 2b'00 padding

    always @(posedge clk_27m or negedge tx_reset_n) begin
        if (!tx_reset_n) begin
            reg_byte0 <= 8'h00;
            reg_byte1 <= 8'h00;
        end else begin
            reg_byte0 <= dec_data;
            reg_byte1 <= {2'b00, local_gpi, dec_vsync, dec_hsync};
        end
    end

    // ========================================================================
    // 2. 81 MHz Processing State Counter & Data Routing Multiplexer
    // ========================================================================
    reg [1:0] mux_count;  // Tracks the current cycle slice (0, 1, or 2)

    always @(posedge clk_81m or negedge tx_reset_n) begin
        if (!tx_reset_n) begin
            mux_count  <= 2'b00;
            mux_byte_o <= 8'h00;
            mux_is_k_o <= 1'b0;
        end else begin
            // 0 to 2 counter sequencing natively at 81 MHz
            if (mux_count >= 2'b10) begin
                mux_count <= 2'b00;
            end else begin
                mux_count <= mux_count + 1'b1;
            end

            // 3-to-1 data multiplexer mapping out the sequence
            case (mux_count)
                2'b00: begin
                    mux_byte_o <= reg_byte0;  // Send Byte 0: Video Bits
                    mux_is_k_o <= 1'b0;       // Mark as Data payload
                end
                
                2'b01: begin
                    mux_byte_o <= reg_byte1;  // Send Byte 1: Syncs and GPIOs
                    mux_is_k_o <= 1'b0;       // Mark as Data payload
                end
                
                2'b10: begin
                    mux_byte_o <= K28_5_BYTE; // Send Byte 2: Structural K28.5 Alignment Comma
                    mux_is_k_o <= 1'b1;       // Assert K-code flag to 8b/10b encoder
                end
                
                default: begin
                    mux_byte_o <= K28_5_BYTE;
                    mux_is_k_o <= 1'b1;
                end
            endcase
        end
    end

endmodule
