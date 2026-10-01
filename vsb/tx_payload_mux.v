// ============================================================================
// Module Name:  tx_payload_mux
// Description:  Bridges the clk_27m (video-capture) domain to the clk_81m
//               (serializing) domain and arranges the payload into the
//               data1 / data2 / Idle(K28.5) framing cycle expected by the
//               far end (and by VDB's planned downlink RX demux).
//
// Revision (S-9 remediation, 2026-10-01): clk_27m and clk_81m are now
// genuinely independent clocks (clk_81m comes from the external oscillator,
// no longer the PLL -- see vsb_top.v). The previous implementation's 2-flop
// toggle synchronizer assumed a fixed, startup-coordinated phase
// relationship between the two clocks (safe only because both were
// PLL-derived) and is not sufficient for two truly asynchronous clocks that
// can drift relative to each other by up to +/-5% (see VSB Code Review.md,
// S-9 Addendum). It is replaced here with a real asynchronous elastic FIFO
// (tx_elastic_fifo.v) plus blanking-confined justification logic:
//   - WRITE side (this module, clk_27m / video_reset_n): captures one
//     video sample (pixel byte + control byte) every clk_27m cycle and
//     writes it into the FIFO. Unconditional except for a blanking-
//     confined overflow-avoidance drop (see below) -- active-video samples
//     are never dropped.
//   - READ side (this module, clk_81m / tx_reset_n): pulls samples from
//     the FIFO and arranges them into the mandatory data1/data2/Idle
//     framing. If the FIFO runs low (write side running slow relative to
//     nominal), the read side naturally stays in the Idle state longer,
//     inserting extra Idle symbols -- this requires no special-case logic,
//     it falls directly out of the state machine structure.
//
// IMPORTANT: this module's correctness depends on exact clock-edge timing
// across two always blocks (this module's FSM and tx_elastic_fifo.v's
// registered read port) -- the kind of logic that is very easy to get
// subtly wrong by inspection alone (a naive implementation would silently
// undershoot the required 27 MHz throughput by one cycle per group). This
// is the highest-priority candidate for the planned Icarus Verilog
// simulation, ahead of any other remaining S-9 file.
// Standards:    Verilog-2001 Standard Baseline
// ============================================================================

