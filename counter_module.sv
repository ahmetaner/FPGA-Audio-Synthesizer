module counter_module#(
	parameter int SYS_CLK_FREQ = 50_000_000,
	parameter int SAMPLE_RATE  = 50_000,
	parameter int AGE_RATE 		= 1000
)(
	input logic clk,
	input logic rst,
	output logic [31:0] counter, // n of x[n]
	output logic sample_enable,  // sample_enable = 1 => x[n] --> x[n+1]
	output logic age_enable
);

	//local parameters
	localparam int SAMPLE_MAX_COUNT = SYS_CLK_FREQ/SAMPLE_RATE;
	localparam int AGE_MAX_COUNT 	  = SYS_CLK_FREQ/AGE_RATE;	
	//local variables
	logic [9:0]  sample_counter; // 0-> 999
	logic [15:0] age_counter;
	
	//enable generator
	always_ff @(posedge clk or posedge rst) begin
		if(rst) begin
			sample_counter <= 10'b0;
			age_counter 	<= 16'b0;
			sample_enable  <= 1'b0;
			age_enable		<= 1'b0;
			counter 			<= 32'b0;
		end else begin
		
			if(sample_counter == SAMPLE_MAX_COUNT - 1) begin
				sample_counter <= 10'b0;
				sample_enable <= 1'b1;
				counter <= counter + 32'b1;
			end else begin
				sample_counter <= sample_counter + 10'd1;
				sample_enable <= 1'b0;
			end
			
			if(age_counter == AGE_MAX_COUNT - 1) begin
				age_counter <= 16'b0;
				age_enable <= 1'b1;
			end else begin
				age_counter <= age_counter + 16'd1;
				age_enable <= 1'b0;
			end
		end
	end
	
endmodule