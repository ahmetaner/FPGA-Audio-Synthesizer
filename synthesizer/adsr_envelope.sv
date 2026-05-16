// =============================================================================
//  adsr_envelope.sv  —  FIXED
//
//  FIX (Bug 3): Output multiply bit-extraction corrected from [47:32] → [46:31].
//
//  Explanation:
//    mixed_sound  is signed [15:0]   (range -32768 .. +32767)
//    envelope     is unsigned [31:0] in Q0.32 format (range 0 .. ~1.0)
//    $signed({1'b0, envelope}) is signed [32:0]
//
//    Product width = 16 + 33 = 49 bits  → audio_mult is signed [48:0]
//
//    The integer (audio) part of the result sits at bits [46:31]:
//      - bits [30:0]  are the 31 fractional bits from the Q0.32 envelope
//      - bits [46:31] are the 16 integer bits (the actual audio sample)
//      - bit  [48]    is the sign extension guard bit (always equals bit[47])
//
//    The old code extracted [47:32], which was shifted one bit too high —
//    effectively dividing the output by 2 and mis-aligning the sign bit.
// =============================================================================

module adsr_envelope (
    input logic clk,
    input logic rst,
    input logic gate_v1,
    input logic sample_enable,
    input logic signed [15:0] mixed_sound,
    output logic signed [15:0] shaped_sound
);

    typedef enum logic[2:0]{
        zero       = 3'b000,
        attack     = 3'b001,
        decay      = 3'b010,
        sustain    = 3'b011,
        release_st = 3'b100
    } adsr_fsm;

    // Q0.32 coefficients
    localparam logic [31:0] ATTACK_COEF   = 32'd4_280_000_000;
    localparam logic [31:0] DECAY_COEF    = 32'd4_294_797_183;
    localparam logic [31:0] RELEASE_COEF  = 32'd4_230_189_873;

    localparam logic [31:0] ONE           = 32'hFFFF_FFFF;
    localparam logic [31:0] DOT5          = 32'd2_147_483_648;
    localparam logic [31:0] EPSILON       = 32'd1_000_000;
    localparam logic [31:0] ATTACK_TARGET = ONE - EPSILON;

    logic [31:0] envelope;
    adsr_fsm next_state, current_state;

    // --- Shared DSP multiplier ---
    logic [31:0] mult_in_a;
    logic [31:0] mult_in_b;
    logic [63:0] shared_mult;

    always_comb begin
        if (current_state == attack)
            mult_in_a = ONE - envelope;
        else
            mult_in_a = envelope;

        unique case(current_state)
            attack:  mult_in_b = ATTACK_COEF;
            decay:   mult_in_b = DECAY_COEF;
            default: mult_in_b = RELEASE_COEF;
        endcase

        shared_mult = {32'd0, mult_in_a} * mult_in_b;
    end

    // --- 1. Sequential: envelope update ---
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= zero;
            envelope      <= 32'b0;
        end else begin
            current_state <= next_state;
            if (current_state == zero) begin
                envelope <= 32'b0;
            end else if (sample_enable) begin
                unique case(current_state)
                    attack:     envelope <= ONE - shared_mult[63:32];
                    decay:      envelope <= shared_mult[63:32];
                    sustain:    envelope <= envelope;
                    release_st: envelope <= shared_mult[63:32];
                    default:    envelope <= envelope;
                endcase
            end
        end
    end

    // --- 2. Combinational: FSM next-state ---
    always_comb begin
        next_state = current_state;
        unique case(current_state)
            zero: begin
                if (gate_v1) next_state = attack;
            end
            attack: begin
                if (!gate_v1)               next_state = release_st;
                else if (envelope >= ATTACK_TARGET) next_state = decay;
            end
            decay: begin
                if (!gate_v1)               next_state = release_st;
                else if (envelope <= DOT5)  next_state = sustain;
            end
            sustain: begin
                if (!gate_v1) next_state = release_st;
            end
            release_st: begin
                if (gate_v1)                next_state = attack;
                else if (envelope <= EPSILON) next_state = zero;
            end
            default: next_state = zero;
        endcase
    end

    // --- 3. Combinational: output scaling ---
    //  mixed_sound  : signed [15:0]
    //  {1'b0,envelope} sign-extended → signed [32:0]
    //  product      : signed [48:0]
    //
    //  FIX: extract bits [46:31] — the 16 integer bits after the 31 fractional
    //  bits of the Q0.32 envelope.  Old code used [47:32] which was 1 bit high.
    logic signed [48:0] audio_mult;

    always_comb begin
        audio_mult  = mixed_sound * $signed({1'b0, envelope});
        shaped_sound = audio_mult[46:31];   // FIX: was [47:32]
    end

endmodule