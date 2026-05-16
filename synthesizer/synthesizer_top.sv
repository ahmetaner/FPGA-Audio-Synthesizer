// =============================================================================
//  synthesizer_top.sv  —  DE1-SoC Polyphonic Synthesizer Top-Level Entity
//
//  Signal chain:
//    PS/2 Keyboard
//      → ps2_receiver          (raw 8-bit scan codes)
//      → scan_code_to_bus      (key_state_bus[11:0], waveform_select, soft_reset)
//      → voice_allocator       (4× FREQ[15:0] + GATE per voice)
//      → 4× voice_module       (oscillator + sine ROM → RAW_SOUND per voice)
//      → 4× adsr_envelope      (per-voice ADSR shaping)
//      → digital_mixer         (sum + attenuate → 16-bit MIXED_SOUND)
//      → iir_lowpass_filter    (anti-aliasing → FILTERED_SOUND)
//      → synthesizer_sound_interface
//            ├─ audio_pll      (50 MHz → 12.288 MHz MCLK)
//            ├─ i2c_config     (WM8731 register initialisation)
//            └─ i2s_transmitter(serial audio → AUD_BCLK/LRCLK/DACDAT)
//
//  Target device : Cyclone V  5CSEMA5F31C6  (DE1-SoC)
//  System clock  : 50 MHz (CLOCK_50)
//  Sample rate   : 48 kHz
// =============================================================================

