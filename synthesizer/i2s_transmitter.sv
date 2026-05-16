// =============================================================================
//  i2s_transmitter.sv  —  FIXED
//
//  FIX 1 (Bug 1): BCLK_DIV corrected for 12.288 MHz input clock.
//    - Old code had BCLK_DIV=16 with a comment saying "50 MHz / 32 = 1.5625 MHz".
//    - synthesizer_sound_interface now feeds aud_xck (12.288 MHz) to this module.
//    - Required BCLK = 3.072 MHz  (= 48 kHz × 32 bits × 2 edges)
//    - BCLK_DIV = 12.288 MHz / (3.072 MHz × 2) = 2
//      → counter reloads every 2 cycles, toggles BCLK each reload → 3.072 MHz. ✓
//
//  FIX 2 (Bug 2): shift_reg read index corrected from [30] → [31].
//    - After the shift ({shift_reg[30:0], 1'b0}), the next bit to send is the
//      NEW bit[31] (which was the old bit[30]).  Reading [30] before the shift
//      was one position behind, corrupting every frame.
//
//  Everything else (port names, FSM structure, LRCLK polarity) is unchanged.
// =============================================================================

module i2s_transmitter (
    input  logic clk_50mhz,          // NOTE: actually receives 12.288 MHz from audio_pll
    input  logic rst,

    input  logic signed [15:0] sample_in,

    output logic aud_bclk,
    output logic aud_daclrck,
    output logic aud_dacdat
);

    // -------------------------------------------------------------------------
    //  BCLK generation
    //  Input clock : 12.288 MHz  (aud_xck from PLL)
    //  Target BCLK : 3.072 MHz   (= 48 kHz × 32 bits × 2 edges)
    //  BCLK_DIV    : 12_288_000 / (3_072_000 × 2) = 2
    // -------------------------------------------------------------------------
    localparam int BCLK_DIV = 2;   // FIX 1: was 16 (designed for 50 MHz)

    logic [$clog2(BCLK_DIV)-1:0] bclk_cnt;
    logic bclk_tick;

    always_ff @(posedge clk_50mhz or posedge rst) begin
        if (rst) begin
            bclk_cnt  <= 0;
            bclk_tick <= 0;
            aud_bclk  <= 0;
        end else begin
            if (bclk_cnt == BCLK_DIV - 1) begin
                bclk_cnt  <= 0;
                aud_bclk  <= ~aud_bclk;
                bclk_tick <= 1;
            end else begin
                bclk_cnt  <= bclk_cnt + 1;
                bclk_tick <= 0;
            end
        end
    end

    // -------------------------------------------------------------------------
    //  I2S serial shift-out
    //  32 BCLK cycles per frame: bits [31:16] = Left channel, [15:0] = Right.
    //  Data is clocked out on BCLK falling edges (bclk_tick fires when BCLK
    //  just went high, so the next edge is the falling edge the codec samples).
    // -------------------------------------------------------------------------
    logic [5:0]       bit_cnt;
    logic signed [15:0] sample_latched;
    logic [31:0]      shift_reg;

   always_ff @(posedge clk_50mhz or posedge rst) begin
        if (rst) begin
            bit_cnt        <= 0;
            aud_daclrck    <= 0;
            aud_dacdat     <= 0;
            sample_latched <= 0;
            shift_reg      <= 0;
        end else begin
            if (bclk_tick && aud_bclk == 1'b1) begin

                if (bit_cnt == 0) begin
                    // TEST SİNYALİNİ ÇIKARDIK, GERÇEK SESİ (sample_in) BAĞLADIK:
                    sample_latched <= sample_in;
                    shift_reg      <= {sample_in, sample_in};   // [31:16]=L, [15:0]=R

                    aud_daclrck    <= 1'b0;              
                    aud_dacdat     <= sample_in[15];     // MSB of left channel

                    bit_cnt        <= bit_cnt + 1;
                end else begin
                    shift_reg   <= {shift_reg[30:0], 1'b0};
                    aud_dacdat  <= shift_reg[31];       

                    if (bit_cnt == 16)
                        aud_daclrck <= 1'b1;             

                    if (bit_cnt == 31)
                        bit_cnt <= 0;
                    else
                        bit_cnt <= bit_cnt + 1;
                end
            end
        end
    end

endmodule