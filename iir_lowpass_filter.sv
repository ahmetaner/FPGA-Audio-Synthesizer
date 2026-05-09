`timescale 1ns / 1ps

module iir_lowpass_filter #(
    parameter ALPHA_SHIFT = 4  // Kesme frekansı ayarı
)(
    input  logic               CLK_50MHZ,
    input  logic               RST,
    input  logic               SAMPLE_ENABLE, // ADSR'deki sample_enable ile aynı olmalı
    input  logic signed [15:0] SHAPED_SOUND,  // ADSR'den gelen giriş
    output logic signed [15:0] FILTERED_SOUND
);

    // 32-bit genişletilmiş akümülatör: [31:16] Tamsayı, [15:0] Kesir
    logic signed [31:0] filter_acc;

    always_ff @(posedge CLK_50MHZ or posedge RST) begin
        if (RST) begin
            filter_acc     <= '0;
            FILTERED_SOUND <= '0;
        end 
        // KRİTİK: Filtre sadece ADSR modülündeki yeni örnekleme anında çalışmalıdır.
        else if (SAMPLE_ENABLE) begin 
            
            // 1. Derece IIR Filtre Denklemi: 
            // y[n] = y[n-1] + alpha * (x[n] - y[n-1])
            
            // Mevcut giriş (SHAPED_SOUND) 16-bit'ten 32-bit'e (Q16.16) yükseltilir.
            // (x[n] - y[n-1]) işlemi:
            logic signed [31:0] error;
            error = (32'(SHAPED_SOUND) <<< 16) - filter_acc;

            // Akümülatör güncelleme: y[n] = y[n-1] + (error >> ALPHA_SHIFT)
            // '>>>' kullanımı işaretli (signed) kaydırma yaparak negatif değerleri korur.
            filter_acc <= filter_acc + (error >>> ALPHA_SHIFT);

            // Çıkışa akümülatörün tamsayı kısmını aktar
            FILTERED_SOUND <= filter_acc[31:16];
        end
    end

endmodule