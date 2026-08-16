// ============================================================================
// Module Name:  vsb_top
// Description:  Top-level structural wrapper for the Video Source Board (VSB)
//               Dual-Tree Clock/Reset Design updated for MachXO3LF.
// Target Chip:  Lattice Semiconductor LCMXO3LF-1300E-5MG121I (Nexus Architecture)
// Standards:    Verilog-2001 Standard Baseline
// ============================================================================

`timescale 1ns / 1ps

module vsb_top (
    // Global Hardware Reset (From PCB External RC Delay Network)
    input  wire        hw_reset_n,

    // Reference Clock Inputs
    input  wire        dec_llc_27m,    // 27.00000 MHz Line-Locked Clock from ADV7182A

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
    output wire        serdes_refclk,  // 81 MHz Center-Aligned Reference Clock to SERDES

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
    wire clk_81m;              // 81.00 MHz Synchronous Transmit Domain
    wire clk_27m_buf;          // 27.00 MHz Buffered/Phase-Aligned Fabric Clock
    
    wire pll_dl_locked;        // Downlink Transmit PLL Lock Flag
    wire tx_reset_n;           // Synchronized reset for the 81 MHz TX Pipeline
    wire rx_reset_n;           // Synchronized reset for the 81 MHz RX Pipeline
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


	assign hw_reset = ~hw_reset_n;

    // Main Clock Multiplier (Accepts 27 MHz LLC Input from ADV7182A)
    // Generates the 81 MHz TBI processing clock and a clean 27 MHz fabric buffer
    // Regenerated for the MachXO3LF target (replaces the CrossLink-NX
    // "vsb_pll_downlink_nx" artifact); divider values verified for
    // CLKOP=81.000000 MHz / CLKOS=27.000000 MHz exact (VCO=486 MHz).
    vsb_pll_downlink u_pll_downlink (
        .CLKI   (dec_llc_27m),        // 27.000 MHz input source
        .RST    (hw_reset),           // RST is active-HIGH per Lattice EHXPLLL spec
        .CLKOP  (clk_81m),            // 81.000 MHz TX primary clock
        .CLKOS  (clk_27m_buf),        // 27.000 MHz phase-aligned fabric clock
        .LOCK   (pll_dl_locked)       // Stabilized lock tracking flag
    );
	
    // ========================================================================
    // 5. Reset Tree Synchronizer
    // ========================================================================

	// Transmit Reset Synchronizer: Bound to the local 81 MHz Transmit Clock
    // Releases the Downlink pipeline once the core PLL locks stably
    vsb_reset_sync u_tx_reset_sync (
        .dest_clk  (clk_81m),
        .async_in_n(pll_dl_locked),
        .sync_out_n(tx_reset_n)
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
    downlink_tx u_downlink_tx (
        // System Clock and Reset Inputs
        .clk_81m          (clk_81m),            // 81 MHz Transmit Processing Clock
        .clk_27m          (clk_27m_buf),        // 27 MHz Video Sync-Locked Clock
        .tx_reset_n       (tx_reset_n),         // Synchronized active-low TX reset

        // Video and Local Control Input Payload
        .dec_data         (dec_data),           // 8-bit Pixel Data from ADV7182A
        .dec_hsync        (dec_hsync),          // Horizontal Sync flag
        .dec_vsync        (dec_vsync),          // Vertical Sync flag
        .local_gpi        (local_gpi),          // 4-bit Downstream GPIO Control inputs

        // Physical TLK1221 SERDES TBI Transmit Output Bus
        .serdes_td        (serdes_td),          // 10-bit TBI Parallel Bus to SERDES
        .serdes_refclk    (serdes_refclk),      // 81 MHz Transmit Output Clock

        // Status Feedback Output
        .tx_stable        (downlink_tx_stable)  // Status monitoring out to LED logic
    );

	// ========================================================================
    // 7. Uplink Receiver Sub-module Instantiation
    // ========================================================================
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
