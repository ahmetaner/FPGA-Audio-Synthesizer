module oscillator (
    input  logic        clk_50mhz,
    input  logic        rst,
    input  logic        sample_enable, // 48kHz tetikleyicisi
    input  logic [15:0] freq_hz,       // 5. kişiden gelen frekans (örn: 440)
    input  logic [1:0]  wave_sel,      // Dalga seçimi: 00=Sinüs, 01=Kare, 10=Testere, 11=Üçgen
    
    // Sinüs ROM için arayüz (LUT)
    output logic [11:0] rom_address,
    input  logic signed [15:0] sine_rom_data,

    output logic signed [15:0] wave_out
);

    // --- 1. Faz Akümülatörü (Phase Accumulator) ---
    logic [31:0] phase_acc;
    logic [31:0] phase_inc;

    // (2^32) / 48000 = 89478
    assign phase_inc = freq_hz * 32'd89478;

    always_ff @(posedge clk_50mhz or posedge rst) begin
        if (rst) begin
            phase_acc <= 32'b0;
        end 
        else if (sample_enable) begin
            // Sadece saniyede 48000 kez faza ekleme yapılır
            phase_acc <= phase_acc + phase_inc;
        end
    end

    // --- 2. Dalga Şekli Üretimi (Waveform Generation) ---
    logic signed [15:0] sqr_wave;
    logic signed [15:0] saw_wave;
    logic signed [15:0] tri_wave;
	 logic [15:0] tri_unsigned;
	 logic [15:0] tri_centered;
    
    always_comb begin
        // KARE DALGA (Square)
        // Fazın en üst bitine (MSB) bakılır. 0 ise tepe, 1 ise dip nokta.
        // Genliği max yapmıyoruz ki üstüne ADSR binince taşmasın.
        sqr_wave = (phase_acc[31] == 1'b0) ? 16'sd16383 : -16'sd16384;

        // TESTERE DİŞİ (Sawtooth)
        // Fazın en anlamlı 16 bitini doğrudan çıktı olarak alırsak 0'dan tepeye, 
        // sonra aniden dipe vuran testere dişi elde ederiz.
        saw_wave = signed'(phase_acc[31:16]);

        // ÜÇGEN DALGA (Triangle)
         tri_unsigned = phase_acc[30:15] ^ {16{phase_acc[31]}};
			tri_centered = tri_unsigned - 16'h8000;
			tri_wave = signed'(tri_centered);
        
        // SİNÜS DALGA (ROM Bağlantısı)
        // Fazın en anlamlı 12 bitini ROM adresi olarak dışarı gönder.
        rom_address = phase_acc[31:20];
    end

    // --- 3. Dalga Seçici (Multiplexer) ---
    always_comb begin
        unique case (wave_sel)
            2'b00: wave_out = sine_rom_data; // ROM'dan gelen sinüs verisi
            2'b01: wave_out = sqr_wave;
            2'b10: wave_out = saw_wave;
            2'b11: wave_out = tri_wave;
            default: wave_out = 16'sd0;
        endcase
    end

endmodule