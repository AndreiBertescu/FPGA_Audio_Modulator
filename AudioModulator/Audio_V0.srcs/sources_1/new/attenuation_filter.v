`timescale 1ns / 1ns

module attenuation_filter #(
	parameter 		         TP = 1
)(
	input 			  		 clk_i,
	input 			  		 reset_i,
	
	input			  		 new_bit_i,
	input			  		 new_sample_i,
	
	input signed [32-1 : 0]  volume_left_i,
	input signed [32-1 : 0]  volume_right_i,
	
	input signed [32-1 : 0]  left_ch_i,
	input signed [32-1 : 0]  right_ch_i,
	
	output reg signed [32-1 : 0] left_ch_o,
	output reg signed [32-1 : 0] right_ch_o
);

reg [6-1 : 0] 		   tdm_counter;
wire signed [32-1 : 0] audio_in;
reg  signed [32-1 : 0] audio_in_d;
wire signed [32-1 : 0] volume_in;
reg  signed [32-1 : 0] volume_in_d;

reg  signed [64-1 : 0] mult_result;


// Time Domanin Multiplexing
always @(posedge clk_i or posedge reset_i) begin
	if(reset_i)
		tdm_counter <= #TP 'b0;
	else if(new_sample_i)
		tdm_counter <= #TP 'b0;
	else if(new_bit_i)
		tdm_counter <= #TP tdm_counter + 'b1;
end

assign audio_in = ~tdm_counter[5] ? left_ch_i : right_ch_i;
assign volume_in = ~tdm_counter[5] ? volume_left_i : volume_right_i;


// Input delay
always @(posedge clk_i) begin
    audio_in_d  <= #TP audio_in;
    volume_in_d <= #TP volume_in;
end


// Filter equation
always @(posedge clk_i) begin
    mult_result <= #TP audio_in_d  * volume_in_d;
end


always @(posedge clk_i or posedge reset_i) begin
	if(reset_i) begin
		left_ch_o  <= #TP 'b0;
		right_ch_o <= #TP 'b0;
	end else begin
		left_ch_o  <= #TP ~tdm_counter[5] ? mult_result >>> 30 : left_ch_o;
		right_ch_o <= #TP  tdm_counter[5] ? mult_result >>> 30 : right_ch_o;
	end
end

endmodule