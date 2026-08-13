// ============================================================================
// Module Name:  board_status_led
// Description:  Consolidates clock locks, firmware init status, and link health 
//               into a single diagnostic multi-state LED driver.
// ============================================================================

module board_status_led (
    input  wire        clk_54m,          // Primary 54 MHz processing clock
    input  wire        reset_n,          // System infrastructure master reset
    
    // Diagnostic Status Input Links
    input  wire        pll_locked,       // Asserted when hardware PLLs are stable
    input  wire        i2c_init_done,    // High if MCU sequence completed successfully
    input  wire        uplink_error,     // Tracks uplink `decode_error` fault flags
    input  wire        downlink_stable,  // Driven by `link_stable` from link monitor
    
    // Physical Output Drive Pin
    output reg         status_led        // Maps directly to the board indicator LED
);

    // --- Timebase Counter Traces ---
    // At 54 MHz, a 26-bit counter handles up to ~1.24 second rollover windows
    reg [25:0] clk_divider;
    
    // Extract distinct clock bit edges to form precise flashing time slots
    // Bit 25 toggles at ~0.80 Hz (Close approximation for standard 0.5Hz visual feedback)
    // Bit 23 toggles at ~3.21 Hz (Close approximation for rapid 2Hz hunting warning)
    wire slow_pulse = clk_divider[25];
    wire fast_pulse = clk_divider[23];

    // ------------------------------------------------------------------------
    // Step 1: Continuous Clock Frequency Divider Tree
    // ------------------------------------------------------------------------
    always @(posedge clk_54m or negedge reset_n) begin
        if (!reset_n) begin
            clk_divider <= 26'h0000000;
        end else begin
            clk_divider <= clk_divider + 1'b1;
        end
    end

    // ------------------------------------------------------------------------
    // Step 2: Multi-State Priority Diagnostic Control Encoder
    // ------------------------------------------------------------------------
    always @(*) begin
        if (!pll_locked || !i2c_init_done) begin
            // Condition 1: Off (Critical Core Initialization Failure)
            status_led = 1'b0;
        end 
        else if (uplink_error) begin
            // Condition 2: Slow 0.5 Hz Flashing (Uplink Pipeline Fault)
            status_led = slow_pulse;
        end 
        else if (!downlink_stable) begin
            // Condition 3: Rapid 2 Hz Flashing (Downlink Searching/No Lock)
            status_led = fast_pulse;
        end 
        else begin
            // Condition 4: Solid On (All Paths Verified Operational)
            status_led = 1'b1;
        end
    end

endmodule
