module scan_code_to_bus (
    input  logic clk_50mhz,
    input  logic reset,         
    input  logic [7:0] rx_data, 
    input  logic rx_valid,      
    
    output logic [11:0] key_state_bus,  
    output logic [1:0] waveform_select, 
    output logic soft_reset             
);

    typedef enum logic {
        IDLE,       
        BREAK_WAIT  
    } state_t;

    // next_state değişkenini sildik, sadece state kullanacağız.
    state_t state; 

    always_ff @(posedge clk_50mhz or posedge reset) begin
        if (reset) begin
            state           <= IDLE;
            key_state_bus   <= 12'b0;
            waveform_select <= 2'b00;
            soft_reset      <= 1'b0;
        end else begin
            soft_reset <= 1'b0; 
            
            if (rx_valid) begin
                if (state == IDLE) begin
                    if (rx_data == 8'hF0) begin
                        // Doğrudan state değişkenini güncelliyoruz
                        state <= BREAK_WAIT; 
                    end else begin
                        case (rx_data)
                            // --- YENİ NOTA TUŞLARI (Q W E R T Y U I O P Ğ/ [ Ü/ ] ) ---
                            8'h15: key_state_bus[0]  <= 1'b1; // 'Q' 
                            8'h1D: key_state_bus[1]  <= 1'b1; // 'W' 
                            8'h24: key_state_bus[2]  <= 1'b1; // 'E' 
                            8'h2D: key_state_bus[3]  <= 1'b1; // 'R' 
                            8'h2C: key_state_bus[4]  <= 1'b1; // 'T' 
                            8'h35: key_state_bus[5]  <= 1'b1; // 'Y' 
                            8'h3C: key_state_bus[6]  <= 1'b1; // 'U' 
                            8'h43: key_state_bus[7]  <= 1'b1; // 'I' 
                            8'h44: key_state_bus[8]  <= 1'b1; // 'O' 
                            8'h4D: key_state_bus[9]  <= 1'b1; // 'P' 
                            8'h54: key_state_bus[10] <= 1'b1; // 'Ğ' veya '[' 
                            8'h5B: key_state_bus[11] <= 1'b1; // 'Ü' veya ']' 
                            
                            // --- WAVEFORM KONTROLÜ (1, 2, 3, 4) ---
                            8'h16: waveform_select <= 2'b00; 
                            8'h1E: waveform_select <= 2'b01; 
                            8'h26: waveform_select <= 2'b10; 
                            8'h25: waveform_select <= 2'b11; 
                            
                            // --- KLAVYE RESETİ ---
                            8'h76: soft_reset <= 1'b1;       // 'ESC' 
                        endcase
                    end
                end else if (state == BREAK_WAIT) begin
                    // Tuş Bırakıldı (Break)
                    case (rx_data)
                        8'h15: key_state_bus[0]  <= 1'b0;
                        8'h1D: key_state_bus[1]  <= 1'b0;
                        8'h24: key_state_bus[2]  <= 1'b0;
                        8'h2D: key_state_bus[3]  <= 1'b0;
                        8'h2C: key_state_bus[4]  <= 1'b0;
                        8'h35: key_state_bus[5]  <= 1'b0;
                        8'h3C: key_state_bus[6]  <= 1'b0;
                        8'h43: key_state_bus[7]  <= 1'b0;
                        8'h44: key_state_bus[8]  <= 1'b0;
                        8'h4D: key_state_bus[9]  <= 1'b0;
                        8'h54: key_state_bus[10] <= 1'b0;
                        8'h5B: key_state_bus[11] <= 1'b0;
                    endcase
                    // İşlem bitince IDLE durumuna dön
                    state <= IDLE; 
                end
            end
        end
    end
endmodule