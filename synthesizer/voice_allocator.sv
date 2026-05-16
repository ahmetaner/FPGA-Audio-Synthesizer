module voice_allocator (
    input  logic        CLK_50MHZ,
    input  logic        RST,
    input  logic [11:0] BTN_STATE_BUS,
    input  logic        AGE_ENABLE,

    output logic [15:0] FREQ_V1,
    output logic [15:0] FREQ_V2,
    output logic [15:0] FREQ_V3,
    output logic [15:0] FREQ_V4,
    output logic        GATE_V1,
    output logic        GATE_V2,
    output logic        GATE_V3,
    output logic        GATE_V4
);

    // Note IDs (mapped to key_state_bus bit positions)
    localparam logic [3:0] NOTE_A      = 4'd0;
    localparam logic [3:0] NOTE_ASHARP = 4'd1;
    localparam logic [3:0] NOTE_B      = 4'd2;
    localparam logic [3:0] NOTE_C      = 4'd3;
    localparam logic [3:0] NOTE_CSHARP = 4'd4;
    localparam logic [3:0] NOTE_D      = 4'd5;
    localparam logic [3:0] NOTE_DSHARP = 4'd6;
    localparam logic [3:0] NOTE_E      = 4'd7;
    localparam logic [3:0] NOTE_F      = 4'd8;
    localparam logic [3:0] NOTE_FSHARP = 4'd9;
    localparam logic [3:0] NOTE_G      = 4'd10;
    localparam logic [3:0] NOTE_GSHARP = 4'd11;
    localparam logic [3:0] EMPTY       = 4'd12;  // No note

    // Internal signals
    logic [3:0]  note_id;
    logic [15:0] freq_note;
    logic [11:0] btn_state_old;
    logic [11:0] btn_pushed;
    logic [11:0] btn_released;

    // FIX: Unified all arrays to 0-based [0:3] indexing.
    // Original code mixed [1:4] for note_channel and [0:3] for note_age,
    // causing voice 4 to use note_channel[4] (out of bounds for a [0:3] array)
    // and age comparisons to reference wrong slots.
    logic [3:0]  note_channel [0:3];
    logic [15:0] note_age     [0:3];
    logic [1:0]  oldest_note;

    logic gate_v [0:3];

    // Drive outputs from internal gate array
    assign GATE_V1 = gate_v[0];
    assign GATE_V2 = gate_v[1];
    assign GATE_V3 = gate_v[2];
    assign GATE_V4 = gate_v[3];

    assign btn_released = btn_state_old & ~BTN_STATE_BUS;
    assign btn_pushed   = BTN_STATE_BUS & ~btn_state_old;

    // --- Frequency lookup table ---
    always_comb begin
        case (note_id)
            NOTE_A:      freq_note = 16'd440;
            NOTE_ASHARP: freq_note = 16'd466;
            NOTE_B:      freq_note = 16'd494;
            NOTE_C:      freq_note = 16'd262;
            NOTE_CSHARP: freq_note = 16'd277;
            NOTE_D:      freq_note = 16'd294;
            NOTE_DSHARP: freq_note = 16'd311;
            NOTE_E:      freq_note = 16'd330;
            NOTE_F:      freq_note = 16'd349;
            NOTE_FSHARP: freq_note = 16'd370;
            NOTE_G:      freq_note = 16'd392;
            NOTE_GSHARP: freq_note = 16'd415;
            default:     freq_note = 16'd0;
        endcase
    end

    // --- 12-to-4 priority encoder: which key was just pressed ---
    always_comb begin
        note_id = EMPTY;
        for (int i = 0; i < 12; i++) begin
            if (btn_pushed[i]) note_id = i[3:0];
        end
    end

    // --- Oldest-voice comparator (for note stealing) ---
    always_comb begin
        oldest_note = 2'd0;
        if (note_age[1] > note_age[oldest_note]) oldest_note = 2'd1;
        if (note_age[2] > note_age[oldest_note]) oldest_note = 2'd2;
        if (note_age[3] > note_age[oldest_note]) oldest_note = 2'd3;
    end

    // --- Sequential: allocation, release, ageing ---
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

            // Ageing: increment age of active voices
            if (AGE_ENABLE) begin
                if (gate_v[0]) note_age[0] <= note_age[0] + 1'b1;
                if (gate_v[1]) note_age[1] <= note_age[1] + 1'b1;
                if (gate_v[2]) note_age[2] <= note_age[2] + 1'b1;
                if (gate_v[3]) note_age[3] <= note_age[3] + 1'b1;
            end

            // Key pressed: allocate a free voice (or steal oldest)
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
                    // Note stealing: replace the oldest voice
                    case (oldest_note)
                        2'd0: begin FREQ_V1 <= freq_note; gate_v[0] <= 1'b1; note_channel[0] <= note_id; note_age[0] <= '0; end
                        2'd1: begin FREQ_V2 <= freq_note; gate_v[1] <= 1'b1; note_channel[1] <= note_id; note_age[1] <= '0; end
                        2'd2: begin FREQ_V3 <= freq_note; gate_v[2] <= 1'b1; note_channel[2] <= note_id; note_age[2] <= '0; end
                        2'd3: begin FREQ_V4 <= freq_note; gate_v[3] <= 1'b1; note_channel[3] <= note_id; note_age[3] <= '0; end
                    endcase
                end
            end

            // Key released: silence the voice holding that note
            if (btn_released != '0) begin
                if (gate_v[0] && btn_released[note_channel[0]]) begin gate_v[0] <= 1'b0; note_channel[0] <= EMPTY; end
                if (gate_v[1] && btn_released[note_channel[1]]) begin gate_v[1] <= 1'b0; note_channel[1] <= EMPTY; end
                if (gate_v[2] && btn_released[note_channel[2]]) begin gate_v[2] <= 1'b0; note_channel[2] <= EMPTY; end
                if (gate_v[3] && btn_released[note_channel[3]]) begin gate_v[3] <= 1'b0; note_channel[3] <= EMPTY; end
            end
        end
    end

endmodule
