// ============================================================================
// Module Name:  uplink_rx
// Description:  Uplink Receiver Core for the Video Source Board (VSB).
//               Accepts raw 10-bit TBI data, handles word alignment, decodes 
//               8b/10b, and extracts the 8-bit upstream telemetry GPIO bus.
// Standards:    Verilog-2001 Standard Baseline
// ============================================================================

`timescale 1ns / 1ps

module uplink_rx (
    // Physical TLK1221 SERDES TBI Receive Input Interface
    input  wire [9:0]  serdes_rd,      // 10-bit TBI Parallel Bus from SERDES
    input  wire        serdes_sync,    // Line synchronization tracking pin from SERDES
    input  wire        serdes_rbc0,    // 81 MHz Recovered Byte Clock from SERDES
    input  wire        rx_reset_n,     // Synchronized active-low RX reset

    // Local System Extracted Telemetry Outputs
    output wire [7:0]  local_gpo,      // 8-bit Extracted Upstream Control pins
    output wire        decode_error    // 8b/10b Link Exception alarm flag
);

    // ========================================================================
    // Internal Structural Interconnect Wires
    // ========================================================================
    reg  [9:0] aligned_10b_word;       // Managed directly inline by the SYNC flag
    reg        lock_acquired;          // Local alignment stability track flag
    
    wire [7:0] rx_decoded_byte;        // 8-bit decoded raw byte data
    wire       rx_is_k;                // Control character flag (1 = K-code, 0 = Data)

  
    // ========================================================================
    // Sub-module Component Instantiations
    // ========================================================================

    // 1. 10-bit Comma Word Aligner / Barrel Shifter
    // Locks onto incoming K28.5 comma streams to establish proper word boundaries.
    always @(posedge serdes_rbc0 or negedge rx_reset_n) begin
        if (!rx_reset_n) begin
            lock_acquired    <= 1'b0;
            aligned_10b_word <= 10'b0;
        end else begin
            if (serdes_sync) begin
                lock_acquired <= 1'b1;
            end

            if (lock_acquired || serdes_sync) begin
                aligned_10b_word <= serdes_rd;
            end else begin
                aligned_10b_word <= 10'b0;
            end
        end
    end

    // 2. Synthesizable 8b/10b Decoder Block
    // Translates the aligned 10-bit codeword back into its original 8-bit character byte,
    // verifying running disparity legality and asserting error tracking exceptions.
    decoder_8b10b u_decoder_8b10b (
        .clk             (serdes_rbc0),
        .rst_n           (rx_reset_n),
        .din             (aligned_10b_word),
        .dout            (rx_decoded_byte),
        .kout            (rx_is_k),
        .code_err        (decode_error)
    );

    // ========================================================================
    // 3. Inline Telemetry Extraction & Latching Logic
    // ========================================================================
    always @(posedge serdes_rbc0 or negedge rx_reset_n) begin
        if (!rx_reset_n) begin
            local_gpo <= 8'h00;
        end else begin
            // When a regular data byte arrives (not a K-character), 
            // it contains all 8 GPIOs at once. Latch them immediately.
            if (!rx_is_k && !serdes_sync) begin
                local_gpo <= rx_decoded_byte;
            end
        end
    end

endmodule	
