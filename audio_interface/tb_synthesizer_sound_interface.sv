`timescale 1ns/1ps

module tb_synthesizer_sound_interface;

    logic CLOCK_50;
    logic rst;

    logic signed [15:0] FILTERED_SOUND;

    logic I2C_SCLK;
    tri   I2C_SDAT;

    logic AUD_XCK;
    logic AUD_BCLK;
    logic AUD_DACLRCK;
    logic AUD_DACDAT;

    // 50 MHz clock = 20 ns period
    initial CLOCK_50 = 1'b0;
    always #10 CLOCK_50 = ~CLOCK_50;

    // DUT
    synthesizer_sound_interface dut (
        .CLOCK_50       (CLOCK_50),
        .rst            (rst),
        .FILTERED_SOUND (FILTERED_SOUND),

        .I2C_SCLK       (I2C_SCLK),
        .I2C_SDAT       (I2C_SDAT),

        .AUD_XCK        (AUD_XCK),
        .AUD_BCLK       (AUD_BCLK),
        .AUD_DACLRCK    (AUD_DACLRCK),
        .AUD_DACDAT     (AUD_DACDAT)
    );

    // Fake I2C slave ACK:
    // I2C master ACK bitinde SDA'yı release ediyor.
    // Biz testbench'ten SDA'yı 0'a çekerek ACK veriyoruz.
    logic fake_ack_drive;

    assign I2C_SDAT = fake_ack_drive ? 1'b0 : 1'bz;

    initial begin
        fake_ack_drive = 1'b0;

        forever begin
            @(negedge I2C_SCLK);
            // Her 9. bit civarında kısa ACK denemesi.
            // Basit test için yeterli; detaylı slave modelini sonra yazarız.
            #100;
        end
    end

    // Stimulus
    initial begin
        rst = 1'b1;
        FILTERED_SOUND = 16'sd0;

        #200;
        rst = 1'b0;

        // I2S datasında görülebilir pattern
        #20_000;
        FILTERED_SOUND = 16'sh7FFF;

        #20_000;
        FILTERED_SOUND = -16'sd32768;

        #20_000;
        FILTERED_SOUND = 16'sh1234;

        #20_000;
        FILTERED_SOUND = 16'shABCD;

        // I2C config için birkaç ms çalıştırmak gerekir
        #5_000_000;

        $stop;
    end

endmodule