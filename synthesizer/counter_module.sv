module counter_module #(
    parameter int SYS_CLK_FREQ = 50_000_000,
    parameter int SAMPLE_RATE  = 48_000,       // FIX: was 50_000, oscillator phase_inc is tuned for 48 kHz
    parameter int AGE_RATE     = 1000
)(
    input  logic clk,
    input  logic rst,
    output logic [31:0] counter,      // sample index n
    output logic        sample_enable, // single-cycle pulse at 48 kHz
    output logic        age_enable
);

    localparam int SAMPLE_MAX_COUNT = SYS_CLK_FREQ / SAMPLE_RATE; // 1042 cycles @ 50 MHz / 48 kHz
    localparam int AGE_MAX_COUNT    = SYS_CLK_FREQ / AGE_RATE;    // 50000 cycles

    // Widen sample_counter to hold up to SAMPLE_MAX_COUNT (needs >10 bits for 1042)
    logic [10:0] sample_counter;
    logic [15:0] age_counter;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            sample_counter <= '0;
            age_counter    <= '0;
            sample_enable  <= 1'b0;
            age_enable     <= 1'b0;
            counter        <= '0;
        end else begin
            // --- Sample enable (48 kHz) ---
            if (sample_counter == SAMPLE_MAX_COUNT - 1) begin
                sample_counter <= '0;
                sample_enable  <= 1'b1;
                counter        <= counter + 1;
            end else begin
                sample_counter <= sample_counter + 1'b1;
                sample_enable  <= 1'b0;
            end

            // --- Age enable (1 kHz) ---
            if (age_counter == AGE_MAX_COUNT - 1) begin
                age_counter <= '0;
                age_enable  <= 1'b1;
            end else begin
                age_counter <= age_counter + 1'b1;
                age_enable  <= 1'b0;
            end
        end
    end

endmodule
