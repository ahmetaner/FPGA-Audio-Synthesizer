module voice_allocator (
    input  logic        CLK_50MHZ,
    input  logic        RST,
    input  logic [18:0] BTN_STATE_BUS,
    input  logic        AGE_ENABLE,
    input  logic [1:0]  OCTAVE_SHIFT,  // 0=C2 baz, 1=C3 baz, 2=C4 baz, 3=C5 baz

    output logic [15:0] FREQ_V1,
    output logic [15:0] FREQ_V2,
    output logic [15:0] FREQ_V3,
    output logic [15:0] FREQ_V4,
    output logic        GATE_V1,
    output logic        GATE_V2,
    output logic        GATE_V3,
    output logic        GATE_V4
);

    // -------------------------------------------------------------------------
    // Nota ID'leri — key_state_bus bit pozisyonları
    // -------------------------------------------------------------------------
    localparam logic [4:0] NOTE_C   = 5'd0;
    localparam logic [4:0] NOTE_D   = 5'd1;
    localparam logic [4:0] NOTE_E   = 5'd2;
    localparam logic [4:0] NOTE_F   = 5'd3;
    localparam logic [4:0] NOTE_G   = 5'd4;
    localparam logic [4:0] NOTE_A   = 5'd5;
    localparam logic [4:0] NOTE_B   = 5'd6;
    localparam logic [4:0] NOTE_CH  = 5'd7;   // C bir üst oktav (harf sırasının 2. oktavı)
    localparam logic [4:0] NOTE_DH  = 5'd8;
    localparam logic [4:0] NOTE_EH  = 5'd9;
    localparam logic [4:0] NOTE_FH  = 5'd10;
    localparam logic [4:0] NOTE_CS  = 5'd11;  // C#
    localparam logic [4:0] NOTE_DS  = 5'd12;  // D#
    localparam logic [4:0] NOTE_FS  = 5'd13;  // F#
    localparam logic [4:0] NOTE_GS  = 5'd14;  // G#
    localparam logic [4:0] NOTE_AS  = 5'd15;  // A#
    localparam logic [4:0] NOTE_CSH = 5'd16;  // C#' (üst oktav)
    localparam logic [4:0] NOTE_DSH = 5'd17;  // D#' (üst oktav)
    localparam logic [4:0] NOTE_FSH = 5'd18;  // F#' (üst oktav)
    localparam logic [4:0] EMPTY    = 5'd31;

    // -------------------------------------------------------------------------
    // Temel frekanslar — C2 oktavı baz alınarak (OCTAVE_SHIFT=0)
    // Her oktav yukarı = frekans x2 (bit shift ile)
    // -------------------------------------------------------------------------
    // C2=65, D2=73, E2=82, F2=87, G2=98, A2=110, B2=123
    // C3=131, D3=147 (üst oktav tuşları — harf sırası sağ yarısı)
    // C#2=69, D#2=78, F#2=92, G#2=104, A#2=117
    // C#3=139, D#3=156, F#3=185

    logic [4:0]  note_id;
    logic [15:0] freq_base;   // C2 bazlı temel frekans
    logic [15:0] freq_note;   // Oktav kaydırma uygulanmış frekans
    logic [18:0] btn_state_old;
    logic [18:0] btn_pushed;
    logic [18:0] btn_released;

    logic [4:0]  note_channel [0:3];
    logic [15:0] note_age     [0:3];
    logic [1:0]  oldest_note;
    logic gate_v [0:3];

    assign GATE_V1 = gate_v[0];
    assign GATE_V2 = gate_v[1];
    assign GATE_V3 = gate_v[2];
    assign GATE_V4 = gate_v[3];

    assign btn_released = btn_state_old & ~BTN_STATE_BUS;
    assign btn_pushed   = BTN_STATE_BUS & ~btn_state_old;

    // -------------------------------------------------------------------------
    // Adım 1: C2 bazlı temel frekans tablosu
    // -------------------------------------------------------------------------
    always_comb begin
        case (note_id)
            NOTE_C:   freq_base = 16'd65;   // C2
            NOTE_D:   freq_base = 16'd73;   // D2
            NOTE_E:   freq_base = 16'd82;   // E2
            NOTE_F:   freq_base = 16'd87;   // F2
            NOTE_G:   freq_base = 16'd98;   // G2
            NOTE_A:   freq_base = 16'd110;  // A2
            NOTE_B:   freq_base = 16'd123;  // B2
            NOTE_CH:  freq_base = 16'd131;  // C3  (harf sırası üst oktav başlangıcı)
            NOTE_DH:  freq_base = 16'd147;  // D3
            NOTE_EH:  freq_base = 16'd165;  // E3
            NOTE_FH:  freq_base = 16'd175;  // F3
            NOTE_CS:  freq_base = 16'd69;   // C#2
            NOTE_DS:  freq_base = 16'd78;   // D#2
            NOTE_FS:  freq_base = 16'd92;   // F#2
            NOTE_GS:  freq_base = 16'd104;  // G#2
            NOTE_AS:  freq_base = 16'd117;  // A#2
            NOTE_CSH: freq_base = 16'd139;  // C#3
            NOTE_DSH: freq_base = 16'd156;  // D#3
            NOTE_FSH: freq_base = 16'd185;  // F#3
            default:  freq_base = 16'd0;
        endcase
    end

    // -------------------------------------------------------------------------
    // Adım 2: Oktav kaydırma — bit shift ile frekansı ölçekle
    // OCTAVE_SHIFT=0 → x1 (C2 baz)
    // OCTAVE_SHIFT=1 → x2 (C3 baz)
    // OCTAVE_SHIFT=2 → x4 (C4 baz) ← varsayılan başlangıç
    // OCTAVE_SHIFT=3 → x8 (C5 baz)
    // -------------------------------------------------------------------------
    always_comb begin
        case (OCTAVE_SHIFT)
            2'd0: freq_note = freq_base;          // C2 bazlı (en kalın)
            2'd1: freq_note = freq_base << 1;     // C3 bazlı
            2'd2: freq_note = freq_base << 2;     // C4 bazlı (varsayılan)
            2'd3: freq_note = freq_base << 3;     // C5 bazlı (en ince)
            default: freq_note = freq_base << 2;
        endcase
    end

    // -------------------------------------------------------------------------
    // Öncelik kodlayıcı
    // -------------------------------------------------------------------------
    always_comb begin
        note_id = EMPTY;
        for (int i = 0; i < 19; i++) begin
            if (btn_pushed[i]) note_id = i[4:0];
        end
    end

    // -------------------------------------------------------------------------
    // En eski ses kanalı karşılaştırıcısı
    // -------------------------------------------------------------------------
    always_comb begin
        oldest_note = 2'd0;
        if (note_age[1] > note_age[oldest_note]) oldest_note = 2'd1;
        if (note_age[2] > note_age[oldest_note]) oldest_note = 2'd2;
        if (note_age[3] > note_age[oldest_note]) oldest_note = 2'd3;
    end

    // -------------------------------------------------------------------------
    // Sıralı mantık: tahsis, bırakma, yaşlandırma
    // -------------------------------------------------------------------------
    always_ff @(posedge CLK_50MHZ or posedge RST) begin
        if (RST) begin
            FREQ_V1 <= '0; FREQ_V2 <= '0; FREQ_V3 <= '0; FREQ_V4 <= '0;
            gate_v[0] <= '0; gate_v[1] <= '0; gate_v[2] <= '0; gate_v[3] <= '0;
            note_channel[0] <= EMPTY; note_channel[1] <= EMPTY;
            note_channel[2] <= EMPTY; note_channel[3] <= EMPTY;
            note_age[0] <= '0; note_age[1] <= '0;
            note_age[2] <= '0; note_age[3] <= '0;
            btn_state_old <= '0;
        end else begin
            btn_state_old <= BTN_STATE_BUS;

            if (AGE_ENABLE) begin
                if (gate_v[0]) note_age[0] <= note_age[0] + 1'b1;
                if (gate_v[1]) note_age[1] <= note_age[1] + 1'b1;
                if (gate_v[2]) note_age[2] <= note_age[2] + 1'b1;
                if (gate_v[3]) note_age[3] <= note_age[3] + 1'b1;
            end

            if (btn_pushed != '0) begin
                if (!gate_v[0]) begin
                    FREQ_V1         <= freq_note;
                    gate_v[0]       <= 1'b1;
                    note_channel[0] <= note_id;
                    note_age[0]     <= '0;
                end else if (!gate_v[1]) begin
                    FREQ_V2         <= freq_note;
                    gate_v[1]       <= 1'b1;
                    note_channel[1] <= note_id;
                    note_age[1]     <= '0;
                end else if (!gate_v[2]) begin
                    FREQ_V3         <= freq_note;
                    gate_v[2]       <= 1'b1;
                    note_channel[2] <= note_id;
                    note_age[2]     <= '0;
                end else if (!gate_v[3]) begin
                    FREQ_V4         <= freq_note;
                    gate_v[3]       <= 1'b1;
                    note_channel[3] <= note_id;
                    note_age[3]     <= '0;
                end else begin
                    case (oldest_note)
                        2'd0: begin FREQ_V1 <= freq_note; gate_v[0] <= 1'b1; note_channel[0] <= note_id; note_age[0] <= '0; end
                        2'd1: begin FREQ_V2 <= freq_note; gate_v[1] <= 1'b1; note_channel[1] <= note_id; note_age[1] <= '0; end
                        2'd2: begin FREQ_V3 <= freq_note; gate_v[2] <= 1'b1; note_channel[2] <= note_id; note_age[2] <= '0; end
                        2'd3: begin FREQ_V4 <= freq_note; gate_v[3] <= 1'b1; note_channel[3] <= note_id; note_age[3] <= '0; end
                    endcase
                end
            end

            if (btn_released != '0) begin
                if (gate_v[0] && btn_released[note_channel[0]]) begin gate_v[0] <= 1'b0; note_channel[0] <= EMPTY; end
                if (gate_v[1] && btn_released[note_channel[1]]) begin gate_v[1] <= 1'b0; note_channel[1] <= EMPTY; end
                if (gate_v[2] && btn_released[note_channel[2]]) begin gate_v[2] <= 1'b0; note_channel[2] <= EMPTY; end
                if (gate_v[3] && btn_released[note_channel[3]]) begin gate_v[3] <= 1'b0; note_channel[3] <= EMPTY; end
            end
        end
    end

endmodule
