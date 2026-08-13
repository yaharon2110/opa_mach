// ============================================================================
// Module Name:  vsb_reset_sync
// Description:  Asynchronous Assert, Synchronous Counter-Stretched Deassert.
//               Guarantees clock distribution stabilization before logic release.
// ============================================================================

`timescale 1ns / 1ps

module vsb_reset_sync (
    input  wire        dest_clk,   // Target domain clock
    input  wire        async_in_n, // Raw clearing trigger source
    output reg         sync_out_n  // Stretched active-low system reset out
);

    // Two-stage metastability synchronization pipeline
    reg [1:0] sync_reg;
    
    // 16-bit delay counter (Creates a 65,536 clock cycle stretching window)
    reg [15:0] delay_counter;

    // Stage 1: Asynchronous capture of the input condition
    always @(posedge dest_clk or negedge async_in_n) begin
        if (!async_in_n) begin
            sync_reg <= 2'b00;
        end else begin
            sync_reg <= {sync_reg[0], 1'b1};
        end
    end

    // Stage 2: Counter-based synchronous reset stretching loop
    always @(posedge dest_clk or negedge async_in_n) begin
        if (!async_in_n) begin
            // The instant an abort/clear happens, drop the timer and output immediately
            delay_counter <= 16'h0;
            sync_out_n    <= 1'b0;
        end else begin
            if (sync_reg[1] == 1'b1) begin
                // The input condition is stable. Start counting clock pulses.
                if (delay_counter < 16'hFFFF) begin
                    delay_counter <= delay_counter + 1'b1;
                    sync_out_n    <= 1'b0; // Keep the system held in reset
                end else begin
                    delay_counter <= delay_counter; // Lock the counter at max value
                    sync_out_n    <= 1'b1; // Safely release the synchronous system reset!
                end
            end else begin
                delay_counter <= 16'h0;
                sync_out_n    <= 1'b0;
            end
        end
    end

endmodule
