module i2s_transmitter (
    input  logic clk_50mhz,
    input  logic rst,

    input  logic signed [15:0] sample_in,

    output logic aud_bclk,
    output logic aud_daclrck,
    output logic aud_dacdat
);

    // 50 MHz / 32 = 1.5625 MHz BCLK civarı.
    // Başlangıç testi için yeterli. Daha sonra PLL clock ile iyileştiririz.
    localparam int BCLK_DIV = 16;

    logic [$clog2(BCLK_DIV)-1:0] bclk_cnt;
    logic bclk_tick;

    always_ff @(posedge clk_50mhz or posedge rst) begin
        if (rst) begin
            bclk_cnt <= 0;
            bclk_tick <= 0;
            aud_bclk <= 0;
        end else begin
            if (bclk_cnt == BCLK_DIV-1) begin
                bclk_cnt <= 0;
                aud_bclk <= ~aud_bclk;
                bclk_tick <= 1;
            end else begin
                bclk_cnt <= bclk_cnt + 1;
                bclk_tick <= 0;
            end
        end
    end

    logic [5:0] bit_cnt;
    logic signed [15:0] sample_latched;
    logic [31:0] shift_reg;

    always_ff @(posedge clk_50mhz or posedge rst) begin
        if (rst) begin
            bit_cnt <= 0;
            aud_daclrck <= 0;
            aud_dacdat <= 0;
            sample_latched <= 0;
            shift_reg <= 0;
        end else begin
            // BCLK falling edge gibi davranıyoruz
            if (bclk_tick && aud_bclk == 1'b1) begin

                if (bit_cnt == 0) begin
                    sample_latched <= sample_in;

                    // Left + Right aynı sample
                    shift_reg <= {sample_in, sample_in};

                    aud_daclrck <= 1'b0; // Left channel
                    aud_dacdat <= sample_in[15];

                    bit_cnt <= bit_cnt + 1;
                end else begin
                    shift_reg <= {shift_reg[30:0], 1'b0};
                    aud_dacdat <= shift_reg[30];

                    if (bit_cnt == 15)
                        aud_daclrck <= 1'b1; // Right channel

                    if (bit_cnt == 31)
                        bit_cnt <= 0;
                    else
                        bit_cnt <= bit_cnt + 1;
                end
            end
        end
    end

endmodule