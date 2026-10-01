// ============================================================================
// Module Name:  tx_elastic_fifo
// Description:  Generic asynchronous (dual-clock) FIFO, standard Gray-code
//               pointer design (Cummings, "Simulation and Synthesis
//               Techniques for Asynchronous FIFO Design"). Introduced for
//               the S-9 remediation to bridge the clk_27m (video-capture,
//               genlock-tracked) domain to the clk_81m (independent-
//               oscillator, serializing) domain inside tx_payload_mux.v --
//               these are now genuinely independent clocks, not PLL-related.
//
//               Gray-coded pointers are used because they guarantee only a
//               single bit changes between any two consecutive pointer
//               values. A multi-bit binary counter crossing a clock domain
//               through ordinary 2-flop synchronizers can be sampled
//               mid-transition with several bits changing at once,
//               producing a wildly wrong value; a Gray-coded value sampled
//               mid-transition resolves to either the old or the new
//               (adjacent) value, which is always safe for a pointer
//               comparison.
//
//               Memory technology note (corrects the earlier S-9 plan of
//               "distributed RAM, not EBR"): at DEPTH=128, DATA_WIDTH=16
//               (2048 bits), a register-based (flip-flop) implementation
//               would need 2048 registers -- more than this device's
//               entire register budget (1583). This depth is genuinely
//               required (see VSB Code Review.md S-9 Addendum -- the FIFO
//               has to absorb close to a full video line's worth of
//               worst-case drift before a blanking-confined correction can
//               run). The memory array below is written in the standard
//               inferable dual-clock pseudo-dual-port pattern and is
//               expected to synthesize into a single Block RAM (EBR)
//               primitive -- cheap at this size (fits well inside one
//               ~9Kbit block) -- rather than forced into distributed/LUT
//               RAM. Verify the actual Map/PAR report at Task 3 to confirm.
//
//               Read port is SYNCHRONOUS/registered (not combinational
//               first-word-fall-through) -- this is the natural, reliably
//               inferable style for Block RAM on this device family. The
//               1-cycle read latency this introduces is accounted for by
//               the caller (tx_payload_mux.v), which prefetches ahead of
//               need rather than reading immediately after asserting rd_en.
// Standards:    Verilog-2001 Standard Baseline
// ============================================================================

