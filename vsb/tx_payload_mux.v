`timescale 1ns / 1ps

module tx_payload_mux (
    input  wire        clk_81m,
    input  wire        clk_27m,
    input  wire        tx_reset_n,

    input  wire [7:0]  dec_data,
    input  wire        dec_hsync,
    input  wire        dec_vsync,
    input  wire [3:0]  local_gpi,

    output reg  [7:0]  mux_byte_o,
    output reg         mux_is_k_o
);

    localparam [7:0] K28_5_BYTE = 8'hBC;

    // ========================================================================
    // 1. Synchronous Video Payload Capture (27 MHz Domain)
    //    Also toggles once per clk_27m cycle -- used to deterministically
    //    re-align the 81 MHz mux phase below instead of letting it free-run.
    // ========================================================================
    reg [7:0] reg_byte0;
    reg [7:0] reg_byte1;
    reg       byte_toggle_27m;

    always @(posedge clk_27m or negedge tx_reset_n) begin
        if (!tx_reset_n) begin
            reg_byte0       <= 8'h00;
            reg_byte1       <= 8'h00;
            byte_toggle_27m <= 1'b0;
        end else begin
            reg_byte0       <= dec_data;
            reg_byte1       <= {2'b00, local_gpi, dec_vsync, dec_hsync};
            byte_toggle_27m <= ~byte_toggle_27m;
        end
    end

    // ========================================================================
    // 2. Bring the 27 MHz toggle into the 81 MHz domain (2-flop synchronizer,
    //    safe here because these are related/derived PLL clocks, not
    //    independent async domains), then edge-detect it into a one-cycle
    //    "byte_load" pulse with guaranteed setup margin.
    // ========================================================================
    reg [2:0] toggle_sync_81m;

    always @(posedge clk_81m or negedge tx_reset_n) begin
        if (!tx_reset_n)
            toggle_sync_81m <= 3'b000;
        else
            toggle_sync_81m <= {toggle_sync_81m[1:0], byte_toggle_27m};
    end

    wire byte_load = toggle_sync_81m[2] ^ toggle_sync_81m[1];

    // ========================================================================
    // 3. 81 MHz Mux -- re-armed by byte_load every clk_27m cycle instead of
    //    free-running from an arbitrary reset-release phase.
    // ========================================================================
    reg [1:0] mux_count;

    always @(posedge clk_81m or negedge tx_reset_n) begin
        if (!tx_reset_n) begin
            mux_count  <= 2'b00;
            mux_byte_o <= 8'h00;
            mux_is_k_o <= 1'b0;
        end else begin
            if (byte_load)
                mux_count <= 2'b00;
            else if (mux_count >= 2'b10)
                mux_count <= 2'b00;
            else
                mux_count <= mux_count + 1'b1;

            case (mux_count)
                2'b00: begin mux_byte_o <= reg_byte0;   mux_is_k_o <= 1'b0; end
                2'b01: begin mux_byte_o <= reg_byte1;   mux_is_k_o <= 1'b0; end
                2'b10: begin mux_byte_o <= K28_5_BYTE;  mux_is_k_o <= 1'b1; end
                default: begin mux_byte_o <= K28_5_BYTE; mux_is_k_o <= 1'b1; end
            endcase
        end
    end

endmodule
