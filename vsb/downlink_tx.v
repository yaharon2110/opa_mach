// ============================================================================
// Module Name:  downlink_tx
// Description:  Downlink Transmitter Core for the Video Source Board (VSB).
//               Aggregates video data, encodes via 8b/10b, and drives the TBI bus.
// Standards:    Verilog-2001 Standard Baseline
// ============================================================================

`timescale 1ns / 1ps

module downlink_tx (
    // System Clock and Reset Inputs
    input  wire        clk_81m,        // 81 MHz Transmit Processing Clock
    input  wire        clk_27m,        // 27 MHz Video Sync-Locked Clock
    input  wire        tx_reset_n,     // Synchronized active-low TX reset

    // Video and Local Control Input Payload from ADV7182A
    input  wire [7:0]  dec_data,       // 8-bit Pixel Data (D0-D7)
    input  wire        dec_hsync,      // Horizontal Sync flag
    input  wire        dec_vsync,      // Vertical Sync flag
    input  wire [3:0]  local_gpi,      // 4-bit Downstream GPIO Control inputs

    // Physical TLK1221 SERDES TBI Transmit Output Bus
    output wire [9:0]  serdes_td,      // 10-bit TBI Parallel Bus to SERDES
    output wire        serdes_refclk,  // 81 MHz Transmit Output Clock

    // Status Feedback Output
    output wire        tx_stable       // Status monitoring out to LED logic
);
     
    // Direct center-aligned reference clock pass-through to the external SERDES
    assign serdes_refclk = clk_81m;
    
    // Flag to indicate transmission stability (asserted active when reset is released)
    assign tx_stable = tx_reset_n;

    // ========================================================================
    // Sub-module Interconnect & Component Instantiations
    // ========================================================================
	
// ========================================================================
    // Internal Control Signals
    // ========================================================================
    wire [7:0] tx_byte;      // Raw 8-bit byte chosen by the multiplexer
    wire       tx_is_k;      // Control bit indicating an 8b/10b K-code symbol

    // ========================================================================
    // 1. Synchronous Video Payload Capture & 3:1 Multiplexer Stage
    // ========================================================================
    // This block bridges the 27 MHz parallel input domain to the 81 MHz serializing 
    // domain, arranging your data payload into a predictable 3-byte framing cycle.
    tx_payload_mux u_tx_payload_mux (
        // Clock and Reset Links
        .clk_81m        (clk_81m),
        .clk_27m        (clk_27m),
        .tx_reset_n     (tx_reset_n),

        // Video and Local GPIO Signals
        .dec_data       (dec_data),
        .dec_hsync      (dec_hsync),
        .dec_vsync      (dec_vsync),
        .local_gpi      (local_gpi),

        // Parallel Selected Outputs
        .mux_byte_o     (tx_byte),
        .mux_is_k_o     (tx_is_k)
    );

    // ========================================================================
    // 2. Synthesizable 8b/10b Encoder Block
    // ========================================================================
    // Processes the raw 8-bit stream from the multiplexer into a DC-balanced 
    // 10-bit parallel TBI word. It monitors running disparity every 81 MHz clock cycle.
    encoder_8b10b u_encoder_8b10b (
        // Clock and Reset Lines
        .clk            (clk_81m),
        .rst_n          (tx_reset_n),

        // Data Inputs
        .din            (tx_byte),       // 8-bit data character map input
        .kin            (tx_is_k),       // Control pin (1 = K-character, 0 = D-data)

        // TBI Parallel Interface Outputs
        .dout           (serdes_td)      // Final 10-bit codeword to the TLK1221
    );

endmodule	
