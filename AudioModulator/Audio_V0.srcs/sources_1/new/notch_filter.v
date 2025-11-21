`timescale 1ns / 1ns

module notch_filter #(
	parameter 		  		 TP = 1
)(		 
	input 			  		 clk_i,
	input 			  		 reset_i,
	
	input			  		 new_bit_i,
	input			  		 new_sample_i,
	input signed [32-1 : 0]  a_i,
	
	input signed [32-1 : 0]  left_ch_i,
	input signed [32-1 : 0]  right_ch_i,
	
	output reg signed [32-1 : 0] left_ch_o,
	output reg signed [32-1 : 0] right_ch_o
);

localparam signed [32-1 : 0] R = 32'h3000_0000;

reg [6-1 : 0] 		   tdm_counter;
reg  signed [32-1 : 0] a_d;
wire signed [32-1 : 0] audio_in;
reg  signed [32-1 : 0] audio_in_d;
wire signed [32-1 : 0] audio_prev_in_1;
reg  signed [32-1 : 0] audio_prev_in_1_d;
wire signed [32-1 : 0] audio_prev_in_2;
reg  signed [32-1 : 0] audio_prev_in_2_d;
wire signed [32-1 : 0] audio_prev_out_1;
reg  signed [32-1 : 0] audio_prev_out_1_d;
wire signed [32-1 : 0] audio_prev_out_2;
reg  signed [32-1 : 0] audio_prev_out_2_d;

reg signed [32-1 : 0] y_prev_left_1;
reg signed [32-1 : 0] y_prev_right_1;
reg signed [32-1 : 0] y_prev_left_2;
reg signed [32-1 : 0] y_prev_right_2;

reg signed [32-1 : 0] x_prev_left_1;
reg signed [32-1 : 0] x_prev_right_1;
reg signed [32-1 : 0] x_prev_left_2;
reg signed [32-1 : 0] x_prev_right_2;

reg signed [32-1 : 0] x_plus_x_prev2;
reg signed [64-1 : 0] a_mult_x_prev1;
reg signed [64-1 : 0] a_mult_R;
reg signed [64-1 : 0] R_mult_R;
reg signed [64-1 : 0] a_mult_R_mult_y_prev;
reg signed [64-1 : 0] R_mult_R_mult_y_prev;
reg signed [32-1 : 0] res1_minus_res2;
reg signed [32-1 : 0] res3_minus_res4;
reg signed [32-1 : 0] res5_plus_res6;


// Time Domanin Multiplexing
always @(posedge clk_i or posedge reset_i) begin
	if(reset_i)
		tdm_counter <= #TP 'b0;
	else if(new_sample_i)
		tdm_counter <= #TP 'b0;
	else if(new_bit_i)
		tdm_counter <= #TP tdm_counter + 'b1;
end

assign audio_in 	    = ~tdm_counter[5] ? left_ch_i   : right_ch_i;
assign audio_prev_in_1  = ~tdm_counter[5] ? x_prev_left_1 : x_prev_right_1;
assign audio_prev_in_2  = ~tdm_counter[5] ? x_prev_left_2 : x_prev_right_2;
assign audio_prev_out_1 = ~tdm_counter[5] ? y_prev_left_1 : y_prev_right_1;
assign audio_prev_out_2 = ~tdm_counter[5] ? y_prev_left_2 : y_prev_right_2;


// Input delay
always @(posedge clk_i) begin
    audio_in_d         <= #TP audio_in;
    audio_prev_in_1_d  <= #TP audio_prev_in_1;
    audio_prev_in_2_d  <= #TP audio_prev_in_2;
    audio_prev_out_1_d <= #TP audio_prev_out_1;
    audio_prev_out_2_d <= #TP audio_prev_out_2;
    a_d                <= #TP a_i;
end


// Filter equation
always @(posedge clk_i) begin
    x_plus_x_prev2	 	 <= #TP audio_in_d + audio_prev_in_2_d;
    a_mult_x_prev1	 	 <= #TP a_d * audio_prev_in_1_d;
    
    a_mult_R			 <= #TP a_d * R;
    R_mult_R			 <= #TP R * R;
    a_mult_R_mult_y_prev <= #TP (a_mult_R >>> 30) * audio_prev_out_1_d;
    R_mult_R_mult_y_prev <= #TP (R_mult_R >>> 30) * audio_prev_out_2_d;
    
    res1_minus_res2      <= #TP x_plus_x_prev2 - (a_mult_x_prev1 >>> 30);
    res3_minus_res4      <= #TP (a_mult_R_mult_y_prev >>> 30) - (R_mult_R_mult_y_prev >>> 30);
    res5_plus_res6		 <= #TP res1_minus_res2 + res3_minus_res4;
end


always @(posedge clk_i or posedge reset_i) begin
	if(reset_i) begin
		y_prev_left_1  <= #TP 'b0;
		y_prev_right_1 <= #TP 'b0;
		x_prev_left_1  <= #TP 'b0;
		x_prev_right_1 <= #TP 'b0;
		
		y_prev_left_2  <= #TP 'b0;
		y_prev_right_2 <= #TP 'b0;
		x_prev_left_2  <= #TP 'b0;
		x_prev_right_2 <= #TP 'b0;
	end else if(new_sample_i) begin
		y_prev_left_1  <= #TP left_ch_o;
		y_prev_right_1 <= #TP right_ch_o;
		x_prev_left_1  <= #TP left_ch_i;
		x_prev_right_1 <= #TP right_ch_i;
		
		y_prev_left_2  <= #TP y_prev_left_1;
		y_prev_right_2 <= #TP y_prev_right_1;
		x_prev_left_2  <= #TP x_prev_left_1;
		x_prev_right_2 <= #TP x_prev_right_1;
	end
end


always @(posedge clk_i or posedge reset_i) begin
	if(reset_i) begin
		left_ch_o  <= #TP 'b0;
		right_ch_o <= #TP 'b0;
	end else begin
		left_ch_o  <= #TP ~tdm_counter[5] ? res5_plus_res6 : left_ch_o;
		right_ch_o <= #TP  tdm_counter[5] ? res5_plus_res6 : right_ch_o;
	end
end

endmodule
