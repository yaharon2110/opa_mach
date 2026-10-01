// ============================================================================
// Module Name:  board_status_led
// Description:  Consolidates clock locks, firmware init status, and link health
//               into a single diagnostic multi-state LED driver.
//
// Revision (S-9 remediation, 2026-10-01): priority order changed so that
// uplink_error is checked FIRST, ahead of the I2C/PLL conditions. The
// original order (!pll_locked || !i2c_init_done -> off, checked first)
// could mask a genuine uplink fault behind an unrelated downlink/I2C
// condition -- the LED would simply go off, discarding the uplink_error
// information entirely. Since VSB's uplink RX path is already independent
// of the downlink/I2C logic (see VSB Code Review.md, Task 2 notes on
// uplink_rx.v needing no S-9 changes), it is reasonable for its fault
// status to take priority in the display.
//
// Decided priority (Yossi, 2026-10-01) -- single LED, 4 states, 3 health
// axes (I2C init / downlink PLL+stability / uplink). A single monochrome
// LED cannot fully and independently represent 3 independent axes with
// only 4 states (8 possible combinations vs. 4 states) -- this is an
// accepted, understood limitation (option 3 of 3 considered; see VSB Code
// Review.md), not an oversight:
//   1. uplink_error                    -> SLOW FLASH (checked first)
//   2. !i2c_init_done                  -> OFF
//   3. !pll_locked || !downlink_stable -> FAST FLASH
//   4. else                            -> SOLID ON
// Known accepted limitation: if I2C fails (state 2) while the uplink is
// genuinely healthy but has never asserted an error, the LED shows OFF
// rather than a distinct "uplink confirmed good" indication. A true
// independent-per-axis indicator would need a second LED (Bank0 pin C8
// was identified as available for this, if ever revisited) or a
// time-multiplexed blink sequence -- deliberately not pursued now.
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
    //
    // Priority order (S-9 remediation, 2026-10-01): uplink_error is now
    // checked FIRST, ahead of i2c_init_done/pll_locked -- see header note.
    // ------------------------------------------------------------------------
    always @(*) begin
        if (uplink_error) begin
            // Condition 1: Slow 0.5 Hz Flashing (Uplink Pipeline Fault) --
            // checked first so a downlink/I2C condition never hides a real
            // uplink fault.
            status_led = slow_pulse;
        end
        else if (!i2c_init_done) begin
            // Condition 2: Off (I2C/MCU Init Not Complete)
            status_led = 1'b0;
        end
        else if (!pll_locked || !downlink_stable) begin
            // Condition 3: Rapid 2 Hz Flashing (Downlink PLL Unlocked or
            // Link Not Yet Stable)
            status_led = fast_pulse;
        end
        else begin
            // Condition 4: Solid On (All Paths Verified Operational)
            status_led = 1'b1;
        end
    end

endmodule
