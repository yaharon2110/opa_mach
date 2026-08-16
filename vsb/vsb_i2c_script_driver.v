// ============================================================================
// Module Name:  vsb_i2c_script_driver
// Description:  Sequences Lattice EFB I2C Master registers via Wishbone to
//               automatically initialize 4 registers on the ADV7182A decoder.
//               Monitors for NACK errors and verifies final read data.
// ============================================================================

`timescale 1ns / 1ps

module vsb_i2c_script_driver (
    input  wire        clk_53m,          // Connected to internal_osc_clk (53.20 MHz)
    input  wire        reset_n,          // Connected to global hw_reset_n
    
    // Hard Silicon EFB Wishbone Interface Connections
    output reg         wb_cyc,
    output reg         wb_stb,
    output reg         wb_we,
    output reg  [7:0]  wb_adr,
    output reg  [7:0]  wb_dat_w,
    input  wire [7:0]  wb_dat_r,
    input  wire        wb_ack,
     
    // Status Indication Output Pin
    output reg         i2c_init_done
);

    // ========================================================================
    // 1. Lattice EFB Internal Wishbone Register Definitions
    // ========================================================================
    localparam [7:0]
        REG_I2C_TXDR = 8'h40,   // Transmit Data Register (Write Only)
        REG_I2C_RXDR = 8'h41,   // Receive Data Register (Read Only)
        REG_I2C_CR   = 8'h42,   // Command Register (Write Only)
        REG_I2C_SR   = 8'h43;   // Status Register (Read Only)

    // Lattice Hard EFB Command Bit Definitions
    localparam [7:0]
        CMD_STA_TX   = 8'h94,   // Generate START condition + Transmit byte
        CMD_TX       = 8'h14,   // Transmit data byte smoothly
        CMD_STO_TX   = 8'h54,   // Transmit data byte + Generate STOP condition
        CMD_RD_NACK  = 8'h24,   // Read data byte + Generate NACK (Final read step)
        CMD_STO      = 8'h44;   // Generate standalone STOP condition

    // ========================================================================
    // 2. Sequencer State Machine Map
    // ========================================================================
    localparam [4:0]
        ST_BOOT_WARMUP = 5'd0,
        ST_SET_ADDR    = 5'd1,
        ST_WAIT_ACK    = 5'd2,
        ST_SEND_CMD    = 5'd3,
        ST_WAIT_CMD_ACK= 5'd4,
        ST_POLL_SR_EN  = 5'd5,
        ST_POLL_SR_WAIT= 5'd6,
        ST_POLL_SR_EVAL= 5'd7,
        ST_DELAY_1MS   = 5'd8,
        ST_FETCH_DATA  = 5'd9,
        ST_FETCH_WAIT  = 5'd10,
        ST_EVAL_READ   = 5'd11,
        ST_SUCCESS     = 5'd12,
        ST_ERROR       = 5'd13;

    reg [4:0]  state;
    reg [23:0] timer_counter;
    reg [4:0]  script_index;
    reg [7:0]  payload_byte;
    reg [7:0]  command_byte;
    reg [7:0]  sr_latch;
    reg [7:0]  read_data_byte;

    // ========================================================================
    // 3. ADV7182A Step-by-Step Microcode Initialization Rom
    // ========================================================================
    always @(*) begin
        case (script_index)
            // Block 1: Write Reg 0x0F -> 0x00
            5'd0:  begin payload_byte = 8'h40; command_byte = CMD_STA_TX;  end // Device Addr Write (0x40)
            5'd1:  begin payload_byte = 8'h0F; command_byte = CMD_TX;      end // Target Reg
            5'd2:  begin payload_byte = 8'h00; command_byte = CMD_STO_TX;  end // Data Value

            // Block 2: Write Reg 0x1D -> 0x40
            5'd3:  begin payload_byte = 8'h40; command_byte = CMD_STA_TX;  end 
            5'd4:  begin payload_byte = 8'h1D; command_byte = CMD_TX;      end 
            5'd5:  begin payload_byte = 8'h40; command_byte = CMD_STO_TX;  end 

            // Block 3: Write Reg 0x00 -> 0x00
            5'd6:  begin payload_byte = 8'h40; command_byte = CMD_STA_TX;  end 
            5'd7:  begin payload_byte = 8'h00; command_byte = CMD_TX;      end 
            5'd8:  begin payload_byte = 8'h00; command_byte = CMD_STO_TX;  end 

            // Block 4: Write Reg 0x03 -> 0x0C
            5'd9:  begin payload_byte = 8'h40; command_byte = CMD_STA_TX;  end 
            5'd10: begin payload_byte = 8'h03; command_byte = CMD_TX;      end 
            5'd11: begin payload_byte = 8'h0C; command_byte = CMD_STO_TX;  end 

            // Block 5: Diagnostic Verification Read Phase from Reg 0x03
            5'd12: begin payload_byte = 8'h40; command_byte = CMD_STA_TX;  end // Send Device Addr Write
            5'd13: begin payload_byte = 8'h03; command_byte = CMD_STO_TX;  end // Send Reg Pointer + STOP
            5'd14: begin payload_byte = 8'h41; command_byte = CMD_STA_TX;  end // Restart Device Addr Read (0x41)
            5'd15: begin payload_byte = 8'h00; command_byte = CMD_RD_NACK;  end // Read Data (NACK to terminate)
            default: begin payload_byte = 8'h00; command_byte = CMD_STO;   end
        endcase
    end

    // ========================================================================
    // 4. Sequential Wishbone Execution Control Engine
    // ========================================================================
    always @(posedge clk_53m or negedge reset_n) begin
        if (!reset_n) begin
            state             <= ST_BOOT_WARMUP;
            timer_counter     <= 24'd0;
            script_index      <= 5'd0;
            wb_cyc            <= 1'b0;
            wb_stb            <= 1'b0;
            wb_we             <= 1'b0;
            wb_adr            <= 8'h0;
            wb_dat_w          <= 8'h0;
            sr_latch          <= 8'h0;
            read_data_byte    <= 8'h0;
            i2c_init_done     <= 1'b0;
        end else begin
            case (state)

                // 10ms Cold-Boot Warmup Delay (53.20 MHz * 10ms = 532,000 clock cycles)
                ST_BOOT_WARMUP: begin
                    i2c_init_done <= 1'b0;
                    script_index  <= 5'd0;
                    if (timer_counter >= 24'd532000) begin
                        timer_counter <= 24'd0;
                        state         <= ST_SET_ADDR;
                    end else begin
                        timer_counter <= timer_counter + 1'b1;
                    end
                end

                // Wishbone Step 1: Write Byte Payload to the EFB Transmit Register
                ST_SET_ADDR: begin
                    wb_cyc   <= 1'b1;
                    wb_stb   <= 1'b1;
                    wb_we    <= 1'b1;
                    wb_adr   <= REG_I2C_TXDR;
                    wb_dat_w <= payload_byte;
                    state    <= ST_WAIT_ACK;
                end

                // Wait for the internal hard EFB to acknowledge Wishbone data latch
                ST_WAIT_ACK: begin
                    if (wb_ack) begin
                        wb_cyc <= 1'b0;
                        wb_stb <= 1'b0;
                        wb_we  <= 1'b0;
                        state  <= ST_SEND_CMD;
                    end
                end

                // Wishbone Step 2: Write I2C Execution Action Code to Command Register
                ST_SEND_CMD: begin
                    wb_cyc   <= 1'b1;
                    wb_stb   <= 1'b1;
                    wb_we    <= 1'b1;
                    wb_adr   <= REG_I2C_CR;
                    wb_dat_w <= command_byte;
                    state    <= ST_WAIT_CMD_ACK;
                end

                ST_WAIT_CMD_ACK: begin
                    if (wb_ack) begin
                        wb_cyc <= 1'b0;
                        wb_stb <= 1'b0;
                        wb_we  <= 1'b0;
                        state  <= ST_POLL_SR_EN;
                    end
                end

                // Wishbone Step 3: Poll the Silicon EFB Status Register to watch execution
                ST_POLL_SR_EN: begin
                    wb_cyc <= 1'b1;
                    wb_stb <= 1'b1;
                    wb_we  <= 1'b0; // Read op
                    wb_adr <= REG_I2C_SR;
                    state  <= ST_POLL_SR_WAIT;
                end

                ST_POLL_SR_WAIT: begin
                    if (wb_ack) begin
                        sr_latch <= wb_dat_r; // Latch EFB real-time flag bits
                        wb_cyc   <= 1'b0;
                        wb_stb   <= 1'b0;
                        state    <= ST_POLL_SR_EVAL;
                    end
                end

                // Evaluate status register bits safely
                ST_POLL_SR_EVAL: begin
                    // Bit 1 = TIP (Transfer In Progress). We stay here while TIP == 1.
                    if (sr_latch[1] == 1'b1) begin
                        state <= ST_POLL_SR_EN; // Keep polling until data is fully serialized
                    end else begin
                        // Bit 4 = NoACK (Captured NACK error from line). If 1, slave failed to answer.
                        if (sr_latch[4] == 1'b1) begin
                            state <= ST_ERROR;
                        end else begin
                            script_index <= script_index + 1'b1;
                            
                            // Route sequencer pointer to its next task segment
                            if (script_index == 5'd2 || script_index == 5'd5 || script_index == 5'd8 || script_index == 5'd11) begin
                                state <= ST_DELAY_1MS; // Safe space delay between complete register writes
                            end else if (script_index == 5'd13) begin
                                state <= ST_DELAY_1MS; // Delay between register pointer write and the read restart
                            end else if (script_index == 5'd15) begin
                                state <= ST_FETCH_DATA; // I2C hardware read finished; go grab it out of the FIFO buffer
							end else begin
								state <= ST_SET_ADDR;   // Keep pushing data inside the current multi-byte sequence
							end
						end
					end
				end
							
				// Mandatory 1ms Inter-Write Delay (53.20 MHz * 1ms = 53,200 clock cycles)
				ST_DELAY_1MS: begin
					if (timer_counter >= 24'd53200) begin
						timer_counter <= 24'd0;
							state         <= ST_SET_ADDR;
					end else begin
						timer_counter <= timer_counter + 1'b1;
					end
				end
				
				// Wishbone Step 4: Extract the received hardware byte out of the EFB
				ST_FETCH_DATA: begin
					wb_cyc <= 1'b1;
					wb_stb <= 1'b1;
					wb_we  <= 1'b0;
					wb_adr <= REG_I2C_RXDR; // Read from internal Receive Register
					state  <= ST_FETCH_WAIT;
				end
				
				ST_FETCH_WAIT: begin
					if (wb_ack) begin
						read_data_byte <= wb_dat_r; // Latch raw returned register metrics
						wb_cyc         <= 1'b0;
						wb_stb         <= 1'b0;
						state          <= ST_EVAL_READ;
					end
				end
				
				// Data Verification Engine Point
				ST_EVAL_READ: begin
					if (read_data_byte == 8'h0C) begin
						state <= ST_SUCCESS; // Exact value matches setup requirements
					end else begin
						state <= ST_ERROR;   // Wrong data byte came back, trigger a reset cycle
					end
				end
				
				// Safe Lock State
				ST_SUCCESS: begin
					i2c_init_done <= 1'b1;   // Keep success status locked high permanently
					state         <= ST_SUCCESS;
				end
				
				// Fault Fallback Cycle Re-Sync
				ST_ERROR: begin
					i2c_init_done <= 1'b0;   // Drop success status low instantly
					timer_counter <= 24'd0;
					state         <= ST_BOOT_WARMUP; // Auto-trigger safe loop reboot sequence
				end
					
				default: state <= ST_BOOT_WARMUP;
			endcase
		end
	end
endmodule	
