`timescale 1ns / 1ns

module audio_i2s #(
	parameter TP = 1
)(
	input 	            reset_i,
	
	input 	            reg_clk_i,
	input               reg_wea_i,
	input [4-1 : 0]     reg_addr_i,
	input [32-1 : 0]    reg_value_i,
			  
    input               bclk_10x,
    input               ac_adc_sdata,
    output              ac_dac_sdata,
    output 	            ac_bclk,
    output 	            ac_lrclk,
    
    output              new_sample_o,
    output [24-1 : 0]   sample_left_o,
    output [24-1 : 0]   sample_right_o
);  

localparam ADDR_WIDTH = 17;

// Clock signals
wire 			lrclk_clk_raw;
wire 			lrclk_pulse_raw;
reg [5-1 : 0]   lrclk_clk_delay;
reg [5-1 : 0]   lrclk_pulse_delay;
wire 			lrclk_pulse;

wire   			bclk_clk;
wire   			bclk_pulse;

// Register block
reg [32-1 : 0] reg_block [0 : 16-1];

// Audio signals
reg  [64-1 : 0]         input_sh_reg;
reg signed [24-1 : 0]   read_data_left;
reg signed [24-1 : 0]   read_data_right;
reg  [48-1 : 0]         mixer_chanel;

reg  [ADDR_WIDTH-1 : 0] write_ptr;
reg  [ADDR_WIDTH-1 : 0] read_ptr_left;
reg  [ADDR_WIDTH-1 : 0] read_ptr_right;
wire [48-1 : 0]         buffer_output;
reg  [64-1 : 0]         output_sh_reg;

wire [32-1 : 0] attenuator_left_ch_o;
wire [32-1 : 0] attenuator_right_ch_o;

wire [32-1 : 0] low_pass_left_ch_d;
wire [32-1 : 0] low_pass_right_ch_d;
wire [32-1 : 0] low_pass_left_ch_o;
wire [32-1 : 0] low_pass_right_ch_o;

wire [32-1 : 0] high_pass_left_ch_d;
wire [32-1 : 0] high_pass_right_ch_d;
wire [32-1 : 0] high_pass_left_ch_o;
wire [32-1 : 0] high_pass_right_ch_o;

wire [32-1 : 0] band_pass_left_ch_d;
wire [32-1 : 0] band_pass_right_ch_d;
wire [32-1 : 0] band_pass_left_ch_o;
wire [32-1 : 0] band_pass_right_ch_o;

wire [32-1 : 0] band_stop_left_ch_o;
wire [32-1 : 0] band_stop_right_ch_o;

wire signed [24-1:0] threshold;
wire [24-1 : 0] distorsion_left_ch_o;
wire [24-1 : 0] distorsion_right_ch_o;

wire [32-1 : 0] tremolo_left_ch_o;
wire [32-1 : 0] tremolo_right_ch_o;

assign new_sample_o   = lrclk_pulse;
assign sample_left_o  = buffer_output[48-1 : 24];
assign sample_right_o = buffer_output[24-1 : 0];


// REGISTER BLOCK
always @(posedge reg_clk_i or posedge reset_i) begin
    if(reset_i) begin
        reg_block[0]  <= #TP 32'h0000_0001;  // Mixer select
        reg_block[1]  <= #TP 32'h3FFF_FFFF;  // Volume left
        reg_block[2]  <= #TP 32'h3FFF_FFFF;  // Volume right
        reg_block[3]  <= #TP 32'h1d7b_9a90;  // LPF frequency
        reg_block[4]  <= #TP 32'h6237_c54f;  // HPF frequency
        reg_block[5]  <= #TP 32'h1d7b_9a90;  // BPF low frequency
        reg_block[6]  <= #TP 32'h6237_c54f;  // BPF high frequency
        reg_block[7]  <= #TP 32'h7ba3_751d;  // BSF frequency
        reg_block[8]  <= #TP 32'd11;  		 // Distorsion
        reg_block[9]  <= #TP 32'h0000_0576;  // Tremolo frequency
        reg_block[10] <= #TP 32'h0000_0000;  // Delay amount left
        reg_block[11] <= #TP 32'h0000_0000;  // Delay amount right
        reg_block[12] <= #TP 32'h0000_0000;  // Unused
        reg_block[13] <= #TP 32'h0000_0000;  // Unused
        reg_block[14] <= #TP 32'h0000_0000;  // Unused
        reg_block[15] <= #TP 32'h0000_0000;  // Unused
    end else if(reg_wea_i)
        reg_block[reg_addr_i] <= #TP reg_value_i;
end


// AUDIO DATA PATH
// I2S data input
always @(posedge bclk_10x or posedge reset_i) begin
	if(reset_i)
		input_sh_reg <= #TP 'b0;
	else if(bclk_pulse)
		input_sh_reg <= #TP {input_sh_reg[64-2 : 0], ac_adc_sdata};
end

always @(posedge bclk_10x or posedge reset_i) begin
	if(reset_i) begin
		read_data_left  <= #TP 'b0;
		read_data_right <= #TP 'b0;
	end else if(lrclk_pulse) begin
		read_data_left  <= #TP input_sh_reg[62 : 39];
		read_data_right <= #TP input_sh_reg[30 : 7];
	end
end


// Modulator blocks


// Mixer
always @(*) begin
	if(reg_block[0] == 32'd0)
		mixer_chanel <= #TP {read_data_left, read_data_right};
	else if(reg_block[0] == 32'd1)
		mixer_chanel <= #TP {low_pass_left_ch_o[32-1 : 8], low_pass_right_ch_o[32-1 : 8]};
	else if(reg_block[0] == 32'd2)
		mixer_chanel <= #TP {high_pass_left_ch_o[32-1 : 8], high_pass_right_ch_o[32-1 : 8]};
	else if(reg_block[0] == 32'd3)
		mixer_chanel <= #TP {band_pass_left_ch_o[32-1 : 8], band_pass_right_ch_o[32-1 : 8]};
	else if(reg_block[0] == 32'd4)
		mixer_chanel <= #TP {band_stop_left_ch_o[32-1 : 8], band_stop_right_ch_o[32-1 : 8]};
	else if(reg_block[0] == 32'd5)
		mixer_chanel <= #TP {distorsion_left_ch_o, distorsion_right_ch_o};
	else if(reg_block[0] == 32'd6)
		mixer_chanel <= #TP {tremolo_left_ch_o[32-1 : 8], tremolo_right_ch_o[32-1 : 8]};
    else
		mixer_chanel <= #TP {read_data_left, read_data_right};
end


// Volume filter
attenuation_filter #(
	.TP			    (1						        )
) attenuation_filter_inst (             
	.clk_i     	    (bclk_10x	  			        ),
	.reset_i        (reset_i      			        ),
            
	.new_bit_i	    (bclk_pulse			        	),
	.new_sample_i	(lrclk_pulse			        ),
	
	.volume_left_i	(reg_block[1] 				    ),
	.volume_right_i	(reg_block[2] 				    ),
	
	.left_ch_i      ({mixer_chanel[48-1 : 24], 8'b0}),
	.right_ch_i     ({mixer_chanel[24-1 : 0],  8'b0}),
	
	.left_ch_o      (attenuator_left_ch_o           ),
	.right_ch_o     (attenuator_right_ch_o          )
);


// Audio L/R buffers
blk_mem_gen_0 audio_buffer_left (
	.clka   (bclk_10x     					),
	.wea    (lrclk_pulse  					),
	.addra  (write_ptr    					),
	.dina   (attenuator_left_ch_o[32-1 : 8]	),
	
	.clkb   (bclk_10x     					),
	.addrb  (read_ptr_left    				),
	.doutb  (buffer_output[48-1 : 24]   	)
);	
	
blk_mem_gen_0 audio_buffer_righ (	
	.clka   (bclk_10x     					),
	.wea    (lrclk_pulse  					),
	.addra  (write_ptr    					),
	.dina   (attenuator_right_ch_o[32-1 : 8]),
	
	.clkb   (bclk_10x     					),
	.addrb  (read_ptr_right    				),
	.doutb  (buffer_output[24-1 : 0]    	)
);

always @(posedge bclk_10x or posedge reset_i) begin
	if(reset_i) begin
		write_ptr 	   <= #TP 'b0;
		read_ptr_left  <= #TP 'b0;
		read_ptr_right <= #TP 'b0;
	end else if(lrclk_pulse) begin
		write_ptr 	   <= #TP write_ptr + 1'b1;
		read_ptr_left  <= #TP write_ptr - reg_block[10];
		read_ptr_right <= #TP write_ptr - reg_block[11];
	end
end


// I2S data output
always @(posedge bclk_10x or posedge reset_i) begin
	if(reset_i)
		output_sh_reg <= #TP 'b0;
	else if(lrclk_pulse)
		output_sh_reg <= #TP {1'b0, buffer_output[48-1 : 24], 8'b0, buffer_output[24-1 : 0], 7'b0};
	else if(bclk_pulse)
		output_sh_reg <= #TP {output_sh_reg[64-2 : 0], 1'b0};
end
assign ac_dac_sdata = output_sh_reg[63];


// MODULATOR BLOCKS
// Low-pass filter
low_pass_filter #(
	.TP				(1						)
) low_pass_filter_inst1 (     
	.clk_i     		(bclk_10x	  			),
	.reset_i    	(reset_i      			),
	
	.new_bit_i	    (bclk_pulse			    ),
	.new_sample_i	(lrclk_pulse			),
	.a_i			(reg_block[3] 			),
		
	.left_ch_i  	({read_data_left, 8'b0 }),
	.right_ch_i 	({read_data_right, 8'b0}),
		
	.left_ch_o  	(low_pass_left_ch_d     ),
	.right_ch_o 	(low_pass_right_ch_d   	)
);

low_pass_filter #(
	.TP				(1						)
) low_pass_filter_inst2 (     
	.clk_i     		(bclk_10x	  			),
	.reset_i    	(reset_i      			),
	
	.new_bit_i	    (bclk_pulse			    ),
	.new_sample_i	(lrclk_pulse			),
	.a_i			(reg_block[3] 			),
		
	.left_ch_i  	(low_pass_left_ch_d		),
	.right_ch_i 	(low_pass_right_ch_d	),
		
	.left_ch_o  	(low_pass_left_ch_o     ),
	.right_ch_o 	(low_pass_right_ch_o   	)
);


// High-pass filter
high_pass_filter #(
	.TP				(1						)
) high_pass_filter_inst1 (     
	.clk_i     		(bclk_10x	  			),
	.reset_i    	(reset_i      			),
	
	.new_bit_i	    (bclk_pulse			    ),
	.new_sample_i	(lrclk_pulse			),
	.a_i			(reg_block[4] 			),
	
	.left_ch_i  	({read_data_left, 8'b0 }),
	.right_ch_i 	({read_data_right, 8'b0}),
		
	.left_ch_o  	(high_pass_left_ch_d    ),
	.right_ch_o 	(high_pass_right_ch_d   )
);

high_pass_filter #(
	.TP				(1						)
) high_pass_filter_inst2 (     
	.clk_i     		(bclk_10x	  			),
	.reset_i    	(reset_i      			),
	
	.new_bit_i	    (bclk_pulse			    ),
	.new_sample_i	(lrclk_pulse			),
	.a_i			(reg_block[4] 			),
	
	.left_ch_i  	(high_pass_left_ch_d	),
	.right_ch_i 	(high_pass_right_ch_d	),
		
	.left_ch_o  	(high_pass_left_ch_o    ),
	.right_ch_o 	(high_pass_right_ch_o   )
);


// Band-pass filter
low_pass_filter #(
	.TP				(1						)
) band_pass_filter_inst1 (     
	.clk_i     		(bclk_10x	  			),
	.reset_i    	(reset_i      			),
	
	.new_bit_i	    (bclk_pulse			    ),
	.new_sample_i	(lrclk_pulse			),
	.a_i			(reg_block[5] 			),
	
	.left_ch_i  	({read_data_left, 8'b0 }),
	.right_ch_i 	({read_data_right, 8'b0}),
		
	.left_ch_o  	(band_pass_left_ch_d    ),
	.right_ch_o 	(band_pass_right_ch_d   )
);

high_pass_filter #(
	.TP				(1						)
) band_pass_filter_inst2 (     
	.clk_i     		(bclk_10x	  			),
	.reset_i    	(reset_i      			),
	
	.new_bit_i	    (bclk_pulse			    ),
	.new_sample_i	(lrclk_pulse			),
	.a_i			(reg_block[6] 			),
	
	.left_ch_i  	(band_pass_left_ch_d	),
	.right_ch_i 	(band_pass_right_ch_d	),
					 
	.left_ch_o  	(band_pass_left_ch_o    ),
	.right_ch_o 	(band_pass_right_ch_o   )
);


// Band-stop filter
notch_filter #(
	.TP				(1						)
) notch_filter_inst1 (     
	.clk_i     		(bclk_10x	  			),
	.reset_i    	(reset_i      			),
	
	.new_bit_i	    (bclk_pulse			    ),
	.new_sample_i	(lrclk_pulse			),
	.a_i			(reg_block[7] 			),
	
	.left_ch_i  	({read_data_left, 8'b0 }),
	.right_ch_i 	({read_data_right, 8'b0}),
		
	.left_ch_o  	(band_stop_left_ch_o    ),
	.right_ch_o 	(band_stop_right_ch_o   )
);


// Distorsion
assign threshold = reg_block[8][24-1 : 0];
assign distorsion_left_ch_o  = (read_data_left  > threshold) ? threshold : ((read_data_left  < -threshold) ? -threshold : read_data_left);
assign distorsion_right_ch_o = (read_data_right > threshold) ? threshold : ((read_data_right < -threshold) ? -threshold : read_data_right);


// Tremolo - Amplitude modulation
tremolo_filter #(
	.TP				(1						)
) tremolo_filter_inst (     
	.clk_i     		(bclk_10x	  			),
	.reset_i    	(reset_i      			),
	
	.new_bit_i	    (bclk_pulse			    ),
	.new_sample_i	(lrclk_pulse			),
	.a_i			(reg_block[9] 			),
		
	.left_ch_i  	({read_data_left, 8'b0 }),
	.right_ch_i 	({read_data_right, 8'b0}),
		
	.left_ch_o  	(tremolo_left_ch_o    	),
	.right_ch_o 	(tremolo_right_ch_o   	)
);


// CLOCK GENERATION
// Clock divider to make I2S left/right clock frequency - 48 kHz
clock_divider #(
	.FREQ_IN    (30_720_000   		),
	.FREQ_OUT   (48_000       		)
) lrclk_generator (	          		        
	.clk_i     	(bclk_10x	  		),
	.reset_i    (reset_i      		),
	.clk_o      (lrclk_clk_raw		),
	.pulse_o    (lrclk_pulse_raw  	)
);

// Delay to sincronize lrclk with bclk
always @(posedge bclk_10x or posedge reset_i) begin
	if(reset_i) begin
		lrclk_clk_delay   <= #TP 'b0;
		lrclk_pulse_delay <= #TP 'b0;
	end else begin
		lrclk_clk_delay   <= #TP {lrclk_clk_delay[5-2 : 0], lrclk_clk_raw};
		lrclk_pulse_delay <= #TP {lrclk_pulse_delay[5-2 : 0], lrclk_pulse_raw};
	end
end
assign lrclk_pulse 	= lrclk_pulse_delay	[4];
assign ac_lrclk  	= ~lrclk_clk_delay	[4];


// Clock divider to make I2S bit clock frequency - 3.072 MHz = 48 kHz * 64
clock_divider #(
	.FREQ_IN    (30_720_000   	),
	.FREQ_OUT   (3_072_000    	)
) bclk_generator (	          	        
	.clk_i     	(bclk_10x	  	),
	.reset_i    (reset_i      	),
	.clk_o      (bclk_clk     	),
	.pulse_o    (bclk_pulse   	)
);

assign  ac_bclk  = ~bclk_clk;

endmodule