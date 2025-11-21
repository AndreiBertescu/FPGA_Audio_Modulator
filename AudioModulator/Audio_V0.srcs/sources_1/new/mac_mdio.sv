`timescale 1ns / 1ns

module mac_mdio #(
	parameter			TP = 1,
	parameter[5-1 : 0] 	PHY_ADDR = 5'b00001
)(
	input 		clk_i,
	input 		reset_i,
	output		busy_o,
    
	output 		eth_rst_b,
	output 		eth_mdc,
	inout 		eth_mdio
);

localparam 						ROM_LENGTH 		= 3;
localparam 						GAP_LENGTH 		= 3;
localparam 						FRAME_LENGTH 	= 64 + GAP_LENGTH;

// Program ROM
localparam logic [FRAME_LENGTH-1 : 0] PRG_MEM [0 : ROM_LENGTH] = '{
	{32'hFFFFFFFF, 2'b01, 2'b01, PHY_ADDR, 5'h09, 2'b10, 16'h00_00},  // GBCR reg - disable 1gbps advertisement
	//{32'hFFFFFFFF, 2'b01, 2'b01, PHY_ADDR, 5'h04, 2'b10, 16'h00_60},  // ANAR reg - disable 100mbps advertisement
	{32'hFFFFFFFF, 2'b01, 2'b01, PHY_ADDR, 5'h04, 2'b10, 16'h01_80},  // ANAR reg - disable 10mbps advertisement
	{32'hFFFFFFFF, 2'b01, 2'b01, PHY_ADDR, 5'h00, 2'b10, 16'h13_00},  // BMCR reg - normal operation - full duplex
	{64'hFFFFFFFFFFFFFFFF}	// Helper padding
};

reg[$clog2(ROM_LENGTH)-1 : 0] 	prg_counter;
reg[$clog2(FRAME_LENGTH)-1 : 0] frame_counter;
reg[FRAME_LENGTH-1 : 0] 		sh_reg;
wire 							eth_mdc_clock;
wire 							eth_mdc_pulse;
reg 							active;
wire							start_long;
assign 							eth_mdc = ~eth_mdc_clock;

wire 							mdio_in;
wire 							mdio_out;
wire 							mdio_en;
assign 							mdio_en = active & (frame_counter <= FRAME_LENGTH - GAP_LENGTH - 1);
assign 							mdio_in = sh_reg[FRAME_LENGTH - 1];

// Startup sequence signals
wire 							eth_reset_done;
wire 							eth_wait_done;
reg 							eth_wait_done_d;
assign 							eth_rst_b = eth_reset_done;


// Clock divider to make ethernet frequency
clock_divider #(
	.FREQ_IN    		(25_000_000   ),
	.FREQ_OUT   		(1_000_000    )
) clock_generator (	                  
	.clk_i     			(clk_i		  ),
	.reset_i    		(reset_i      ),
	.clk_o      		(eth_mdc_clock),
	.pulse_o      		(eth_mdc_pulse)
);


// Delay
always @(posedge clk_i or posedge reset_i) begin
	if(reset_i)
		eth_wait_done_d <= #TP 'b0;
	else if(eth_mdc_pulse)
		eth_wait_done_d <= #TP eth_wait_done;
end


// Flow control
always @(posedge clk_i or posedge reset_i) begin
	if(reset_i)
		active <= #TP 'b0;
	else if(eth_mdc_pulse) begin
		if(start_long)
			active <= #TP 'b1;
		else if((frame_counter == FRAME_LENGTH-1) & (prg_counter == ROM_LENGTH))
			active <= #TP 'b0;
	end
end

assign busy_o = ~eth_wait_done_d | active;
assign start_long = eth_wait_done & ~eth_wait_done_d;


// Program counters
always @(posedge clk_i or posedge reset_i) begin
	if(reset_i)
		prg_counter <= 'b0;
	else if(~active)
		prg_counter <= 'b0;
	else if(eth_mdc_pulse) begin
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
	else if(eth_mdc_pulse) begin
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
	else if(eth_mdc_pulse) begin
		if(start_long | frame_counter == FRAME_LENGTH-1)
			sh_reg <= {PRG_MEM[prg_counter], {GAP_LENGTH{1'b0}}};
		else
			sh_reg <= {sh_reg[FRAME_LENGTH-2 : 0], 1'b0};
	end
end


// MDIO tri-state buffer
IOBUF #(
	.DRIVE			(12			), 	// Specify the output drive strength
	.IBUF_LOW_PWR	("TRUE"		),  // Low Power - "TRUE", High Performance = "FALSE" 
	.IOSTANDARD		("DEFAULT"	), 	// Specify the I/O standard
	.SLEW			("SLOW"		) 	// Specify the output slew rate
) IOBUF_inst (
	.O				(mdio_out	),
	.IO				(eth_mdio	),
	.I				(mdio_in	),
	.T				(~mdio_en	) 
);


// Startup sequence timers
`ifdef SYNTHESYS
timer #(
	.CLOCK_PERIOD    	(40  			),
	.TIME_NS   			(20_000_000     )
) eth_reset_timer (	                  	
	.clk_i     			(clk_i		  	),
	.reset_i    		(reset_i      	),
	.active_i      		(1'b1		  	),
	.done_o      		(eth_reset_done	)
);

timer #(
	.CLOCK_PERIOD    	(40  			),
	.TIME_NS   			(50_000_000    	)
) eth_wait_timer (	                  
	.clk_i     			(clk_i		  	),
	.reset_i    		(reset_i      	),
	.active_i      		(eth_reset_done	),
	.done_o      		(eth_wait_done	)
);
`else
timer #(
	.CLOCK_PERIOD    	(40  			),
	.TIME_NS   			(1_000     		)
) eth_reset_timer (	                  	
	.clk_i     			(clk_i		  	),
	.reset_i    		(reset_i      	),
	.active_i      		(1'b1		  	),
	.done_o      		(eth_reset_done	)
);

timer #(
	.CLOCK_PERIOD    	(40  			),
	.TIME_NS   			(5_000    		)
) eth_wait_timer (	                  
	.clk_i     			(clk_i		  	),
	.reset_i    		(reset_i      	),
	.active_i      		(eth_reset_done	),
	.done_o      		(eth_wait_done	)
);
`endif

endmodule

