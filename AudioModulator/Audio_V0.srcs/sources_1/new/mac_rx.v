`timescale 1ns / 1ns

module mac_rx #(
	parameter			TP		    = 1,
	parameter[48-1 : 0] SRC_MAC     = 48'hFF_FF_FF_FF_FF_FF,  // Broadcast 
	parameter[48-1 : 0] DST_MAC     = 48'h02_01_02_03_04_05,  // 02_... - locally administered unicast
	parameter[16-1 : 0]	ETHERTYPE   = 16'h88B5 			  	  // Used for experimental packet types
)(
	input 				reset_i,
    
	input 				rx_clk_i,
    input[11-1 : 0]     rx_addr_i,
    output[8-1 : 0]     rx_data_o,
    
	input 				eth_rxck,
	input 				eth_rxctl,
	input[4-1 : 0] 		eth_rxd
);

localparam S_IDLE 			  = 4'b1000;
localparam S_READ_PREFRAME 	  = 4'b0100;
localparam S_READ_DATA 		  = 4'b0010;
localparam PREFRAME_LENGTH    = 6*8 + 6*8 + 2*8;
localparam PREFRAME_LENGTH_PR = PREFRAME_LENGTH + 7*8;

reg 						eth_rxctl_d;
reg 						eth_rxctl_dd;
reg [4-1 : 0] 		        eth_rxd_d;

reg [PREFRAME_LENGTH-1 : 0] input_sh_reg;
reg [24-1 : 0] 				nibble_ptr;
reg [4-1 : 0]   			state;
assign 						busy_o = (state != S_IDLE);

wire                        correct_id;
wire                        wea;
wire [11-1 : 0]             addr;
wire [8-1 : 0]              data;


// RX data buffer
blk_mem_gen_3 bram_rx_buffer (
	.clka   (eth_rxck   ),
	.wea    (wea        ),
	.addra  (addr       ),
	.dina   (data       ),
        
	.clkb   (rx_clk_i   ),
	.addrb  (rx_addr_i  ),
	.doutb  (rx_data_o  )
);

assign wea  = (state == S_READ_DATA);
assign addr = nibble_ptr[12-1 : 1];
assign data = input_sh_reg[8-1 : 0];


// Start signal delay
always @(posedge eth_rxck or posedge reset_i) begin
	if(reset_i) begin
		eth_rxctl_d <= #TP 'b0;
		eth_rxctl_dd <= #TP 'b0;
	end else begin
		eth_rxctl_d <= #TP eth_rxctl;
		eth_rxctl_dd <= #TP eth_rxctl_d;
	end
end


// State machine register
assign correct_id = (input_sh_reg[PREFRAME_LENGTH-1 -: 8*6]     == DST_MAC) 
                  & (input_sh_reg[PREFRAME_LENGTH-8*6-1 -: 8*6] == SRC_MAC) 
                  & (input_sh_reg[8*2-1 : 0] == ETHERTYPE);
                  
always @(posedge eth_rxck or posedge reset_i) begin
	if(reset_i)
		state <= S_IDLE;
	else begin
		if((state == S_IDLE) & (eth_rxctl_d & ~eth_rxctl_dd))
			state <= #TP S_READ_PREFRAME;
		else if(state == S_READ_PREFRAME  & nibble_ptr == PREFRAME_LENGTH_PR / 4 + 1)
			state <= #TP correct_id ? S_READ_DATA : S_IDLE;                                      
		else if(~eth_rxctl_d & eth_rxctl_dd)
			state <= #TP S_IDLE;   
	end
end
	
	
// Nibble pointer counter
always @(posedge eth_rxck or posedge reset_i) begin
	if(reset_i)
		nibble_ptr <= #TP 'b0;
	else begin
        if (state == S_IDLE | (state == S_READ_PREFRAME  & nibble_ptr == PREFRAME_LENGTH_PR / 4 + 1))
            nibble_ptr <= #TP 'b0;
        else
            nibble_ptr <= #TP nibble_ptr + 'b1;
    end
end


// RX shift register
always @(posedge eth_rxck or posedge reset_i) begin
	if(reset_i)
		input_sh_reg <= 'b0;
	else if(state == S_IDLE)
        input_sh_reg <= #TP 'b0;
    else if(nibble_ptr[0])
        input_sh_reg <= #TP {input_sh_reg[PREFRAME_LENGTH-8 : 0], eth_rxd, eth_rxd_d};
end

always @(posedge eth_rxck or posedge reset_i) begin
	if(reset_i)
		eth_rxd_d <= 'b0;
	else
        eth_rxd_d <= #TP eth_rxd;
end

endmodule