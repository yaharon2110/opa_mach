// ============================================================================
// Module Name:  vsb_top
// Description:  Top-level structural wrapper for the Video Source Board (VSB)
//               Dual-Tree Clock/Reset Design updated for MachXO3LF.
// Target Chip:  Lattice Semiconductor LCMXO3LF-1300E-5MG121I (Nexus Architecture)
// Standards:    Verilog-2001 Standard Baseline
//
// Revision (S-9 remediation, 2026-10-01): clk_81m / serdes_refclk are no
// longer PLL-derived. An independent, low-jitter external oscillator
// (SiT8008, 81.000 MHz) now feeds the TLK1221 SERDES REFCLK pin directly
// via its own PCB trace (verified by Yossi's own SI simulation of the
// 3-way series-resistor split -- SERDES / FPGA / debug-tap buffer), fully
// bypassing the FPGA for that net. This FPGA only receives its own tap of
// the same oscillator on the new osc_81m input. The PLL (u_pll_downlink)
// is otherwise untouched -- it still locks to dec_llc_27m and still
// produces clk_27m_buf -- but its CLKOP (81 MHz) output is now unused and
// left unconnected. See VSB Code Review.md, S-9 / S-9 Addendum.
// ============================================================================

`timescale 1ns / 1ps

module vsb_top (
    // Global Hardware Reset (From PCB External RC Delay Network)
    input  wire        hw_reset_n,

    // Reference Clock Inputs
    input  wire        dec_llc_27m,    // 27.00000 MHz Line-Locked Clock from ADV7182A

    // Independent Low-Jitter Oscillator Input (S-9 remediation)
    // 81.000 MHz, SiT8008, 2.5V LVCMOS. This is the FPGA's own tap of the
    // same oscillator that feeds the TLK1221 SERDES REFCLK pin and the
    // debug-tap clock buffer directly via separate PCB traces (series-
    // resistor 3-way split) -- the FPGA no longer generates or drives
    // SERDES's reference clock. Must land on a dedicated PCLKT pin
    // (planned: L6) -- see pinout rev. 4 (Task 4, not yet applied).
    input  wire        osc_81m,

    // ADV7182A Decoder Parallel Video Interface
    input  wire [7:0]  dec_data,       // 8-bit Pixel Data (D0-D7)
    input  wire        dec_hsync,      // Horizontal Sync
    input  wire        dec_vsync,      // Vertical Sync

    // I2C Master Control Bus (To ADV7182A Config Ports)
    inout  wire        i2c_scl,
    inout  wire        i2c_sda,

    // Local Digital I/O Control Pins
    input  wire [3:0]  local_gpi,      // 4x local downstream input control pins
    output wire [7:0]  local_gpo,      // 8x local extracted upstream output pins

    // TLK1221 Downlink Transmitter TBI Interface (810 Mbps Line Rate)
    output wire [9:0]  serdes_td,      // 10-bit TBI Transmit Parallel Data Bus to SERDES
    // serdes_refclk REMOVED (S-9 remediation): the TLK1221's REFCLK pin is
    // now driven directly from the independent oscillator via its own PCB
    // trace, not from the FPGA -- see osc_81m above.

    // TLK1221 Uplink Receiver TBI Interface
    input  wire [9:0]  serdes_rd,      // 10-bit TBI Receive Parallel Data Bus from SERDES
    input  wire        serdes_sync,    // Sync status indicator signal from SERDES
    input  wire        serdes_rbc0,    // 81 MHz Recovered Byte Clock 0 from SERDES

    // System Board Status Output
    output wire        vsb_status_led
);

     // ========================================================================
    // 1. Internal Clock and Reset Distribution Interconnect
    // ========================================================================
    wire internal_osc_clk;     // ~56.00 MHz Core Oscillator for I2C Config
    wire clk_81m;              // 81.00 MHz Transmit/Serializing Domain -- now
                               // driven directly from osc_81m (S-9 remediation),
                               // no longer a PLL output. Kept as the same
                               // internal wire name so downlink_tx.v's
                               // instantiation below is unaffected.
    wire clk_27m_buf;          // 27.00 MHz Buffered/Phase-Aligned Fabric Clock
                               // (still PLL-derived, still locked to dec_llc_27m)

    assign clk_81m = osc_81m;  // S-9 remediation: direct oscillator feed,
                               // bypasses the PLL entirely for this net.

    wire pll_dl_locked;        // Downlink Transmit PLL Lock Flag
    wire tx_reset_n;           // Synchronized reset for the clk_81m (osc_81m) domain
    wire video_reset_n;        // NEW (S-9): Synchronized reset for the clk_27m_buf
                               // domain. clk_81m and clk_27m_buf are genuinely
                               // independent clocks now, so each domain gets its
                               // own synchronizer instance off the same release
                               // condition (pll_dl_locked) -- reusing one
                               // synchronized signal as the reset-release edge
                               // in a second, unrelated clock domain would be an
                               // unsynchronized crossing. Both still gated by
                               // pll_dl_locked: by design, neither the video-
                               // capture domain nor the TX/serializing domain
                               // should leave reset until the downlink PLL is
                               // locked to dec_llc_27m (per Yossi 2026-10-01:
                               // no reason to run the TX side if the 27 MHz
                               // reference isn't valid anyway).
    wire rx_reset_n;           // Synchronized reset for the serdes_rbc0 (uplink RX) domain
    wire hw_reset;             // Active-high conversion for blocks needing it

    assign hw_reset = ~hw_reset_n;

    // ========================================================================
    // 2. I2C Configuration Bus Interconnect (Untouched)
    // ========================================================================
    wire       wb_cyc_i2c, wb_stb_i2c, wb_we_i2c, wb_ack_i2c;
    wire [7:0] wb_adr_i2c;
    wire [7:0] wb_wdat_i2c;
    wire [7:0] wb_rdat_i2c;
    wire       i2c_init_done;

    // ========================================================================
    // 3. Telemetry and Sub-module Monitoring Links
    // ========================================================================
    wire downlink_tx_stable;   // Transmission state monitor line
    wire uplink_decode_error;  // Receiver error tracking flag

    // ========================================================================
    // 4. CrossLink-NX On-Chip Hardware Hard IP Primitive Instantiations
    // ========================================================================

    // Native OSCH primitive (no IPexpress needed). 53.2 MHz is a
    // standard discrete tap per MachXO3 Data Sheet Table 2-13, ±5.5% accuracy.
    OSCH #( .NOM_FREQ("53.2") ) u_internal_osc (
        .STDBY    (1'b0),              // 0 = oscillator enabled
        .OSC      (internal_osc_clk),
        .SEDSTDBY ()                   // unused
    );

    // Main Clock Multiplier (Accepts 27 MHz LLC Input from ADV7182A)
    // Still generates the clean 27 MHz fabric buffer (clk_27m_buf), locked
    // to dec_llc_27m, exactly as before. CLKOP (81 MHz) is now UNUSED and
    // left unconnected -- the 81 MHz TX/serializing domain comes from the
    // independent oscillator (osc_81m) instead, per the S-9 remediation.
    // Left as a single-output-in-use IP rather than regenerated as a
    // single-output PLL (Yossi's choice, 2026-10-01: lower-risk, no IP
    // regeneration/re-verification needed).
    vsb_pll_downlink u_pll_downlink (
        .CLKI   (dec_llc_27m),        // 27.000 MHz input source
        .RST    (hw_reset),           // RST is active-HIGH per Lattice EHXPLLL spec
        .CLKOP  (),                   // UNUSED (S-9 remediation) -- was clk_81m
        .CLKOS  (clk_27m_buf),        // 27.000 MHz phase-aligned fabric clock
        .LOCK   (pll_dl_locked)       // Stabilized lock tracking flag
    );

    // ========================================================================
    // 5. Reset Tree Synchronizer
    // ========================================================================

	// Transmit Reset Synchronizer: Bound to the independent 81 MHz oscillator
    // domain (osc_81m / clk_81m). Releases the TX/serializing pipeline once
    // the downlink PLL locks -- same release condition as before, now
    // re-synchronized into a genuinely independent clock domain instead of
    // a PLL-related one.
    vsb_reset_sync u_tx_reset_sync (
        .dest_clk  (clk_81m),
        .async_in_n(pll_dl_locked),
        .sync_out_n(tx_reset_n)
    );

    // NEW (S-9 remediation): Video-Capture Reset Synchronizer. Bound to the
    // clk_27m_buf domain. Same release condition (pll_dl_locked) as
    // u_tx_reset_sync, but its own dedicated synchronizer instance -- needed
    // now that clk_81m and clk_27m_buf are independent clocks and a single
    // synchronized signal can't safely serve as the reset-release edge in
    // two unrelated domains. Used by tx_payload_mux.v's clk_27m-domain
    // (video-capture-side) registers once that file is updated.
    vsb_reset_sync u_video_reset_sync (
        .dest_clk  (clk_27m_buf),
        .async_in_n(pll_dl_locked),
        .sync_out_n(video_reset_n)
    );

    // Receive Reset Synchronizer: Bound to the external SERDES Recovered Clock
    // Releases the Uplink pipeline once the TLK1221 extracts a stable line clock
    vsb_reset_sync u_rx_reset_sync (
        .dest_clk  (serdes_rbc0),
        .async_in_n(hw_reset_n),
        .sync_out_n(rx_reset_n)
    );

	// ========================================================================
    // 6. Downlink Transmitter Sub-module Instantiation
    // ========================================================================
    // NOTE: downlink_tx.v's own port list is the next file to be updated to
    // match this instantiation -- it will drop its serdes_refclk output and
    // add a video_reset_n input (for tx_payload_mux.v's clk_27m-domain
    // registers), mirroring the reset split above.
    downlink_tx u_downlink_tx (
        // System Clock and Reset Inputs
        .clk_81m          (clk_81m),            // 81 MHz Transmit Processing Clock (osc_81m-derived)
        .clk_27m          (clk_27m_buf),        // 27 MHz Video Sync-Locked Clock
        .tx_reset_n       (tx_reset_n),         // Synchronized active-low TX reset (clk_81m domain)
        .video_reset_n    (video_reset_n),      // NEW: Synchronized active-low video reset (clk_27m domain)

        // Video and Local Control Input Payload
        .dec_data         (dec_data),           // 8-bit Pixel Data from ADV7182A
        .dec_hsync        (dec_hsync),          // Horizontal Sync flag
        .dec_vsync        (dec_vsync),          // Vertical Sync flag
        .local_gpi        (local_gpi),          // 4-bit Downstream GPIO Control inputs

        // Physical TLK1221 SERDES TBI Transmit Output Bus
        .serdes_td        (serdes_td),          // 10-bit TBI Parallel Bus to SERDES
        // serdes_refclk connection REMOVED (S-9 remediation) -- see note above.

        // Status Feedback Output
        .tx_stable        (downlink_tx_stable)  // Status monitoring out to LED logic
    );

	// ========================================================================
    // 7. Uplink Receiver Sub-module Instantiation
    // ========================================================================
    // No changes (confirmed 2026-10-01): uplink_rx.v has no dependency on
    // dec_llc_27m / pll_dl_locked / clk_81m / clk_27m_buf today -- serdes_rbc0
    // is recovered externally from VDB's transmission, not generated by
    // VSB's own clock tree, so this path is already fault-independent from
    // the downlink/video domain. See VSB Code Review.md, S-9 Remediation.
    uplink_rx u_uplink_rx (
        // Physical TLK1221 SERDES TBI Receive Input Interface
        .serdes_rd        (serdes_rd),          // 10-bit TBI Parallel Bus from SERDES
        .serdes_sync      (serdes_sync),        // Line synchronization tracking pin
        .serdes_rbc0      (serdes_rbc0),        // 81 MHz Recovered Byte Clock from SERDES
        .rx_reset_n       (rx_reset_n),         // Synchronized active-low RX reset

        // Local System Extracted Telemetry Outputs
        .local_gpo        (local_gpo),          // 8-bit Extracted Upstream Control pins
        .decode_error     (uplink_decode_error) // 8b/10b Link Exception alarm flag
    );

    // ========================================================================
    // 8. Pure Hardware Script Driver Module Instantiation
    // ========================================================================
    // Dynamically tracks ADV7182A configuration registers using updated clocks
    vsb_i2c_script_driver u_i2c_script_driver (
        .clk_53m        (internal_osc_clk),   // CrossLink-NX 56.00 MHz core oscillator
        .reset_n        (hw_reset_n),         // System-wide cold reset tracker line

        // Wishbone Interconnect Master Interfaces
        .wb_cyc         (wb_cyc_i2c),
        .wb_stb         (wb_stb_i2c),
        .wb_we          (wb_we_i2c),
        .wb_adr         (wb_adr_i2c),
        .wb_dat_w       (wb_wdat_i2c),
        .wb_dat_r       (wb_rdat_i2c),
        .wb_ack         (wb_ack_i2c),

        // Success Status System Indication Flag
        .i2c_init_done  (i2c_init_done)
    );

	// ========================================================================
    // 9. MachXO3 EFB Hardened I2C Peripheral (IPexpress-generated for
    //    LCMXO3LF-1300E-5MG121I, Wishbone interface, WISHBONE Clock = 53.20 MHz
    //    -- must match internal_osc_clk and vsb_i2c_script_driver.v's clk_53m)
    // ========================================================================
    I2C_VSB u_i2c_vsb (
        .wb_clk_i   (internal_osc_clk),   // Same clock as vsb_i2c_script_driver.v's clk_53m
        .wb_rst_i   (hw_reset),           // wb_rst_i is active-HIGH per Lattice EFB spec
        .wb_cyc_i   (wb_cyc_i2c),
        .wb_stb_i   (wb_stb_i2c),
        .wb_we_i    (wb_we_i2c),
        .wb_adr_i   (wb_adr_i2c),
        .wb_dat_i   (wb_wdat_i2c),        // write data INTO the EFB (from the script driver)
        .wb_dat_o   (wb_rdat_i2c),        // read data OUT of the EFB (to the script driver)
        .wb_ack_o   (wb_ack_i2c),         // drives wb_ack_i2c directly now -- no glue needed
        .i2c1_scl   (i2c_scl),
        .i2c1_sda   (i2c_sda),
        .i2c1_irqo  ()                    // unused -- script driver polls SR, no interrupt needed
    );

    // ========================================================================
    // 10. Board Diagnostic Status Engine
    // ------------------------------------------------------------------------
    // LED state priority (agreed 2026-10-01, implemented in board_status_led.v
    // -- documented here so the meaning never has to be re-derived from code):
    //   1. uplink_error              -> SLOW FLASH (checked first: uplink
    //                                   status is never hidden by a downlink/
    //                                   I2C condition)
    //   2. !i2c_init_done            -> OFF
    //   3. !pll_locked || !downlink_stable -> FAST FLASH
    //   4. else                      -> SOLID ON
    // Known, accepted limitation (option 3 of 3 considered -- see VSB Code
    // Review.md S-9 Remediation): a single monochrome LED can't fully and
    // independently represent all three health axes (I2C / downlink-PLL /
    // uplink) at once. E.g. if I2C fails (state 2) while the uplink is
    // genuinely healthy but has never asserted an error, the LED shows OFF
    // rather than a distinct "uplink confirmed good" state -- a true
    // positive-health indicator per axis would need a second LED or a
    // time-multiplexed blink sequence; deliberately not pursued now.
    // ========================================================================
    board_status_led u_vsb_status_led (
        .clk_54m         (internal_osc_clk),
        .reset_n         (hw_reset_n),
        .pll_locked      (pll_dl_locked),
        .i2c_init_done   (i2c_init_done),
        .uplink_error    (uplink_decode_error),
        .downlink_stable (downlink_tx_stable),
        .status_led      (vsb_status_led)
    );

endmodule
