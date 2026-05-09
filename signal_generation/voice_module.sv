module voice_module (
    input  logic        CLK_50MHZ,
    input  logic        RST,
    input  logic        SAMPLE_ENABLE,
    input  logic [15:0] FREQ_HZ,       // 5. kişiden gelecek
    input  logic [1:0]  WAVE_SEL,      // Kullanıcı seçecek (Switch)

    output logic signed [15:0] RAW_SOUND // ADSR veya Miksere gidecek ham ses
);

    // --- İÇ KABLOLAR (Osilatör ile ROM arasındaki iletişim hattı) ---
    logic [11:0] adres_kablosu;
    logic signed [15:0] veri_kablosu;

    // --- 1. SENİN OSİLATÖRÜN ---
    oscillator osc_inst (
        .clk_50mhz     (CLK_50MHZ),
        .rst           (RST),
        .sample_enable (SAMPLE_ENABLE),
        .freq_hz       (FREQ_HZ),
        .wave_sel      (WAVE_SEL),
        
        // ROM bağlantıları
        .rom_address   (adres_kablosu), // Osilatör hesapladığı adresi bu kabloya verir
        .sine_rom_data (veri_kablosu),  // ROM'dan gelen veriyi bu kablodan okur
        
        // Çıkış
        .wave_out      (RAW_SOUND)      // Üretilen nihai dalgayı dışarı fırlatır
    );

    // --- 2. QUARTUS'UN ÜRETTİĞİ ROM BLOĞU ---
    // (sine_rom_inst.v dosyasından aldığımız şablonun doldurulmuş hali)
    sine_rom sine_rom_inst (
        .address (adres_kablosu), // Osilatörden gelen adresi al
        .clock   (CLK_50MHZ),     // Sistemi çalıştıran saati ver
        .q       (veri_kablosu)   // Çıkan veriyi osilatörün okuyacağı kabloya bas
    );

endmodule
