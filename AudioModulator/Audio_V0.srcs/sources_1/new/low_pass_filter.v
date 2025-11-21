`timescale 1ns / 1ns

module low_pass_filter #(
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

reg [6-1 : 0] 		   tdm_counter;
reg  signed [32-1 : 0] a_d;
wire signed [32-1 : 0] audio_in;
reg  signed [32-1 : 0] audio_in_d;
wire signed [32-1 : 0] audio_prev_out;
reg  signed [32-1 : 0] audio_prev_out_d;

reg signed [32-1 : 0] y_prev_left;
reg signed [32-1 : 0] y_prev_right;

reg signed [32-1 : 0] x_plus_y;
reg signed [64-1 : 0] a_mult_x;
reg signed [64-1 : 0] a_mult_y;


// Time Domanin Multiplexing
always @(posedge clk_i or posedge reset_i) begin
	if(reset_i)
		tdm_counter <= #TP 'b0;
	else if(new_sample_i)
		tdm_counter <= #TP 'b0;
	else if(new_bit_i)
		tdm_counter <= #TP tdm_counter + 'b1;
end

assign audio_in 	  = ~tdm_counter[5] ? left_ch_i   : right_ch_i;
assign audio_prev_out = ~tdm_counter[5] ? y_prev_left : y_prev_right;


// Input delay
always @(posedge clk_i) begin
    audio_in_d       <= #TP audio_in;
    audio_prev_out_d <= #TP audio_prev_out;
    a_d              <= #TP a_i;
end


// Filter equation
always @(posedge clk_i) begin
    a_mult_x <= #TP 		          a_d  * audio_in_d;
    a_mult_y <= #TP (32'sh7FFF_FFFF - a_d) * audio_prev_out_d;
    x_plus_y <= #TP (a_mult_x  >>> 31) + (a_mult_y  >>> 31);
end


always @(posedge clk_i or posedge reset_i) begin
	if(reset_i) begin
		y_prev_left  <= #TP 'b0;
		y_prev_right <= #TP 'b0;
	end else if(new_sample_i) begin
		y_prev_left <=  #TP left_ch_o;
		y_prev_right <= #TP right_ch_o;
	end
end


always @(posedge clk_i or posedge reset_i) begin
	if(reset_i) begin
		left_ch_o  <= #TP 'b0;
		right_ch_o <= #TP 'b0;
	end else begin
		left_ch_o  <= #TP ~tdm_counter[5] ? x_plus_y : left_ch_o;
		right_ch_o <= #TP  tdm_counter[5] ? x_plus_y : right_ch_o;
	end
end

endmodule