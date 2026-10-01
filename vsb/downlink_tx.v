// ============================================================================
// Module Name:  downlink_tx
// Description:  Downlink Transmitter Core for the Video Source Board (VSB).
//               Aggregates video data, encodes via 8b/10b, and drives the TBI bus.
// Standards:    Verilog-2001 Standard Baseline
//
// Revision (S-9 remediation, 2026-10-01):
//  - serdes_refclk output REMOVED. The TLK1221's REFCLK pin is now driven
//    directly by the independent oscillator via its own PCB trace (see
//    vsb_top.v's osc_81m port and comments) -- this module no longer
//    generates or passes through any reference clock to the SERDES.
//  - video_reset_n input ADDED. clk_81m and clk_27m are now genuinely
//    independent clocks (clk_81m comes from the external oscillator, no
//    longer the PLL), so the clk_27m-domain registers inside
//    tx_payload_mux.v need their own synchronized reset instead of reusing
//    tx_reset_n (which is only synchronized to clk_81m). Both resets still
//    share the same release condition (pll_dl_locked) -- see vsb_top.v.
//  - tx_stable now reflects both resets released, not just tx_reset_n.
// ============================================================================

`timescale 1ns / 1ps

module downlink_tx (
    // System Clock and Reset Inputs
    input  wire        clk_81m,        // 81 MHz Transmit/Serializing Clock (independent oscillator)
    input  wire        clk_27m,        // 27 MHz Video Sync-Locked Clock
    input  wire        tx_reset_n,     // Synchronized active-low reset, clk_81m domain
    input  wire        video_reset_n,  // NEW: Synchronized active-low reset, clk_27m domain

    // Video and Local Control Input Payload from ADV7182A
    input  wire [7:0]  dec_data,       // 8-bit Pixel Data (D0-D7)
    input  wire        dec_hsync,      // Horizontal Sync flag
    input  wire        dec_vsync,      // Vertical Sync flag
    input  wire [3:0]  local_gpi,      // 4-bit Downstream GPIO Control inputs

    // Physical TLK1221 SERDES TBI Transmit Output Bus
    output wire [9:0]  serdes_td,      // 10-bit TBI Parallel Bus to SERDES
    // serdes_refclk REMOVED (S-9 remediation) -- see header note above.

    // Status Feedback Output
    output wire        tx_stable       // Status monitoring out to LED logic
);

    // Flag to indicate transmission stability -- now requires BOTH the
    // clk_81m-domain reset and the clk_27m-domain reset to be released,
    // since the pipeline spans both domains (see tx_payload_mux.v).
    assign tx_stable = tx_reset_n && video_reset_n;

    // ========================================================================
    // Sub-module Interconnect & Component Instantiations
    // ========================================================================

// ========================================================================
    // Internal Control Signals
    // ========================================================================
    wire [7:0] tx_byte;      // Raw 8-bit byte chosen by the multiplexer
    wire       tx_is_k;      // Control bit indicating an 8b/10b K-code symbol

    // ========================================================================
    // 1. Synchronous Video Payload Capture & 27->81 MHz Domain Crossing Stage
    // ========================================================================
    // This block bridges the 27 MHz parallel input domain (locked to
    // dec_llc_27m/genlock) to the 81 MHz serializing domain (now driven by
    // an independent oscillator, no longer clock-related to the 27 MHz
    // side -- S-9 remediation). NOTE: as of this file, tx_payload_mux.v
    // itself still has its pre-remediation 2-flop toggle synchronizer and
    // its single tx_reset_n port -- that is the next file to update (the
    // real work: replacing the synchronizer with an async elastic FIFO +
    // blanking-interval justification, and splitting its reset usage to
    // take tx_reset_n for the clk_81m-domain registers and video_reset_n
    // for the clk_27m-domain registers). The video_reset_n connection below
    // anticipates that update.
    tx_payload_mux u_tx_payload_mux (
        // Clock and Reset Links
        .clk_81m        (clk_81m),
        .clk_27m        (clk_27m),
        .tx_reset_n     (tx_reset_n),
        .video_reset_n  (video_reset_n),   // NEW -- see note above

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
    // Unaffected by S-9 remediation -- purely clk_81m domain, same as before.
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
