`timescale 1ns / 1ns

module audio_i2c #(
	parameter			TP = 1,
	parameter[7-1 : 0] 	I2C_ADDR = 7'b0111011
)(
	input 		        clk_i,
	input 		        reset_i,
	output		        busy_o,
            
	inout 		        scl,
	inout 		        sda
);

localparam ROM_LENGTH 		= 21;
localparam GAP_LENGTH 		= 3;
localparam FRAME_LENGTH 	= 38 + GAP_LENGTH;

// Program ROM - IN AUX - ADC - FPGA - DAC - OUT HEADPHONES
localparam logic [FRAME_LENGTH-1 : 0] PRG_MEM [0 : ROM_LENGTH] = '{
	{1'b0, I2C_ADDR, 1'b0, 1'b0, 8'h40, 1'b0, 8'h00, 1'b0, 8'b00000001, 2'b0},	//R0  - Activate core
	{1'b0, I2C_ADDR, 1'b0, 1'b0, 8'h40, 1'b0, 8'h17, 1'b0, 8'b00000000, 2'b0},	//R17 - Select sampling rate
																		
	{1'b0, I2C_ADDR, 1'b0, 1'b0, 8'h40, 1'b0, 8'h15, 1'b0, 8'b00000000, 2'b0},	//R15 - I2S control register 1
	{1'b0, I2C_ADDR, 1'b0, 1'b0, 8'h40, 1'b0, 8'h16, 1'b0, 8'b00000000, 2'b0},	//R16 - I2S control register 2
																		
	{1'b0, I2C_ADDR, 1'b0, 1'b0, 8'h40, 1'b0, 8'h19, 1'b0, 8'b00000011, 2'b0},	//R19 - ADC control & enable
	
	{1'b0, I2C_ADDR, 1'b0, 1'b0, 8'h40, 1'b0, 8'h0A, 1'b0, 8'b00000001, 2'b0},	//R4  - Enable L In Mixer in
	{1'b0, I2C_ADDR, 1'b0, 1'b0, 8'h40, 1'b0, 8'h0B, 1'b0, 8'b00000011, 2'b0},	//R5  - Enable Line in L input
	{1'b0, I2C_ADDR, 1'b0, 1'b0, 8'h40, 1'b0, 8'h0C, 1'b0, 8'b00000001, 2'b0},	//R6  - Enable R In Mixer in
	{1'b0, I2C_ADDR, 1'b0, 1'b0, 8'h40, 1'b0, 8'h0D, 1'b0, 8'b00000011, 2'b0},	//R7  - Enable Line in R input
																		
	{1'b0, I2C_ADDR, 1'b0, 1'b0, 8'h40, 1'b0, 8'h2A, 1'b0, 8'b00000011, 2'b0},	//R36 - DAC control & enable
	{1'b0, I2C_ADDR, 1'b0, 1'b0, 8'h40, 1'b0, 8'h1C, 1'b0, 8'b00100001, 2'b0},	//R22 - Enable L Mixer out
	{1'b0, I2C_ADDR, 1'b0, 1'b0, 8'h40, 1'b0, 8'h1E, 1'b0, 8'b01000001, 2'b0},	//R24 - Enable R Mixer out
	
	{1'b0, I2C_ADDR, 1'b0, 1'b0, 8'h40, 1'b0, 8'h2B, 1'b0, 8'b00100000, 2'b0},	//R37 - Left DAC volume attenuation
	{1'b0, I2C_ADDR, 1'b0, 1'b0, 8'h40, 1'b0, 8'h2C, 1'b0, 8'b00100000, 2'b0},	//R38 - Right DAC volume attenuation
																		
	{1'b0, I2C_ADDR, 1'b0, 1'b0, 8'h40, 1'b0, 8'h23, 1'b0, 8'b11100111, 2'b0},	//R29 - Headphone L volume control
	{1'b0, I2C_ADDR, 1'b0, 1'b0, 8'h40, 1'b0, 8'h24, 1'b0, 8'b11100111, 2'b0},	//R30 - Headphone R volume control
	
	{1'b0, I2C_ADDR, 1'b0, 1'b0, 8'h40, 1'b0, 8'h29, 1'b0, 8'b00000011, 2'b0},	//R35 - Playback channel enable
	{1'b0, I2C_ADDR, 1'b0, 1'b0, 8'h40, 1'b0, 8'hF2, 1'b0, 8'b00000001, 2'b0},	//R58 - DAC output control
	{1'b0, I2C_ADDR, 1'b0, 1'b0, 8'h40, 1'b0, 8'hF3, 1'b0, 8'b00000001, 2'b0},	//R59 - ADC input control

	{1'b0, I2C_ADDR, 1'b0, 1'b0, 8'h40, 1'b0, 8'hF9, 1'b0, 8'b01111111, 2'b0},	//R65 - Clock enable 1
	{1'b0, I2C_ADDR, 1'b0, 1'b0, 8'h40, 1'b0, 8'hFA, 1'b0, 8'b00000011, 2'b0},	//R66 - Clock enable 2
	{38{1'b1}}	// Helper padding
};


reg[$clog2(ROM_LENGTH)-1 : 0] 	prg_counter;
reg[$clog2(FRAME_LENGTH)-1 : 0] frame_counter;
reg[FRAME_LENGTH-1 : 0] 		sh_reg;
wire 							i2c_clock;
wire 							i2c_pulse;

reg 							active;
wire							start_long;
wire 							reset_done;
reg 							reset_done_d;

wire   							clk_enable;
wire   							data_enable;

wire 							sda_bit_rx;
wire 							sda_bit_tx;
wire 							scl_bit_rx;
wire 							scl_bit_tx;
assign 							sda_bit_tx = sh_reg[FRAME_LENGTH - 1] | ~data_enable;
assign 							scl_bit_tx = ~i2c_clock | ~clk_enable;


assign clk_enable  = active & (frame_counter < FRAME_LENGTH - GAP_LENGTH) & (frame_counter != 'd0);
assign data_enable = active & (frame_counter < FRAME_LENGTH - GAP_LENGTH) &
							  (frame_counter != 'd9)  &
							  (frame_counter != 'd18) &
							  (frame_counter != 'd27) &
							  (frame_counter != 'd36);


// Clock divider to make I2C frequency
clock_divider #(
	.FREQ_IN    		(25_000_000   ),
	.FREQ_OUT   		(100_000      )
) clock_generator (	                  
	.clk_i     			(clk_i		  ),
	.reset_i    		(reset_i      ),
	.clk_o      		(i2c_clock	  ),
	.pulse_o      		(i2c_pulse	  )
);


// Delay
always @(posedge clk_i or posedge reset_i) begin
	if(reset_i)
		reset_done_d <= #TP 'b0;
	else if(i2c_pulse)
		reset_done_d <= #TP reset_done;
end


// Flow control
always @(posedge clk_i or posedge reset_i) begin
	if(reset_i)
		active <= #TP 'b0;
	else if(i2c_pulse) begin
		if(start_long)
			active <= #TP 'b1;
		else if((frame_counter == FRAME_LENGTH-1) & (prg_counter == ROM_LENGTH))
			active <= #TP 'b0;
	end
end

assign busy_o = ~reset_done_d | active;
assign start_long = reset_done & ~reset_done_d;


// Program counters
always @(posedge clk_i or posedge reset_i) begin
	if(reset_i)
		prg_counter <= 'b0;
	else if(~active)
		prg_counter <= 'b0;
	else if(i2c_pulse) begin
		if(prg_counter == ROM_LENGTH)
			prg_counter <= 'b0;
		else if(frame_counter == FRAME_LENGTH-2)
			prg_counter <= prg_counter + 'd1;
	end
end

always @(posedge clk_i or posedge reset_i) begin
	if(reset_i)
		frame_counter <= 'b0;
	else if(~active)
		frame_counter <= 'b0;
	else if(i2c_pulse) begin
		if(frame_counter == FRAME_LENGTH-1)
			frame_counter <= 'b0;
		else
			frame_counter <= frame_counter + 'd1;
	end
end


// Shift register
always @(posedge clk_i or posedge reset_i) begin
	if(reset_i)
		sh_reg <= 'b0;
	else if (~active & ~start_long)
		sh_reg <= 'b0;
	else if(i2c_pulse) begin
		if(start_long | frame_counter == FRAME_LENGTH-1)
			sh_reg <= {PRG_MEM[prg_counter], {GAP_LENGTH{1'b0}}};
		else
			sh_reg <= {sh_reg[FRAME_LENGTH-2 : 0], 1'b0};
	end
end


// Startup sequence timers
`ifdef SYNTHESYS
timer #(
	.CLOCK_PERIOD   (10  			),
	.TIME_NS   		(10_000_000     )
) i2c_reset_timer (	              	
	.clk_i     		(clk_i		  	),
	.reset_i    	(reset_i      	),
	.active_i      	(1'b1		  	),
	.done_o      	(reset_done		)
);
`else
timer #(
	.CLOCK_PERIOD   (10  			),
	.TIME_NS   		(1_000     		)
) i2c_reset_timer (	              	
	.clk_i     		(clk_i		  	),
	.reset_i    	(reset_i      	),
	.active_i      	(1'b1		  	),
	.done_o      	(reset_done		)
);
`endif


// IO bi-directional buffers for sda and scl ports
IOBUF #(
	.DRIVE          (12         	),
	.IBUF_LOW_PWR   ("TRUE"     	),
	.IOSTANDARD     ("DEFAULT"  	),
	.SLEW           ("SLOW"     	) 
) IOBUF_sda (	
	.O              (sda_bit_rx 	),
	.IO             (sda        	),
	.I              (1'b0       	),
	.T              (sda_bit_tx 	)   // high=input, low=output
);	
	
IOBUF #(	
	.DRIVE          (12         	),
	.IBUF_LOW_PWR   ("TRUE"     	),
	.IOSTANDARD     ("DEFAULT"  	),
	.SLEW           ("SLOW"     	) 
) IOBUF_scl (	
	.O              (scl_bit_rx 	),
	.IO             (scl        	),
	.I              (1'b0       	),
	.T              (scl_bit_tx 	)   // high=input, low=output
);

endmodule
