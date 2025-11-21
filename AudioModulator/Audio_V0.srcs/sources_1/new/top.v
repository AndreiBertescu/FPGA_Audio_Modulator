`timescale 1ns / 1ns

module top(
    // 100 MHz clock
    input 	clk_i,	
    
	// Push buttons
    input 	btnc,
    input   btnl,
    
    // I2C
    inout 	scl,
    inout 	sda,
    
    // Audio codec
    input 	ac_adc_sdata,
    output  ac_dac_sdata,
    output 	ac_bclk,
    output 	ac_lrclk,
    output 	ac_mclk,
    
    // Ethernet
    output  eth_rst_b,
    output  eth_mdc,
    inout   eth_mdio,
    
    input   eth_rxck,
    input   eth_rxctl,
    input[4-1 : 0] eth_rxd,
    
    output  eth_txck,
    output  eth_txctl,
    output[4-1 : 0] eth_txd
);

localparam TP = 1;
localparam [16-1 : 0] TX_LENGTH = 1500; // Min. 46
    
wire            clk;
            
wire            mclk_locked;
wire            bclk_10x_locked;
wire            eth_txck_locked;

wire            reset_i;
wire 		 	bclk_reset;
reg [2 : 0] 	bclk_reset_FF;
wire 		 	eth_txck_reset;
reg [2 : 0] 	eth_txck_reset_FF;
wire 		 	eth_rxck_reset;
reg [2 : 0] 	eth_rxck_reset_FF;
assign          reset_i = ~(mclk_locked & bclk_10x_locked & eth_txck_locked) | btnc;

wire [8-1 : 0]  eth_rx_data;
reg  [32-1 : 0] reg_value;
reg  [11-1 : 0] reg_addr;
reg  [11-1 : 0] reg_addr_d;
reg  [11-1 : 0] reg_addr_dd;

wire                start_long;
wire                new_sample;
wire [24-1 : 0]     sample_left;
wire [24-1 : 0]     sample_right;
reg  [24*2 -1 : 0]  sample_sh_reg;
reg  [3-1 : 0]      sh_reg_counter;
reg  [11-1 : 0]     tx_ptr;

wire                tx_wea;
wire [11-1 : 0]     tx_addr;
wire [8-1 : 0]      tx_data;

// Reset structures
always @(posedge bclk_10x or posedge reset_i) begin
	if (reset_i) begin
		bclk_reset_FF <= #TP 3'h7;
	end else begin
		bclk_reset_FF <= #TP {bclk_reset_FF[1:0], 1'b0};
	end
end
assign bclk_reset = bclk_reset_FF[2];

always @(posedge eth_txck or posedge reset_i) begin
	if (reset_i) begin
		eth_txck_reset_FF <= #TP 3'h7;
	end else begin
		eth_txck_reset_FF <= #TP {eth_txck_reset_FF[1:0], 1'b0};
	end
end
assign eth_txck_reset = eth_txck_reset_FF[2];

always @(posedge eth_rxck_i or posedge reset_i) begin
	if (reset_i) begin
		eth_rxck_reset_FF <= #TP 3'h7;
	end else begin
		eth_rxck_reset_FF <= #TP {eth_rxck_reset_FF[1:0], 1'b0};
	end
end
assign eth_rxck_reset = eth_rxck_reset_FF[2];


// CLOCKING
// Buffer for input clock
BUFG BUFG_inst_clk (
  .I            (clk_i              ),
  .O            (clk                )
);

// Buffer for ethernet rx clock
BUFG BUFG_inst_eth (
  .I            (eth_rxck           ),
  .O            (eth_rxck_i         )
);

// Master clock generator - 12.288 MHz = 256 * 48 kHz
clk_wiz_0 mclk_generator(
    .clk_in1	(clk		  	    ),
    .locked		(mclk_locked  	    ),
    .clk_out1	(ac_mclk	  	    )
);

// Clock generator to make 10x the freq of left/right clock - 30.72 MHz
clk_wiz_1 bclk_10x_generator(
    .clk_in1	(clk		     	),
    .locked		(bclk_10x_locked 	),
    .clk_out1	(bclk_10x	     	)
);

// Clock generator for ethernet tx frequency - 25 MHz
clk_wiz_2 eth_txck_generator(
    .clk_in1	(clk		  	    ),
    .locked		(eth_txck_locked  	),
    .clk_out1	(eth_txck	  	    )
);


// Transfer of ethernet rx buffer to audio codec reg_block
always @(posedge bclk_10x or posedge bclk_reset) begin
	if(bclk_reset)
		reg_addr <= #TP 'b0;
	else if(reg_addr == 16*4)
		reg_addr <= #TP 'b0;
	else
		reg_addr <= #TP reg_addr + 'b1;
end

always @(posedge bclk_10x or posedge bclk_reset) begin
	if(bclk_reset) begin
		reg_addr_d  <= #TP 'b0;
		reg_addr_dd <= #TP 'b0;
    end else begin
        reg_addr_d  <= #TP reg_addr;
        reg_addr_dd <= #TP reg_addr_d;
    end
end

always @(posedge bclk_10x or posedge bclk_reset) begin
	if(bclk_reset)
		reg_value <= #TP 'b0;
    else
        reg_value <= #TP {reg_value[32-8-1 : 0], eth_rx_data};
end


// Transfer of audio codec to ethernet tx buffer
always @(posedge bclk_10x or posedge bclk_reset) begin
	if(bclk_reset)
		tx_ptr <= #TP 'b0;
	else if(tx_addr >= TX_LENGTH)
		tx_ptr <= #TP 'b0;
	else if(new_sample)
		tx_ptr <= #TP tx_ptr + 'd6;
end

always @(posedge bclk_10x or posedge bclk_reset) begin
	if(bclk_reset)
		sh_reg_counter <= #TP 'b0;
	else if(new_sample)
		sh_reg_counter <= #TP 'b0;
	else if(tx_wea)
		sh_reg_counter <= #TP sh_reg_counter + 'b1;
end

always @(posedge bclk_10x or posedge bclk_reset) begin
	if(bclk_reset)
		sample_sh_reg <= #TP 'b0;
    else if(new_sample)
        sample_sh_reg <= #TP {sample_left, sample_right};
    else if(tx_wea)
        sample_sh_reg <= #TP {sample_sh_reg[24*2 - 8 -1 : 0], 8'b0};
end

assign tx_wea  = sh_reg_counter < 6;	   
assign tx_addr = tx_ptr + sh_reg_counter;  
assign tx_data = sample_sh_reg[24*2-1 -: 8]; 

// Ethernet start CDC
 xpm_cdc_single #(
    .DEST_SYNC_FF   (2                      ), 
    .INIT_SYNC_FF   (1                      ), 
    .SIM_ASSERT_CHK (0                      ),
    .SRC_INPUT_REG  (1                      ) 
) xpm_cdc_single_inst (
    .src_clk        (bclk_10x               ),     
    .src_in         (tx_addr >= TX_LENGTH   ),
    
    .dest_clk       (eth_txck               ),    
    .dest_out       (start_long             )   
);


// AUDIO
// Audio codec
audio_i2s #(
	.TP				(TP				            )
) audio_i2s_inst(       
	.reset_i 		(bclk_reset		            ),
            
	.reg_clk_i 		(bclk_10x	                ),
	.reg_wea_i      (~|reg_addr_dd[2-1 : 0] & |reg_addr_dd[6-1 : 2]),
	.reg_addr_i     (reg_addr_dd[6-1 : 2] - 4'b1),
    .reg_value_i    (reg_value                  ),
                        
    .bclk_10x       (bclk_10x                   ),
	.ac_adc_sdata 	(ac_adc_sdata	            ),
	.ac_dac_sdata  	(ac_dac_sdata	            ),
	.ac_bclk 		(ac_bclk		            ),
	.ac_lrclk 		(ac_lrclk		            ),
        
    .new_sample_o   (new_sample                 ),
    .sample_left_o  (sample_left                ),
    .sample_right_o (sample_right               )
);

// Codec configurator - through I2C interface
audio_i2c #(
	.TP				(TP				)
) audio_i2c_inst(
	.clk_i 			(eth_txck	    ),
	.reset_i 		(eth_txck_reset	),
	.busy_o         (               ),

	.scl 			(scl			),
	.sda  			(sda			)
);


// ETHERNET
// Media access controller
mac_tx #(
	.TP				(TP					  ),
    .SRC_MAC		(48'h80_1F_12_CA_83_63),
    .DST_MAC		(48'hFF_FF_FF_FF_FF_FF),  // PC - hD8_43_AE_BC_DA_B9, Broadcast - hFF_FF_FF_FF_FF_FF
    .ETHERTYPE		(16'h88B5			  )
) mac_tx_inst(
	.reset_i 		(eth_txck_reset	      ),
    
	.data_length_i 	(TX_LENGTH * 16'd8	  ),  // MUST be >= 46*8
	.start_i 		(start_long       	  ),
	.busy_o  		(			          ),
            
	.tx_clk_i 		(bclk_10x		      ),
	.tx_wea_i		(tx_wea               ),
	.tx_addr_i		(tx_addr              ),
	.tx_data_i		(tx_data              ),
        
	.eth_txck 		(eth_txck	          ),
	.eth_txctl 		(eth_txctl	          ),
	.eth_txd 		(eth_txd	          )
);

mac_rx #(
	.TP				(TP					  ),
    .SRC_MAC		(48'hFF_FF_FF_FF_FF_FF),  // PC - hD8_43_AE_BC_DA_B9, Broadcast - hFF_FF_FF_FF_FF_FF
    .DST_MAC		(48'h80_1F_12_CA_83_63),
    .ETHERTYPE		(16'h88B5			  )
) mac_rx_inst(
	.reset_i 		(eth_rxck_reset	      ),
                                          
	.rx_clk_i 		(bclk_10x		      ),
	.rx_addr_i		(reg_addr	          ),
	.rx_data_o		(eth_rx_data          ),
                                          
	.eth_rxck 		(eth_rxck_i	          ),
	.eth_rxctl  	(eth_rxctl	          ),
	.eth_rxd 		(eth_rxd	          )
);

// PHY configurator - through MDIO interface
mac_mdio #(
	.TP				(TP				      )
) mac_mdio_inst(	      
	.clk_i 			(eth_txck			  ),
	.reset_i 		(eth_txck_reset		  ),
	.busy_o			( 				      ),
    
	.eth_rst_b		(eth_rst_b		      ),
	.eth_mdc 		(eth_mdc		      ),
	.eth_mdio  	    (eth_mdio		      )
);

endmodule
