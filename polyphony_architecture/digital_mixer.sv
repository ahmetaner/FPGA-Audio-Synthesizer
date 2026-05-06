module digital_mixer(

		input logic CLK_50MHZ,
		input logic RST,
		
		input logic SAMPLE_ENABLE,
		input logic signed [15:0] SHAPED_SOUND_V1, // Sound wave can take negative value
		input logic signed [15:0] SHAPED_SOUND_V2,
		input logic signed [15:0] SHAPED_SOUND_V3,
		input logic signed [15:0] SHAPED_SOUND_V4,
	
		output logic signed [15:0] MIXED_SOUND
);

	logic signed [16:0] first_sum_sound;		// 17-bit for the carrier
	logic signed [16:0] second_sum_sound;
	logic signed [17:0] total_sum_sound;		// 18-bit for the carrier
	
	// Pipelined Structure 
	always_ff @(posedge(CLK_50MHZ) or posedge(RST))
	begin
	
		if (RST) begin
		
			first_sum_sound 	<= 17'sb0;
			second_sum_sound 	<= 17'sb0;
			total_sum_sound	<= 18'sb0;
			MIXED_SOUND			<= 16'sb0;
			
		end
		else begin
			if (SAMPLE_ENABLE) begin
				first_sum_sound 	<= 17'(SHAPED_SOUND_V1) + 17'(SHAPED_SOUND_V2); 	// Extend to 17 bit 
				second_sum_sound 	<= 17'(SHAPED_SOUND_V3) + 17'(SHAPED_SOUND_V4);
			
				total_sum_sound 	<= 18'(first_sum_sound) + 18'(second_sum_sound);	// Extend to 18 bit
			
				MIXED_SOUND			<= 16'(total_sum_sound >>> 2);							// Compress to 16 bit
			end
		end
	end
endmodule