`timescale 1ns / 1ps

module tx_payload_mux (
    input  wire        clk_81m,
    input  wire        clk_27m,
    input  wire        tx_reset_n,      // Synchronized active-low reset, clk_81m domain
    input  wire        video_reset_n,   // Synchronized active-low reset, clk_27m domain

    input  wire [7:0]  dec_data,
    input  wire        dec_hsync,
    input  wire        dec_vsync,
    input  wire [3:0]  local_gpi,

    output reg  [7:0]  mux_byte_o,
    output reg         mux_is_k_o
);

    localparam [7:0] K28_5_BYTE  = 8'hBC;
    localparam       DATA_WIDTH  = 16;
    localparam       ADDR_WIDTH  = 7;      // FIFO depth = 128 entries -- see
                                            // tx_elastic_fifo.v header for why
                                            // this depth needs real memory
                                            // (EBR), not flip-flops.

    // ========================================================================
    // 1. Write Side (clk_27m / video_reset_n domain)
    // ========================================================================
    // Same payload field layout as the original design: byte0 = raw pixel
    // data, byte1 = packed control bits (local_gpi + vsync + hsync).
    wire [7:0] byte1_live = {2'b00, local_gpi, dec_vsync, dec_hsync};

    wire [ADDR_WIDTH:0] wr_fill_level;
    wire                 fifo_wr_full;

    // Preferred (blanking-confined) overflow avoidance: during horizontal
    // blanking (dec_hsync is the signal explicitly provided for this
    // purpose), skip writing this one sample into the FIFO if it has gotten
    // close to full. This sample is simply never transmitted -- safe only
    // because it is confined to blanking, where there is no visible video
    // content to lose. tx_elastic_fifo.v's own wr_full flag remains a hard,
    // unconditional safety net underneath this threshold in case it is ever
    // not low enough -- that should never actually fire in a correctly
    // margined design (see VSB Code Review.md, S-9 Addendum, for the sizing
    // reasoning behind the 128-entry depth this threshold is set against).
    localparam [ADDR_WIDTH:0] WR_ALMOST_FULL_THRESH =
        (1 << ADDR_WIDTH) - (1 << (ADDR_WIDTH - 2));   // 3/4 full = 96 of 128

    wire wr_almost_full = (wr_fill_level >= WR_ALMOST_FULL_THRESH);
    wire preferred_drop = dec_hsync && wr_almost_full;
    wire fifo_wr_en      = !preferred_drop;

    // ========================================================================
    // 2. Read Side (clk_81m / tx_reset_n domain) -- see wiring below
    // ========================================================================
    wire [DATA_WIDTH-1:0] fifo_rd_data;
    wire                   fifo_rd_empty;
    wire [ADDR_WIDTH:0]    rd_fill_level;   // available for future use/telemetry; not consumed by this FSM
    reg                    fifo_rd_en;

    tx_elastic_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_tx_elastic_fifo (
        .wr_clk        (clk_27m),
        .wr_rst_n      (video_reset_n),
        .wr_en         (fifo_wr_en),
        .wr_data       ({byte1_live, dec_data}),   // [15:8]=control (data2), [7:0]=pixel (data1)
        .wr_full       (fifo_wr_full),
        .wr_fill_level (wr_fill_level),

        .rd_clk        (clk_81m),
        .rd_rst_n      (tx_reset_n),
        .rd_en         (fifo_rd_en),
        .rd_data       (fifo_rd_data),
        .rd_empty      (fifo_rd_empty),
        .rd_fill_level (rd_fill_level)
    );

    // ========================================================================
    // 3. Read-Side Framing State Machine (clk_81m / tx_reset_n domain)
    // ========================================================================
    // States: S_IDLE emits Idle/K28.5 (and is where underflow naturally
    // shows up as simply staying here longer); S_DATA1/S_DATA2 emit the
    // popped sample's two bytes in sequence.
    localparam [1:0] S_IDLE  = 2'b00;
    localparam [1:0] S_DATA1 = 2'b01;
    localparam [1:0] S_DATA2 = 2'b10;

    reg [1:0]             mux_state;
    reg [DATA_WIDTH-1:0]  popped_data;
    reg                   pop_outstanding; // a pop has been issued and its
                                            // data hasn't been consumed yet
    reg                   data_ready;      // fifo_rd_en delayed by exactly
                                            // one clk_81m cycle -- the
                                            // correctly-timed signal for
                                            // "fifo_rd_data is now safely
                                            // valid to read from THIS always
                                            // block" (tx_elastic_fifo.v's
                                            // read port is registered, i.e.
                                            // one clk_81m cycle of latency
                                            // from rd_en to rd_data valid;
                                            // this register re-times that
                                            // latency for a cross-always-
                                            // block consumer).

    always @(posedge clk_81m or negedge tx_reset_n) begin
        if (!tx_reset_n)
            data_ready <= 1'b0;
        else
            data_ready <= fifo_rd_en;
    end

    always @(posedge clk_81m or negedge tx_reset_n) begin
        if (!tx_reset_n) begin
            mux_state       <= S_IDLE;
            fifo_rd_en      <= 1'b0;
            pop_outstanding <= 1'b0;
            popped_data     <= {DATA_WIDTH{1'b0}};
            mux_byte_o      <= 8'h00;
            mux_is_k_o      <= 1'b0;
        end else begin
            fifo_rd_en <= 1'b0;   // default every cycle; re-asserted explicitly below when needed

            case (mux_state)
                S_IDLE: begin
                    mux_byte_o <= K28_5_BYTE;
                    mux_is_k_o <= 1'b1;

                    if (pop_outstanding) begin
                        // A pop is already in flight -- either prefetched
                        // during the previous group's S_DATA1 (steady-state
                        // fast path, data_ready will already be true by the
                        // time we get here -- see S_DATA1 below), or issued
                        // directly from this state on an earlier cycle
                        // (cold start / recovering from an underflow stall).
                        if (data_ready) begin
                            popped_data     <= fifo_rd_data;
                            pop_outstanding <= 1'b0;
                            mux_state       <= S_DATA1;
                        end
                        // else: still waiting for data_ready -- stay here.
                    end else if (!fifo_rd_empty) begin
                        // No pop in flight (cold start, or recovering from
                        // an underflow stall where the FIFO just became
                        // non-empty again) -- issue one now.
                        fifo_rd_en      <= 1'b1;
                        pop_outstanding <= 1'b1;
                        // Stays in S_IDLE; data_ready will pulse true 1
                        // cycle from now and be checked above.
                    end
                    // else: FIFO empty and nothing in flight -- stay in
                    // S_IDLE, keep emitting Idle. This IS the underflow /
                    // "insert extra Idle" mechanism -- no further logic
                    // needed beyond simply not advancing.
                end

                S_DATA1: begin
                    mux_byte_o <= popped_data[7:0];
                    mux_is_k_o <= 1'b0;

                    // Steady-state fast path: prefetch the NEXT group's
                    // data now. It has exactly two full slot-intervals
                    // (this group's upcoming S_DATA2, then the mandatory
                    // S_IDLE slot) to become valid before S_IDLE's
                    // transition back to S_DATA1 needs it -- zero
                    // throughput penalty when data is continuously
                    // available.
                    if (!fifo_rd_empty) begin
                        fifo_rd_en      <= 1'b1;
                        pop_outstanding <= 1'b1;
                    end

                    mux_state <= S_DATA2;
                end

                S_DATA2: begin
                    mux_byte_o <= popped_data[15:8];
                    mux_is_k_o <= 1'b0;
                    mux_state  <= S_IDLE;
                end

                default: begin
                    mux_state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
