`timescale 1ns / 1ps

module iir_lowpass_filter #(
    parameter int ALPHA_SHIFT = 4   // Cut-off tuning: larger = lower cut-off frequency
)(
    input  logic               CLK_50MHZ,
    input  logic               RST,
    input  logic               SAMPLE_ENABLE,
    input  logic signed [15:0] SHAPED_SOUND,
    output logic signed [15:0] FILTERED_SOUND
);

    // 32-bit Q16.16 accumulator: [31:16] integer part, [15:0] fractional part
    logic signed [31:0] filter_acc;

    // FIX: 'error' must be declared at module scope; local declarations inside
    //       always_ff blocks are not legal in synthesisable SystemVerilog.
    logic signed [31:0] error;

    always_ff @(posedge CLK_50MHZ or posedge RST) begin
        if (RST) begin
            filter_acc     <= '0;
            FILTERED_SOUND <= '0;
        end else if (SAMPLE_ENABLE) begin
            // First-order IIR: y[n] = y[n-1] + alpha * (x[n] - y[n-1])
            // Promote input to Q16.16 then compute error
            error      = (32'(SHAPED_SOUND) <<< 16) - filter_acc;
            filter_acc <= filter_acc + (error >>> ALPHA_SHIFT);
            // Output the integer part of the accumulator
            FILTERED_SOUND <= filter_acc[31:16];
        end
    end

endmodule
