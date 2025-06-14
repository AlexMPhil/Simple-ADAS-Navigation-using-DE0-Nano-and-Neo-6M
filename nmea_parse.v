`timescale 1ns/1ps

module nmea_parse(
	input wire clk,
	input wire rst,
	input wire [7:0] char,
	input wire valid,
	output reg NSR,
	output reg [4:0] hr,
	output reg [5:0] min,
	output reg [5:0] sec
);
	
	localparam IDLE = 3'd0;
	localparam HEADERVIA = 3'd1;
	localparam HEADER = 3'd2;
	localparam CAPTURE = 3'd3;
	localparam PARSER = 3'd4;
	localparam DONE = 3'd5;
	
	reg [7:0] RMC_HEADER[0:5];
	reg [2:0] state, next_state;
	
	// Buffers
	
	reg [7:0] nmea_buffer [0:127];
	reg [7:0] time_field [0:9];
	/*reg [7:0] copy_buffer [0:127];
	//reg [7:0] field_buffer1 [0:15];
	//reg [7:0] utime [0:7];
	reg [7:0] speed [0:5];
	reg [7:0] date [0:5];
	*/
	reg [6:0] buff_index;
	reg [3:0] comma_check;
	reg [3:0] t_index;
	reg [2:0] header_miss;
	
	reg [4:0] IST_hr;
	reg [5:0] IST_min;
	
	reg header_check;
	integer i=0;
	
	initial begin
    RMC_HEADER[0] = 8'h47;
	 RMC_HEADER[1] = 8'h50;
    RMC_HEADER[2] = 8'h52;
    RMC_HEADER[3] = 8'h4D;
    RMC_HEADER[4] = 8'h43;
    RMC_HEADER[5] = 8'h2C; 
	end
	
	always @(posedge clk or negedge rst) begin
		if (!rst) begin
			state <= IDLE;
		end else begin
			state <= next_state;
		end
	end
	
	always @(*) begin
		//next_state <= state;
		case(state)
			IDLE: if (valid && char== 8'h24) next_state = HEADERVIA;
			HEADERVIA: next_state = HEADER;
			HEADER: begin
				if (header_check) next_state = CAPTURE;
				else if (header_miss >= 3) next_state = IDLE;
			end
			CAPTURE: if (comma_check == 2) next_state = PARSER;
			PARSER: if (t_index == 6) next_state = DONE;
			DONE: next_state = IDLE;
			default: next_state = IDLE;
		endcase
	end
	
	always @(posedge clk or negedge rst) begin
	$display("TIME=%0t STATE=%0d CHAR=%c VALID=%b", $time, state, char, valid);
		if (!rst) begin
			buff_index <= 0;
			comma_check <= 0;
			header_check <= 0;
			t_index <= 0;
			hr <=0;
			min <= 0;
			sec <= 0;
			NSR <=0;
		end else begin
			case(state)
				IDLE: begin
					buff_index <= 0;
					comma_check <= 0;
					header_check <= 0;
					t_index <= 0;
					header_miss = 0;
					NSR <= 0;
				end
				
				HEADER: begin
					$display("RMC_HEADER[buff_index]=%0h CHAR=%0h VALID=%b", RMC_HEADER[buff_index], char, valid);
					if (valid && buff_index < 5) begin
						if (char == RMC_HEADER[buff_index]) begin
							buff_index <= buff_index + 1;
							header_miss <= 0;
							if (buff_index == 4) header_check <= 1;
						end else begin
							header_miss <= header_miss + 1;
							buff_index <= 0;
						end
					end
				end
				
				CAPTURE: begin
					if (valid) begin
						$display("char=%c comma=%0d t_index=%0d", char, comma_check, t_index);
						if (char == 8'h2C) begin
							comma_check <= comma_check + 1;
							$display("comma +1");
						end else if (comma_check == 1 && t_index < 6) begin    //comma_check==1 means time field
							time_field[t_index] <= char;
							t_index <= t_index + 1;
							
							$display("char=%c comma=%d t_index=%d time_field[%0d]=%c", char, comma_check, t_index, t_index, char);

						end
					end
				end
				
				PARSER: begin
					//Time Field analysis
					hr <= (time_field[0] - "0") * 10 + (time_field[1] - "0");
					min <= (time_field[2] - "0") * 10 + (time_field[3] - "0");
					sec <= (time_field[4] - "0") * 10 + (time_field[5] - "0");
					
					//GPS time will be in UTC, IST = UTC + 5:30
					/*
					IST_min = min + 30;
					if (IST_min >= 60) begin
						IST_min = IST_min - 60;
						IST_hr = hr + 6;  // 5 for IST and 1 for carry over
					end
					else begin
						IST_hr = hr + 5;
					end
					if (IST_hr >= 24) begin
						IST_hr = IST_hr - 24;
					end
					
					hr <= IST_hr;
					min <=IST_min;
					*/ 
				end
				
				DONE: begin
					NSR <= 1;
				end
				
			endcase
		end
	end
	
endmodule