module synthesizer_top (
    // ── Clocks ───────────────────────────────────────────────────────────────
    input  logic        CLOCK_50,

    // ── Reset: KEY[0] on DE1-SoC is active-low ───────────────────────────────
    input  logic        KEY0,

    // ── PS/2 Keyboard ────────────────────────────────────────────────────────
    input  logic        PS2_CLK,
    input  logic        PS2_DAT,

    // ── WM8731 Audio Codec ───────────────────────────────────────────────────
    output logic        AUD_XCK,      // 12.288 MHz MCLK (from PLL)
    output logic        AUD_BCLK,     // Bit clock  (~3.072 MHz derived in I2S TX)
    output logic        AUD_DACLRCK,  // LR clock   (48 kHz)
    output logic        AUD_DACDAT,   // Serial audio data

    // ── I2C for WM8731 configuration ─────────────────────────────────────────
    output logic        I2C_SCLK,
    inout  wire         I2C_SDAT,

    // ── Status LEDs (LEDR[3:0]) — one per active voice ───────────────────────
    output logic [3:0]  LEDR
);

    // =========================================================================
    //  0.  Reset
    //      KEY0 is active-low.  Stretch reset for 256 cycles so downstream
    //      registers see a clean pulse even if KEY0 bounces.
    // =========================================================================
    logic rst;
    logic [7:0] rst_cnt;

    always_ff @(posedge CLOCK_50) begin
        if (~KEY0) begin
            rst_cnt <= 8'hFF;
            rst     <= 1'b1;
        end else if (rst_cnt != '0) begin
            rst_cnt <= rst_cnt - 1'b1;
            rst     <= 1'b1;
        end else begin
            rst     <= 1'b0;
        end
    end

    // =========================================================================
    //  1.  Sample-rate timing:  48 kHz sample_enable  +  1 kHz age_enable
    // =========================================================================
    logic        sample_enable;
    logic        age_enable;
    logic [31:0] counter_dbg;

    counter_module #(
        .SYS_CLK_FREQ(50_000_000),
        .SAMPLE_RATE (48_000),
        .AGE_RATE    (1_000)
    ) u_counter (
        .clk          (CLOCK_50),
        .rst          (rst),
        .counter      (counter_dbg),
        .sample_enable(sample_enable),
        .age_enable   (age_enable)
    );

    // =========================================================================
    //  2.  PS/2 Keyboard Receiver
    // =========================================================================
    logic [7:0] rx_data;
    logic        rx_valid;

    ps2_receiver u_ps2 (
        .clk_50mhz(CLOCK_50),
        .reset    (rst),
        .ps2_clk  (PS2_CLK),
        .ps2_dat  (PS2_DAT),
        .rx_data  (rx_data),
        .rx_valid (rx_valid)
    );

    // =========================================================================
    //  3.  Scan-code → Key State Bus
    // =========================================================================
    logic [11:0] key_state_bus;
    logic [1:0]  waveform_select;
    logic        soft_reset;

    scan_code_to_bus u_scan (
        .clk_50mhz      (CLOCK_50),
        .reset          (rst | soft_reset),
        .rx_data        (rx_data),
        .rx_valid       (rx_valid),
        .key_state_bus  (key_state_bus),
        .waveform_select(waveform_select),
        .soft_reset     (soft_reset)
    );

    // =========================================================================
    //  4.  Voice Allocator  —  4-voice polyphony with note stealing & ageing
    // =========================================================================
    logic [15:0] freq_v1, freq_v2, freq_v3, freq_v4;
    logic        gate_v1, gate_v2, gate_v3, gate_v4;

    voice_allocator u_alloc (
        .CLK_50MHZ    (CLOCK_50),
        .RST          (rst),
        .BTN_STATE_BUS(key_state_bus),
        .AGE_ENABLE   (age_enable),
        .FREQ_V1(freq_v1), .FREQ_V2(freq_v2),
        .FREQ_V3(freq_v3), .FREQ_V4(freq_v4),
        .GATE_V1(gate_v1), .GATE_V2(gate_v2),
        .GATE_V3(gate_v3), .GATE_V4(gate_v4)
    );

    assign LEDR = {gate_v4, gate_v3, gate_v2, gate_v1};

    // =========================================================================
    //  5.  Voice Modules  —  oscillator + sine ROM, one per voice
    // =========================================================================
    logic signed [15:0] raw_v1, raw_v2, raw_v3, raw_v4;

    voice_module u_voice1 (
        .CLK_50MHZ    (CLOCK_50), .RST(rst),
        .SAMPLE_ENABLE(sample_enable),
        .FREQ_HZ      (freq_v1),  .WAVE_SEL(waveform_select),
        .RAW_SOUND    (raw_v1)
    );
    voice_module u_voice2 (
        .CLK_50MHZ    (CLOCK_50), .RST(rst),
        .SAMPLE_ENABLE(sample_enable),
        .FREQ_HZ      (freq_v2),  .WAVE_SEL(waveform_select),
        .RAW_SOUND    (raw_v2)
    );
    voice_module u_voice3 (
        .CLK_50MHZ    (CLOCK_50), .RST(rst),
        .SAMPLE_ENABLE(sample_enable),
        .FREQ_HZ      (freq_v3),  .WAVE_SEL(waveform_select),
        .RAW_SOUND    (raw_v3)
    );
    voice_module u_voice4 (
        .CLK_50MHZ    (CLOCK_50), .RST(rst),
        .SAMPLE_ENABLE(sample_enable),
        .FREQ_HZ      (freq_v4),  .WAVE_SEL(waveform_select),
        .RAW_SOUND    (raw_v4)
    );

    // =========================================================================
    //  6.  ADSR Envelopes  —  one instance per voice
    // =========================================================================
    logic signed [15:0] shaped_v1, shaped_v2, shaped_v3, shaped_v4;

    adsr_envelope u_adsr1 (
        .clk         (CLOCK_50), .rst(rst),
        .gate_v1     (gate_v1),
        .sample_enable(sample_enable),
        .mixed_sound (raw_v1),
        .shaped_sound(shaped_v1)
    );
    adsr_envelope u_adsr2 (
        .clk         (CLOCK_50), .rst(rst),
        .gate_v1     (gate_v2),
        .sample_enable(sample_enable),
        .mixed_sound (raw_v2),
        .shaped_sound(shaped_v2)
    );
    adsr_envelope u_adsr3 (
        .clk         (CLOCK_50), .rst(rst),
        .gate_v1     (gate_v3),
        .sample_enable(sample_enable),
        .mixed_sound (raw_v3),
        .shaped_sound(shaped_v3)
    );
    adsr_envelope u_adsr4 (
        .clk         (CLOCK_50), .rst(rst),
        .gate_v1     (gate_v4),
        .sample_enable(sample_enable),
        .mixed_sound (raw_v4),
        .shaped_sound(shaped_v4)
    );

    // =========================================================================
    //  7.  Digital Mixer
    // =========================================================================
    logic signed [15:0] mixed_sound;

    digital_mixer u_mixer (
        .CLK_50MHZ      (CLOCK_50),
        .RST            (rst),
        .SAMPLE_ENABLE  (sample_enable),
        .SHAPED_SOUND_V1(shaped_v1),
        .SHAPED_SOUND_V2(shaped_v2),
        .SHAPED_SOUND_V3(shaped_v3),
        .SHAPED_SOUND_V4(shaped_v4),
        .MIXED_SOUND    (mixed_sound)
    );

    // =========================================================================
    //  8.  IIR Low-Pass Filter
    // =========================================================================
    logic signed [15:0] filtered_sound;

    iir_lowpass_filter #(
        .ALPHA_SHIFT(4)
    ) u_lpf (
        .CLK_50MHZ     (CLOCK_50),
        .RST           (rst),
        .SAMPLE_ENABLE (sample_enable),
        .SHAPED_SOUND  (mixed_sound),
        .FILTERED_SOUND(filtered_sound)
    );

    // =========================================================================
    //  9.  Audio Interface  —  PLL + I2C config + I2S transmitter
    // =========================================================================
    synthesizer_sound_interface u_audio (
        .CLOCK_50      (CLOCK_50),
        .rst           (rst),
        .FILTERED_SOUND(filtered_sound),
        .I2C_SCLK      (I2C_SCLK),
        .I2C_SDAT      (I2C_SDAT),
        .AUD_XCK       (AUD_XCK),
        .AUD_BCLK      (AUD_BCLK),
        .AUD_DACLRCK   (AUD_DACLRCK),
        .AUD_DACDAT    (AUD_DACDAT)
    );

endmodule
