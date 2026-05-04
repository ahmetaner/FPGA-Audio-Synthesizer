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

    audio_pll audio_pll_inst (
        .refclk   (CLOCK_50),
        .rst      (rst),
        .outclk_0 (aud_xck),
        .locked   (pll_locked)
    );

    assign AUD_XCK = aud_xck;

    i2c_config i2c_inst (
        .clk_50mhz   (CLOCK_50),
        .rst         (rst),
        .i2c_sclk    (I2C_SCLK),
        .i2c_sdat    (I2C_SDAT),
        .config_done (config_done)
    );

    i2s_transmitter i2s_inst (
        .clk_50mhz    (CLOCK_50),
        .rst          (rst),
        .sample_in    (FILTERED_SOUND),
        .aud_bclk     (AUD_BCLK),
        .aud_daclrck  (AUD_DACLRCK),
        .aud_dacdat   (AUD_DACDAT)
    );

endmodule