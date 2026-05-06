module voice_allocator(

		input logic CLK_50MHZ,
		input logic RST,

		input logic [11:0] BTN_STATE_BUS,
		input logic AGE_ENABLE,
		
		output logic [15:0] FREQ_V1,
		output logic [15:0] FREQ_V2,
		output logic [15:0] FREQ_V3,
		output logic [15:0] FREQ_V4,
		output logic GATE_V1,
		output logic GATE_V2,
		output logic GATE_V3,
		output logic GATE_V4
);

	// Music Notes Local Parameters
	localparam logic [3:0] A 			= 4'b0000; // La 
	localparam logic [3:0] ASharp   	= 4'b0001; // La#
	localparam logic [3:0] B			= 4'b0010; // Si
	localparam logic [3:0] C        	= 4'b0011; // Do
	localparam logic [3:0] CSharp		= 4'b0100; // Do#
	localparam logic [3:0] D   		= 4'b0101; // Re
	localparam logic [3:0] DSharp		= 4'b0110; // Re#
	localparam logic [3:0] E			= 4'b0111; // Mi
	localparam logic [3:0] F			= 4'b1000; // Fa
	localparam logic [3:0] FSharp   	= 4'b1001; // Fa#
	localparam logic [3:0] G			= 4'b1010; // Sol
	localparam logic [3:0] GSharp   	= 4'b1011;  // Sol#
	localparam logic [3:0] Empty    	= 4'b1100;  // Indicates that there is no note 
	
	// Internal Logic Signals
	logic [3:0] note_id;
	logic [15:0] freq_note; // 4th Octave was used as frequency values of notes
	logic [11:0] btn_state_old;
	logic [11:0] btn_pushed;
	logic [11:0] btn_released;
	logic [3:0]  note_channel [1:4]; // Array to Save Note Info for each Channel
	logic [15:0] note_age [0:3]; // Array to Save Note Age Info for each Channel
	logic [1:0]  oldest_note;
	logic gate_v1_signal;
	logic gate_v2_signal;
	logic gate_v3_signal;
	logic gate_v4_signal;
	
	// Initial Combinational Assignments
	assign btn_released 	= btn_state_old & ~(BTN_STATE_BUS); // Falling Edge of Button
	assign btn_pushed 	= BTN_STATE_BUS & ~(btn_state_old); // Rising Edge of Button
	assign GATE_V1 = gate_v1_signal; // Assignments to use Output as If Condition
	assign GATE_V2 = gate_v2_signal;
	assign GATE_V3 = gate_v3_signal;
	assign GATE_V4 = gate_v4_signal;
	
	// Frequency Values of Notes Lookup Table Combinational Block 
	always_comb
	begin
		case(note_id)
			A: 		freq_note = 16'b000110111000;
			ASharp:  freq_note = 16'b000111010010;
			B: 		freq_note = 16'b000111101110;
			C: 		freq_note = 16'b000100000110;
			CSharp:  freq_note = 16'b000100010101;
			D: 		freq_note = 16'b000100100110;
			DSharp:  freq_note = 16'b000100110111;
			E: 		freq_note = 16'b000101001010;
			F: 		freq_note = 16'b000101011101;
			FSharp:  freq_note = 16'b000101110010;
			G: 		freq_note = 16'b000110001000;
			GSharp:  freq_note = 16'b000110011111;
			Empty: 	freq_note = 16'b0;
			default: freq_note = 16'b0;
		endcase
	end 
	
	// 12-bit to 4-bit Encoder Combinational Block 
	always_comb
	begin
		note_id = Empty;
		for (int i=0; i<12 ;i++) begin
			if (btn_pushed[i] == 1'b1) begin 
				note_id = i[3:0]; 	
			end	
		end
	end
	
	// Oldest Note Comparator Combinational Block
	always_comb
	begin
		oldest_note = 2'b00;
		if (note_age[1] > note_age[oldest_note]) oldest_note = 2'b01;
		if (note_age[2] > note_age[oldest_note]) oldest_note = 2'b10;
		if (note_age[3] > note_age[oldest_note]) oldest_note = 2'b11;
	end
	
	// Button Pushed/Released Control Sequential Block
	always_ff @(posedge(CLK_50MHZ) or posedge(RST))
	begin
		if (RST) begin
			FREQ_V1 <= 16'b0;
			FREQ_V2 <= 16'b0;
			FREQ_V3 <= 16'b0;
			FREQ_V4 <= 16'b0;
			gate_v1_signal <= 1'b0;
			gate_v2_signal <= 1'b0;
			gate_v3_signal <= 1'b0;
			gate_v4_signal <= 1'b0;
	
		end
		else begin
			btn_state_old 	<= BTN_STATE_BUS;
			
			// Aging Mechanism
			if (AGE_ENABLE) begin
				 if (gate_v1_signal == 1'b1) note_age[0] <= note_age[0] + 1;
				 if (gate_v2_signal == 1'b1) note_age[1] <= note_age[1] + 1;
				 if (gate_v3_signal == 1'b1) note_age[2] <= note_age[2] + 1;
				 if (gate_v4_signal == 1'b1) note_age[3] <= note_age[3] + 1;
			end
			
			// Push Button Statement
			if (btn_pushed != 12'b0) begin
				if (gate_v1_signal == 1'b0) begin
					FREQ_V1 <= freq_note;
					gate_v1_signal <= 1'b1;
					note_channel[1] <= note_id;
					note_age[0] <= 16'b0;
				end
				else if 	(gate_v2_signal == 1'b0) begin
					FREQ_V2 <= freq_note;
					gate_v2_signal <= 1'b1;
					note_channel[2] <= note_id;
					note_age[1] <= 16'b0;
				end
				else if 	(gate_v3_signal == 1'b0) begin
					FREQ_V3 <= freq_note;
					gate_v3_signal <= 1'b1;
					note_channel[3] <= note_id;
					note_age[2] <= 16'b0;
				end
				else if 	(gate_v4_signal == 1'b0) begin 
					FREQ_V4 <= freq_note;
					gate_v4_signal <= 1'b1;
					note_channel[4] <= note_id;
					note_age[3] <= 16'b0;
				end
				else begin // Note Stealing
					if (oldest_note == 2'b00) begin 
						gate_v1_signal <= 1'b1;
						FREQ_V1 <= freq_note;
						note_channel[1] <= note_id;
						note_age[0] <= 16'b0;
					end
					else if (oldest_note == 2'b01) begin
						gate_v2_signal <= 1'b1;
						FREQ_V2 <= freq_note;
						note_channel[2] <= note_id;
						note_age[1] <= 16'b0;
					end
					else if (oldest_note == 2'b10) begin
						gate_v3_signal <= 1'b1;
						FREQ_V3 <= freq_note;
						note_channel[3] <= note_id;
						note_age[2] <= 16'b0;
					end
					else if (oldest_note == 2'b11) begin
						gate_v4_signal <= 1'b1;
						FREQ_V4 <= freq_note;
						note_channel[4] <= note_id;
						note_age[3] <= 16'b0;
					end
				end
			end
			
			// Release Button Statement
			if (btn_released != 12'b0) begin
				if ((gate_v1_signal == 1'b1) && (btn_released[note_channel[1]] == 1'b1)) begin
					gate_v1_signal <= 1'b0;
					note_channel[1] <= Empty;
				end
				if ((gate_v2_signal == 1'b1) && (btn_released[note_channel[2]] == 1'b1)) begin
					gate_v2_signal <= 1'b0;
					note_channel[2] <= Empty;
				end
				if ((gate_v3_signal == 1'b1) && (btn_released[note_channel[3]] == 1'b1)) begin
					gate_v3_signal <= 1'b0;
					note_channel[3] <= Empty;
				end
				if ((gate_v4_signal == 1'b1) && (btn_released[note_channel[4]] == 1'b1)) begin
					gate_v4_signal <= 1'b0;
					note_channel[4] <= Empty;
				end
			end
		end
	end
	
endmodule