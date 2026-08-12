// ============================================================================
// Module Name:  vsb_top
// Description:  Top-level structural wrapper for the Video Source Board (VSB)
//               Dual-Tree Clock/Reset Design updated for CrossLink-NX.
// Target Chip:  Lattice Semiconductor LIFCL-40-7MG121A (Nexus Architecture)
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
    
    // CrossLink-NX Native Hardened Internal High-Frequency Ring Oscillator
    // Replaces the legacy MachXO3 OSCH macro cell to drive MCU/Config state tracks.
	SYSOSC u_system_osc (
        .hf_out_en_i 	(1'b1),             // Explicitly enable the clock output buffer
        .hf_clk_out_o	(internal_osc_clk)
	);

    // Main Clock Multiplier (Accepts 27 MHz LLC Input from ADV7182A)
    // Generates the 81 MHz TBI processing clock and a clean 27 MHz fabric buffer
    vsb_pll_downlink_nx u_pll_downlink (
        .clki_i		(dec_llc_27m),        // 27.000 MHz input source
        .rstn_i     (hw_reset_n),         // Clean active-low external board reset
        .clkop_o   	(clk_81m),            // Output Channel 0: 81.000 MHz TX primary clock
        .clkos_o   	(clk_27m_buf),        // Output Channel 1: 27.000 MHz phase-aligned fabric clock
        .lock_o    	(pll_dl_locked)       // Stabilized lock tracking flag
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
        
        // Pin Pass-Through Interfaces
        .i2c_scl        (i2c_scl),            
        .i2c_sda        (i2c_sda),            
        
        // Success Status System Indication Flag
        .i2c_init_done  (i2c_init_done)
    );

	// ========================================================================
    // 9. CrossLink-NX Hardened Peripheral I2C Architecture Instance
    // ========================================================================
    // Replaces legacy MachXO3 EFB hardware macro with standard CrossLink-NX
    // LMMI-based hardware engine wrapper. Maps Wishbone cleanly to LMMI.
    
    wire lmmi_rdata_valid;
    wire i2c_bus_busy;
    wire i2c_ready;

    // Connect the script driver's Wishbone output handshake back to LMMI ready signal
    assign wb_ack_i2c = i2c_ready;

    I2C_VSB u_efb_hardware_macro (
        // Physical Open-Drain Board Level Pins (IO Buffers Included inside IP)
        .scl_io             (i2c_scl),            
        .sda_io             (i2c_sda),            
        
        // System Clock and Reset Line Inputs
        .clk_i              (internal_osc_clk),   // Driven synchronously at 56.00 MHz
        .reset_n_i          (hw_reset_n),         // Native active-low reset link
        .i2clsrrstn_i       (hw_reset_n),         // Tie low-speed reset to global line
        
        // Wishbone-to-LMMI Protocol Bridge Adaptations
        .lmmi_request_i     (wb_cyc_i2c && wb_stb_i2c), // Request is high when cycle & strobe are active
        .lmmi_wr_rdn_i      (wb_we_i2c),          // 1 = Write transaction, 0 = Read transaction
        .lmmi_offset_i      (wb_adr_i2c[5:0]),    // LMMI takes lower 6 bits of your I2C address register
        .lmmi_wdata_i       (wb_wdat_i2c),        // 8-bit parallel write data bus
        .lmmi_rdata_o       (wb_rdat_i2c),        // 8-bit parallel read data bus
        .lmmi_ready_o       (i2c_ready),          // Handshake cycle complete strobe
        .lmmi_rdata_valid_o (lmmi_rdata_valid),   // Read byte valid qualification tracking
        
        // Unused Peripheral Interface Flags (Left Floating safely in Master Mode)
        .int_o              (),                   // Interrupt line output
        .busbusy_o          (i2c_bus_busy),       // Real-time bus status monitoring flag
        .insleep_o          (),                   // Core sleep status register flag
        .mrdcmpl_o          (),                   // Master read complete cycle flag
        .slvaddrmatch_o     (),                   // Slave address tracking detection
        .slvaddrmatchscl_o  (),                   // Slave match SCL status line flag
        .srdwr_o            ()                    // Slave read/write direction flag
    );

    // ========================================================================
    // 9. Board Diagnostic Status Engine
    // ========================================================================
    board_status_led u_vsb_status_led (
        .clk_54m         (tx_byte_clk_54m),     
        .reset_n         (hw_reset_n),  
        .pll_locked      (pll_dl_locked),       
        .i2c_init_done   (i2c_init_done),       
        .uplink_error    (uplink_decode_error), 
        .downlink_stable (downlink_tx_stable),       
        .status_led      (vsb_status_led)       
    );

endmodule
