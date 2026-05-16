// =============================================================================
//  synthesizer_sound_interface.sv
//
//  Wraps the PLL, I2C codec configurator, and I2S transmitter.
//
//  FIX 1: i2s_transmitter is now clocked from aud_xck (12.288 MHz PLL output)
//          instead of CLOCK_50, so AUD_BCLK and AUD_XCK are in the same clock
//          domain and will never drift apart.
//
//  FIX 2: I2S transmitter reset is held until both the PLL is locked AND the
//          I2C configuration is complete, so the codec is ready before it
//          receives any audio data.
// =============================================================================
module synthesizer_sound_interface (
    input  logic CLOCK_50,
    input  logic rst,

    input  logic signed [15:0] FILTERED_SOUND,

    output logic I2C_SCLK,
    inout  wire  I2C_SDAT,

    output logic AUD_XCK,
    output logic AUD_BCLK,
    output logic AUD_DACLRCK,
    output logic AUD_DACDAT
);

    logic aud_xck;
    logic pll_locked;
    logic config_done;

    // --- PLL: 50 MHz → 12.288 MHz ---
    audio_pll audio_pll_inst (
        .refclk   (CLOCK_50),
        .rst      (rst),
        .outclk_0 (aud_xck),
        .locked   (pll_locked)
    );

    assign AUD_XCK = aud_xck;

    // --- I2C Configurator (runs on 50 MHz domain) ---
    // Keep in 50 MHz domain — I2C is slow (100 kHz) and doesn't need PLL clock.
    i2c_config i2c_inst (
        .clk_50mhz  (CLOCK_50),
        .rst        (rst),
        .i2c_sclk   (I2C_SCLK),
        .i2c_sdat   (I2C_SDAT),
        .config_done(config_done)
    );

    // --- I2S Transmitter ---
    // FIX: clocked from aud_xck (12.288 MHz) so BCLK is synchronous to MCLK.
    // Reset is held until PLL is locked AND codec config is complete.
    logic i2s_rst;
    assign i2s_rst = rst | ~pll_locked | ~config_done;

    i2s_transmitter i2s_inst (
        .clk_50mhz  (aud_xck),       // FIX: was CLOCK_50
        .rst        (i2s_rst),        // FIX: gated on pll_locked & config_done
        .sample_in  (FILTERED_SOUND),
        .aud_bclk   (AUD_BCLK),
        .aud_daclrck(AUD_DACLRCK),
        .aud_dacdat (AUD_DACDAT)
    );

endmodule