`timescale 1ns / 1ps

module tx_elastic_fifo #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 7          // depth = 2**ADDR_WIDTH (128 entries)
)(
    // ---------------- Write domain (clk_27m / video_reset_n) ----------------
    input  wire                    wr_clk,
    input  wire                    wr_rst_n,
    input  wire                    wr_en,
    input  wire [DATA_WIDTH-1:0]   wr_data,
    output wire                    wr_full,
    output wire [ADDR_WIDTH:0]     wr_fill_level,   // write-domain's view, 0..2**ADDR_WIDTH

    // ---------------- Read domain (clk_81m / tx_reset_n) ----------------
    input  wire                    rd_clk,
    input  wire                    rd_rst_n,
    input  wire                    rd_en,
    output reg  [DATA_WIDTH-1:0]   rd_data,
    output wire                    rd_empty,
    output wire [ADDR_WIDTH:0]     rd_fill_level    // read-domain's view, 0..2**ADDR_WIDTH
);

    localparam DEPTH = (1 << ADDR_WIDTH);

    // ========================================================================
    // Memory Array -- standard inferable dual-clock pseudo-dual-port pattern.
    // ========================================================================
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // ========================================================================
    // Write-Domain Pointer (binary + Gray), (ADDR_WIDTH+1)-bit so the extra
    // MSB disambiguates full vs. empty when the lower bits match (Cummings).
    // ========================================================================
    reg  [ADDR_WIDTH:0] wr_ptr_bin;
    reg  [ADDR_WIDTH:0] wr_ptr_gray;
    wire                 wr_will_advance = wr_en && !wr_full;
    wire [ADDR_WIDTH:0] wr_ptr_bin_next  = wr_ptr_bin + (wr_will_advance ? 1'b1 : 1'b0);
    wire [ADDR_WIDTH:0] wr_ptr_gray_next = (wr_ptr_bin_next >> 1) ^ wr_ptr_bin_next;

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin  <= {(ADDR_WIDTH+1){1'b0}};
            wr_ptr_gray <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;
        end
    end

    // Memory write. Silently ignored if wr_full -- a hard, unconditional
    // overflow safety net underneath whatever write-side policy the caller
    // implements (tx_payload_mux.v's blanking-confined soft-threshold drop);
    // this should never actually be exercised in a correctly margined design.
    always @(posedge wr_clk) begin
        if (wr_will_advance) begin
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
        end
    end

    // ========================================================================
    // Read-Domain Pointer (binary + Gray)
    // ========================================================================
    reg  [ADDR_WIDTH:0] rd_ptr_bin;
    reg  [ADDR_WIDTH:0] rd_ptr_gray;
    wire                 rd_will_advance = rd_en && !rd_empty;
    wire [ADDR_WIDTH:0] rd_ptr_bin_next  = rd_ptr_bin + (rd_will_advance ? 1'b1 : 1'b0);
    wire [ADDR_WIDTH:0] rd_ptr_gray_next = (rd_ptr_bin_next >> 1) ^ rd_ptr_bin_next;

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin  <= {(ADDR_WIDTH+1){1'b0}};
            rd_ptr_gray <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            rd_ptr_bin  <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;
        end
    end

    // Memory read -- registered (synchronous), 1-cycle latency from rd_en to
    // rd_data valid. See header note: the caller accounts for this latency
    // by prefetching ahead of need rather than reading immediately after
    // asserting rd_en.
    always @(posedge rd_clk) begin
        if (rd_will_advance) begin
            rd_data <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
        end
    end

    // ========================================================================
    // Cross-Domain Pointer Synchronizers (2-flop each, Gray-coded)
    // ========================================================================
    reg [ADDR_WIDTH:0] wr_ptr_gray_sync1, wr_ptr_gray_sync2; // write ptr, synced into READ domain
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_ptr_gray_sync1 <= {(ADDR_WIDTH+1){1'b0}};
            wr_ptr_gray_sync2 <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            wr_ptr_gray_sync1 <= wr_ptr_gray;
            wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
        end
    end

    reg [ADDR_WIDTH:0] rd_ptr_gray_sync1, rd_ptr_gray_sync2; // read ptr, synced into WRITE domain
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_ptr_gray_sync1 <= {(ADDR_WIDTH+1){1'b0}};
            rd_ptr_gray_sync2 <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            rd_ptr_gray_sync1 <= rd_ptr_gray;
            rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
        end
    end

    // ========================================================================
    // Empty / Full Flags -- standard Cummings Gray-code comparisons. These
    // compare Gray codes DIRECTLY and never need binary conversion, which is
    // what makes them CDC-safe.
    // ========================================================================
    // Empty: read pointer has caught up exactly to the synchronized
    // (possibly one-or-two-cycle-stale) write pointer.
    assign rd_empty = (rd_ptr_gray == wr_ptr_gray_sync2);

    // Full: write pointer's Gray code equals the synchronized read pointer's
    // Gray code with the two MSBs inverted (the wrap-around case).
    assign wr_full = (wr_ptr_gray == {~rd_ptr_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1],
                                        rd_ptr_gray_sync2[ADDR_WIDTH-2:0]});

    // ========================================================================
    // Gray-to-Binary Conversion -- needed only for the fill-level arithmetic
    // below. Full/empty detection above uses Gray codes directly and never
    // calls this.
    // ========================================================================
    function [ADDR_WIDTH:0] gray2bin;
        input [ADDR_WIDTH:0] g;
        integer i;
        begin
            gray2bin[ADDR_WIDTH] = g[ADDR_WIDTH];
            for (i = ADDR_WIDTH - 1; i >= 0; i = i - 1) begin
                gray2bin[i] = gray2bin[i+1] ^ g[i];
            end
        end
    endfunction

    // Write-domain's view of fill level: its own (live) pointer minus the
    // synchronized (slightly stale) read pointer. The staleness biases this
    // view to be >= the true fill level -- the safe direction for an
    // overflow-avoidance decision (it never under-estimates how full the
    // FIFO really is).
    assign wr_fill_level = wr_ptr_bin - gray2bin(rd_ptr_gray_sync2);

    // Read-domain's view of fill level: the synchronized (slightly stale)
    // write pointer minus its own (live) pointer. The staleness biases this
    // view to be <= the true fill level -- the safe direction for an
    // underflow-avoidance decision (it never over-estimates how much data
    // is really available).
    assign rd_fill_level = gray2bin(wr_ptr_gray_sync2) - rd_ptr_bin;

endmodule
