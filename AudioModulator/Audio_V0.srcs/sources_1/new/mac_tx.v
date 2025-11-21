`timescale 1ns / 1ns

module mac_tx #(
	parameter			TP		    = 1,
	parameter[48-1 : 0] SRC_MAC     = 48'h02_01_02_03_04_05,  // 02_... - locally administered unicast
	parameter[48-1 : 0] DST_MAC     = 48'hFF_FF_FF_FF_FF_FF,  // Broadcast 
	parameter[16-1 : 0]	ETHERTYPE   = 16'h88B5 			  	  // Used for experimental packet types
)(
	input 				reset_i,
    
	input[16-1 : 0]		data_length_i,  // MUST be >= 46*8
	input 				start_i,
	output 				busy_o,
    
	input 				tx_clk_i,
	input				tx_wea_i,
	input[11-1 : 0]		tx_addr_i,
	input[8-1 : 0]		tx_data_i,
    
    input  				eth_txck,
    output reg			eth_txctl,
    output reg[4-1 : 0] eth_txd
);

localparam S_IDLE 			 = 5'b10000;
localparam S_SEND_PREFRAME 	 = 5'b01000;
localparam S_SEND_DATA 		 = 5'b00100;
localparam S_SEND_POSTFRAME  = 5'b00010;
localparam S_TIMEOUT  	     = 5'b00001;
localparam PREFRAME_LENGTH   = 8*8 + 6*8 + 6*8 + 2*8;
localparam POSTFRAME_LENGTH  = 4*8;
localparam TIMEOUT_LENGTH	 = 12*8;

reg [11-1 : 0] 				data_addr;
wire[8-1 : 0] 				read_data;
reg [PREFRAME_LENGTH-1 : 0] preframe;
reg [4*8-1 : 0] 			postframe;

reg                         enable;
reg [8-1:0]                 crc_in;
wire[4*8-1 : 0]             crc_out;

reg [24-1 : 0] 				nibble_ptr;
reg [5-1 : 0]   			state;
wire 						eth_clk_pulse;
assign 						busy_o = (state != S_IDLE);


// TX data buffer
blk_mem_gen_2 bram_tx_buffer (
	.clka   (tx_clk_i     ),
	.wea    (tx_wea_i     ),
	.addra  (tx_addr_i    ),
	.dina   (tx_data_i    ),
	
	.clkb   (eth_txck     ),
	.addrb  (data_addr    ),
	.doutb  (read_data    )
);


// CRC-32 generator
crc32_parallel crc32_generator (
	.clk_i      (eth_txck   ),
	.reset_i    (reset_i    ),
	.enable_i   (enable     ),
	.clk_en     (~nibble_ptr[0]),
	.crc_i      (crc_in     ),
    .crc_o      (crc_out    )
);


// State machine register
always @(posedge eth_txck or posedge reset_i) begin
	if(reset_i)
		state <= S_IDLE;
	else begin
		if((state == S_IDLE) & start_i)
			state <= #TP S_SEND_PREFRAME;
		else if(state == S_SEND_PREFRAME  & nibble_ptr == PREFRAME_LENGTH  /4 - 1)
			state <= #TP S_SEND_DATA;                                      
		else if(state == S_SEND_DATA  	  & nibble_ptr == (data_length_i >> 2)  - 1)
			state <= #TP S_SEND_POSTFRAME;                                 
		else if(state == S_SEND_POSTFRAME & nibble_ptr == POSTFRAME_LENGTH /4 - 1)
			state <= #TP S_TIMEOUT;                                        
		else if(state == S_TIMEOUT 	      & nibble_ptr == TIMEOUT_LENGTH   /4 - 1)
			state <= #TP S_IDLE;
	end
end
	
	
// Nibble pointer counter
always @(posedge eth_txck or posedge reset_i) begin
	if(reset_i)
		nibble_ptr <= #TP 'b0;
	else if ( state == S_IDLE |
			(state == S_SEND_PREFRAME  & nibble_ptr == PREFRAME_LENGTH  /4 - 1) |
			(state == S_SEND_DATA 	   & nibble_ptr == (data_length_i >> 2)  - 1) |
			(state == S_SEND_POSTFRAME & nibble_ptr == POSTFRAME_LENGTH /4 - 1) |
			(state == S_TIMEOUT 	   & nibble_ptr == TIMEOUT_LENGTH   /4 - 1))
        nibble_ptr <= #TP 'b0;
    else
        nibble_ptr <= #TP nibble_ptr + 'b1;
end


// TX enable
always @(posedge eth_txck or posedge reset_i) begin
	if(reset_i)
		eth_txctl <= 'b0;
	else
        eth_txctl <= #TP (state != S_IDLE) & (state != S_TIMEOUT);
end

// TX shift register
always @(posedge eth_txck or posedge reset_i) begin
	if(reset_i)
		eth_txd <= 'b0;
	else begin
		if(state == S_SEND_PREFRAME)
			eth_txd <= #TP (nibble_ptr[0] == 0) ? preframe[PREFRAME_LENGTH - 5 -: 4] : preframe[PREFRAME_LENGTH - 1 -: 4];
		else if(state == S_SEND_DATA)
			eth_txd <= #TP (nibble_ptr[0] == 0) ? read_data[8 - 5 -: 4] : read_data[8 - 1 -: 4];
		else if(state == S_SEND_POSTFRAME)
            eth_txd <= #TP (nibble_ptr[0] == 0) ? postframe[POSTFRAME_LENGTH - 5 -: 4] : postframe[POSTFRAME_LENGTH - 1 -: 4];
		else
		    eth_txd <= #TP 'b0;
	end
end

// Preframe shift register
always @(posedge eth_txck or posedge reset_i) begin
	if(reset_i)
		preframe <= 'b0;
	else if((state == S_IDLE) & start_i)
        preframe <= #TP {64'h55555555555555D5, DST_MAC, SRC_MAC, ETHERTYPE};
    else if(nibble_ptr[0] == 1)
        preframe <= #TP {preframe[PREFRAME_LENGTH - 8 - 1 : 0], 8'b0};
end

// Data bram address
always @(posedge eth_txck or posedge reset_i) begin
	if(reset_i)
		data_addr <= 'b0;
	else if((state != S_SEND_DATA) & ~(state == S_SEND_PREFRAME & nibble_ptr == PREFRAME_LENGTH/4 - 1))
        data_addr <= #TP 'b0;
    else if(nibble_ptr[0] == 1)
        data_addr <= #TP data_addr + 'b1;
end

// Postframe shift register
always @(posedge eth_txck or posedge reset_i) begin
	if(reset_i)
		postframe <= 'b0;
	else if((state == S_SEND_DATA) & (nibble_ptr == (data_length_i >> 2) - 1))
        postframe <= #TP crc_out; //32'h3FFD267B crc_out
    else if(nibble_ptr[0] == 1)
        postframe <= #TP {postframe[POSTFRAME_LENGTH - 8 - 1 : 0], 8'b0};
end


// CRC control
always @(posedge eth_txck or posedge reset_i) begin
	if(reset_i)
		crc_in <= #TP 'hff;
	else if(state == S_SEND_PREFRAME)
        crc_in <= #TP preframe[PREFRAME_LENGTH - 1 -: 8];
    else if(state == S_SEND_DATA)
        crc_in <= #TP read_data;
    else 
        crc_in <= #TP 'hff;
end

always @(posedge eth_txck or posedge reset_i) begin
	if(reset_i)
		enable <= #TP 'b0;
	else if((state == S_IDLE) | (state == S_SEND_POSTFRAME))
        enable <= #TP 'b0;
    else if((state == S_SEND_PREFRAME) & (nibble_ptr >= 16))
        enable <= #TP 'b1;
end

endmodule