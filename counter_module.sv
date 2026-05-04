module counter_module#(
	parameter int SYS_CLK_FREQ = 50_000_000,
	parameter int SAMPLE_RATE = 50_000
)(
	input logic clk,
	input logic rst,
	output logic [31:0] counter, // n of x[n]
	output logic sample_enable  // sample_enable = 1 => x[n] --> x[n+1]
);

	//local parameters
	localparam int MAX_COUNT = SYS_CLK_FREQ/SAMPLE_RATE;
	//local variables
	logic [9:0] enable_counter; // 0-> 999
	
	//enable generator
	always_ff @(posedge clk or posedge rst) begin
		if(rst) begin
			enable_counter <= 10'b0;
			sample_enable <= 1'b0;
			counter <= 32'b0;
		end else begin
			if(enable_counter == MAX_COUNT - 1) begin
				enable_counter <= 10'b0;
				sample_enable <= 1'b1;
				counter <= counter + 32'b1;
			end else begin
				enable_counter <= enable_counter + 10'd1;
				sample_enable <= 1'b0;
			end
		end
	end
	
endmodule