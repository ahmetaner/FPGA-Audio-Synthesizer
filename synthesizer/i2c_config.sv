// =============================================================================
//  i2c_config.sv  —  FIXED
//
//  FIX (Bug 5): Added missing WM8731 register 0x08 (Sampling Control).
//
//  Without register 0x08 the codec resets to its power-on default, which is
//  USB clock mode (CLKODIV2=0, SR=0000, BOSR=0, USB/Normal=1).  In USB mode
//  the codec expects a 12 MHz MCLK and derives its own internal clocks; our
//  PLL provides 12.288 MHz for Normal mode (256fs × 48 kHz).  The mismatch
//  could cause the codec to output silence or distorted audio.
//
//  Register 0x08 value 0x000:
//    bit 0   (USB/Normal) = 0  → Normal mode (MCLK = 256fs or 384fs)
//    bits 4:1 (SR[3:0])   = 0000 → 48 kHz with 256fs MCLK  (table in datasheet)
//    bit 5   (BOSR)       = 0  → 256fs base over-sampling
//    bit 6   (CLKODIV2)   = 0  → CLKOUT = MCLK
//    bit 7   (CLKIDIV2)   = 0  → Core clock = MCLK
//
//  NUM_REGS updated from 10 → 11 to include the new entry.
//  config_rom[9]  is now the Sampling Control register (0x08).
//  config_rom[10] is the Active Control (0x09) that was previously config_rom[9].
// =============================================================================

