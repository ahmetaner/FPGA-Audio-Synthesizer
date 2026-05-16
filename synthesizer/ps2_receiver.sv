module ps2_receiver (
    input  logic clk_50mhz,  // system clock
    input  logic reset,      // synchronous/asynchronous reset
    input  logic ps2_clk,    // Asynchronous clock from the keyboard
    input  logic ps2_dat,    // Asynchronous data from the keyboard
    output logic [7:0] rx_data, // The 8-bit key code that is read (Scan Code)
    output logic rx_valid    // A flag indicating that the data is ready.
);

    // 1. Clock Domain Crossing (Synchronization to prevent metastability.)
    logic [2:0] ps2_clk_sync;
    logic [1:0] ps2_dat_sync;

    always_ff @(posedge clk_50mhz or posedge reset) begin
        if (reset) begin
            ps2_clk_sync <= 3'b111;
            ps2_dat_sync <= 2'b11;
        end else begin
            ps2_clk_sync <= {ps2_clk_sync[1:0], ps2_clk};
            ps2_dat_sync <= {ps2_dat_sync[0], ps2_dat};
        end
    end

    // Detecting the falling edge of ps2_clk
    logic falling_edge;
    assign falling_edge = (ps2_clk_sync[2:1] == 2'b10);

    // Synchronized data
    logic ps2_dat_synced;
    assign ps2_dat_synced = ps2_dat_sync[1];

    // 2. Reading the 11-Bit Frame (Shift Register)
    logic [3:0] bit_count;
    logic [10:0] shift_reg;

    always_ff @(posedge clk_50mhz or posedge reset) begin
        if (reset) begin
            bit_count <= 4'd0;
            rx_valid  <= 1'b0;
            rx_data   <= 8'd0;
            shift_reg <= 11'd0;
        end else begin
            rx_valid <= 1'b0; // Default is 0, will only become 1 when the data is completely finished.
            
            if (falling_edge) begin
                // Add the incoming bit to the top of the shift register and shift it to the right (LSB first).
                shift_reg <= {ps2_dat_synced, shift_reg[10:1]};
                
                if (bit_count == 4'd10) begin
                    // 11 bits completed, light the valid flag and export the data.
                    bit_count <= 4'd0;
                    
                    // FIXED LINE: Start (0), Parity (9), End (10) are discarded, and the 8 data bits [8:1] are taken.
                    rx_data   <= shift_reg[9:2];
                    
                    rx_valid  <= 1'b1;
                end else begin
                    bit_count <= bit_count + 4'd1;
                end
            end
        end
    end

endmodule	