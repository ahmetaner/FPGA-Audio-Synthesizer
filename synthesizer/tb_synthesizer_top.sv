`timescale 1ns / 1ps

module tb_synthesizer_top;

    // Inputs
    logic CLOCK_50;
    logic KEY0;
    logic PS2_CLK;
    logic PS2_DAT;

    // Outputs
    logic AUD_XCK;
    logic AUD_BCLK;
    logic AUD_DACLRCK;
    logic AUD_DACDAT;
    logic I2C_SCLK;
    logic [3:0] LEDR;

    // Inouts
    wire I2C_SDAT;

    // I2C data hattı (inout) için pull-up
    assign I2C_SDAT = 1'bZ;

    // Test edilecek top modülün (UUT) tanımlanması
    synthesizer_top uut (
        .CLOCK_50(CLOCK_50),
        .KEY0(KEY0),
        .PS2_CLK(PS2_CLK),
        .PS2_DAT(PS2_DAT),
        .AUD_XCK(AUD_XCK),
        .AUD_BCLK(AUD_BCLK),
        .AUD_DACLRCK(AUD_DACLRCK),
        .AUD_DACDAT(AUD_DACDAT),
        .I2C_SCLK(I2C_SCLK),
        .I2C_SDAT(I2C_SDAT),
        .LEDR(LEDR)
    );

    // 50 MHz Clock Üretimi (20ns periyot)
    initial CLOCK_50 = 0;
    always #10 CLOCK_50 = ~CLOCK_50;

    // PS/2 Klavye Emülasyon Task'i
    // PS/2 clock frekansı yaklaşık 10-16 kHz'dir. Burada ~10 kHz (100us periyot) kullanıyoruz.
    task send_ps2_byte(input [7:0] data);
        integer i;
        logic parity;
        begin
            parity = ~(^data); // Odd (Tek) parity hesaplaması

            // Start bit (0)
            PS2_DAT = 1'b0;
            #50_000; PS2_CLK = 1'b0; #50_000; PS2_CLK = 1'b1;

            // Data bitleri (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                PS2_DAT = data[i];
                #50_000; PS2_CLK = 1'b0; #50_000; PS2_CLK = 1'b1;
            end

            // Parity bit
            PS2_DAT = parity;
            #50_000; PS2_CLK = 1'b0; #50_000; PS2_CLK = 1'b1;

            // Stop bit (1)
            PS2_DAT = 1'b1;
            #50_000; PS2_CLK = 1'b0; #50_000; PS2_CLK = 1'b1;

            #100_000; // Bir sonraki byte gönderimi öncesi bekleme
        end
    endtask

    initial begin
        // Waveform dosyası oluşturma (Opsiyonel, Icarus Verilog vs. için)
        $dumpfile("synth_tb.vcd");
        $dumpvars(0, tb_synthesizer_top);

        // Başlangıç değerleri
        KEY0 = 1;
        PS2_CLK = 1;
        PS2_DAT = 1;

        // Reset Uygulama (KEY0 active-low)
        #100;
        KEY0 = 0; 
        #1000;
        KEY0 = 1;

        // Reset'in devrede yayılması ve sistemin oturması için bekleme
        #10_000;

        // 1. Tuşa Basma (Make Code)
        // Örn: 'A' tuşu için 8'h1C gönderiliyor.
        // Bu işlem gate_v1'i aktif edip LEDR[0]'ı yakmalıdır.
        send_ps2_byte(8'h1C);

        // Sesin üretilmesi ve ADSR Attack/Decay fazlarının ilerlemesi için zaman tanı
        // sample_enable 48kHz (yaklaşık 20.8us'de bir) vuruyor.
        // 10 milisaniye bekleyerek waveformların oluşmasını izleyebiliriz.
        #10_000_000;

        // 2. Tuşu Bırakma (Break Code)
        // PS/2'de tuş bırakma 8'hF0 ve ardından tuş kodudur.
        // Bu, gate'i düşürüp ADSR Release fazını tetiklemelidir.
        send_ps2_byte(8'hF0);
        send_ps2_byte(8'h1C);

        // Release fazının sönümlenmesini izlemek için bekle
        #5_000_000;

        $display("Simülasyon tamamlandı.");
        $finish;
    end

endmodule