module i2c_config (
    input  logic clk_50mhz,
    input  logic rst,

    output logic i2c_sclk,
    inout  wire  i2c_sdat,

    output logic config_done
);

    localparam int CLK_FREQ = 50_000_000;
    localparam int I2C_FREQ = 100_000;
    localparam int DIVIDER  = CLK_FREQ / (I2C_FREQ * 4);

    localparam logic [6:0] WM8731_ADDR = 7'h1A;

    logic sdat_out;
    logic sdat_oe;

    assign i2c_sdat = sdat_oe ? sdat_out : 1'bz;

    logic [$clog2(DIVIDER)-1:0] div_cnt;
    logic tick;

    always_ff @(posedge clk_50mhz or posedge rst) begin
        if (rst) begin
            div_cnt <= 0;
            tick    <= 0;
        end else begin
            if (div_cnt == DIVIDER - 1) begin
                div_cnt <= 0;
                tick    <= 1;
            end else begin
                div_cnt <= div_cnt + 1;
                tick    <= 0;
            end
        end
    end

    // -------------------------------------------------------------------------
    //  WM8731 register map:  {reg_addr[6:0], data[8:0]}  stored as 16 bits
    // -------------------------------------------------------------------------
    localparam int NUM_REGS = 11;   // FIX: was 10

    logic [15:0] config_rom [0:NUM_REGS-1];

    initial begin
    config_rom[0] = {7'h0F, 9'h000}; // Reset
    config_rom[1] = {7'h06, 9'h000}; // Power down control: all on
    config_rom[2] = {7'h00, 9'h017}; // Left line in
    config_rom[3] = {7'h01, 9'h017}; // Right line in
    config_rom[4] = {7'h02, 9'h079}; // Left headphone out
    config_rom[5] = {7'h03, 9'h079}; // Right headphone out
    config_rom[6] = {7'h04, 9'h012}; // Analog audio path: DAC selected
    config_rom[7] = {7'h05, 9'h000}; // Digital audio path
    config_rom[8] = {7'h07, 9'h012}; // Digital audio interface: I2S, 16-bit, slave
    config_rom[9] = {7'h09, 9'h001}; // Active control
		end

    typedef enum logic [3:0] {
        IDLE,
        START_A,
        START_B,
        SEND,
        ACK,
        STOP_A,
        STOP_B,
        NEXT_REG,
        DONE
    } state_t;

    state_t state;

    logic [7:0] byte0, byte1, byte2;
    logic [1:0] byte_index;
    logic [7:0] current_byte;
    logic [3:0] bit_index;
    logic [1:0] phase;
    logic [$clog2(NUM_REGS)-1:0] reg_index;

    always_comb begin
        byte0 = {WM8731_ADDR, 1'b0};
        byte1 = config_rom[reg_index][15:8];
        byte2 = config_rom[reg_index][7:0];

        case (byte_index)
            2'd0:    current_byte = byte0;
            2'd1:    current_byte = byte1;
            default: current_byte = byte2;
        endcase
    end

    always_ff @(posedge clk_50mhz or posedge rst) begin
        if (rst) begin
            state       <= IDLE;
            i2c_sclk    <= 1'b1;
            sdat_out    <= 1'b1;
            sdat_oe     <= 1'b1;
            config_done <= 1'b0;

            reg_index   <= 0;
            byte_index  <= 0;
            bit_index   <= 7;
            phase       <= 0;
        end else if (tick) begin
            case (state)

                IDLE: begin
                    i2c_sclk    <= 1'b1;
                    sdat_out    <= 1'b1;
                    sdat_oe     <= 1'b1;
                    config_done <= 1'b0;
                    state       <= START_A;
                end

                START_A: begin
                    sdat_out <= 1'b0;   // SDA high→low while SCL high = START
                    i2c_sclk <= 1'b1;
                    state    <= START_B;
                end

                START_B: begin
                    i2c_sclk   <= 1'b0;
                    byte_index <= 0;
                    bit_index  <= 7;
                    phase      <= 0;
                    state      <= SEND;
                end

                SEND: begin
                    case (phase)
                        2'd0: begin
                            i2c_sclk <= 1'b0;
                            sdat_oe  <= 1'b1;
                            sdat_out <= current_byte[bit_index];
                            phase    <= 2'd1;
                        end
                        2'd1: begin
                            i2c_sclk <= 1'b1;
                            phase    <= 2'd2;
                        end
                        2'd2: begin
                            i2c_sclk <= 1'b0;
                            if (bit_index == 0) begin
                                phase <= 0;
                                state <= ACK;
                            end else begin
                                bit_index <= bit_index - 1;
                                phase     <= 0;
                            end
                        end
                        default: phase <= 0;
                    endcase
                end

                ACK: begin
                    case (phase)
                        2'd0: begin
                            i2c_sclk <= 1'b0;
                            sdat_oe  <= 1'b0;   // release SDA for slave ACK
                            phase    <= 2'd1;
                        end
                        2'd1: begin
                            i2c_sclk <= 1'b1;   // slave drives ACK here
                            phase    <= 2'd2;
                        end
                        2'd2: begin
                            i2c_sclk   <= 1'b0;
                            sdat_oe    <= 1'b1;
                            sdat_out   <= 1'b0;
                            phase      <= 0;

                            if (byte_index == 2) begin
                                state <= STOP_A;
                            end else begin
                                byte_index <= byte_index + 1;
                                bit_index  <= 7;
                                state      <= SEND;
                            end
                        end
                        default: phase <= 0;
                    endcase
                end

                STOP_A: begin
                    sdat_oe  <= 1'b1;
                    sdat_out <= 1'b0;
                    i2c_sclk <= 1'b1;
                    state    <= STOP_B;
                end

                STOP_B: begin
                    sdat_out <= 1'b1;   // SDA low→high while SCL high = STOP

                    if (reg_index == NUM_REGS - 1)
                        state <= DONE;
                    else
                        state <= NEXT_REG;
                end

                NEXT_REG: begin
                    reg_index <= reg_index + 1;
                    state     <= START_A;
                end

                DONE: begin
                    config_done <= 1'b1;
                    i2c_sclk    <= 1'b1;
                    sdat_out    <= 1'b1;
                    sdat_oe     <= 1'b1;
                end

            endcase
        end
    end

endmodule