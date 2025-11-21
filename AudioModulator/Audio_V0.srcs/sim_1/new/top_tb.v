`timescale 1ns / 1ns

module top_tb();

localparam TP = 1;

reg  clk_i;
reg  reset_i;
reg start_i;

wire scl;
wire sda;

reg  ac_adc_sdata;
wire ac_dac_sdata;
wire ac_bclk;
wire ac_lrclk;
wire ac_mclk;

localparam [64-1 : 0] audio_value = {-24'd10, 8'b0, 24'd100, 8'b0};
//localparam [64-1 : 0] audio_value2 = {-24'd9, 8'b0, 24'd9, 8'b0};
integer i;

wire eth_rst_b;
wire eth_mdc;
wire eth_mdio;
pullup(eth_mdio);

wire eth_rxck;
wire eth_rxctl;
wire [4-1 : 0] eth_rxd;

wire eth_txck;
wire eth_txctl;
wire[4-1 : 0] eth_txd;

assign eth_rxck = eth_txck;
assign eth_rxctl = eth_txctl;
assign eth_rxd = eth_txd;

// Clock generator
initial begin
	clk_i <= 1'b0;
	forever begin
		#5 clk_i <= ~clk_i;
	end
end

initial begin
	// Initial values
	reset_i = 'b0;
 	ac_adc_sdata = 'b0;
	start_i = 'b0;

	// Reset
	#8000;
	repeat(2) @(posedge clk_i);
	reset_i = #TP 'b1;
	repeat(30) @(posedge clk_i);
	reset_i = #TP 'b0;
	repeat(20) @(posedge clk_i);
	
	@(posedge clk_i);
	start_i = #TP 'b1;
    
	repeat(10) begin                         
        @(negedge ac_lrclk);                 
        for (i = 63; i >= 0; i = i - 1) begin
            @(negedge ac_bclk);              
            ac_adc_sdata <= #TP audio_value[i];
        end             
        //for (i = 63; i >= 0; i = i - 1) begin
        //    @(negedge ac_bclk);              
        //    ac_adc_sdata <= #TP audio_value2[i];
        //end     
    end
	
//    @(negedge eth_rxctl);  
	#1_000;               
	$finish;
end

top DUV (
	.clk_i 			(clk_i			),
	
	.btnc 			(reset_i		),
	.btnl           (start_i        ),
	
	.scl 			(scl			),
	.sda 			(sda			),

	.ac_adc_sdata 	(ac_adc_sdata	),
	.ac_dac_sdata 	(ac_dac_sdata	),
	.ac_bclk 		(ac_bclk		),
	.ac_lrclk 		(ac_lrclk		),
	.ac_mclk 		(ac_mclk		),
	
	.eth_rst_b      (eth_rst_b      ),
	.eth_mdc        (eth_mdc        ),
	.eth_mdio       (eth_mdio       ),

	.eth_rxck       (eth_rxck       ),
	.eth_rxctl      (eth_rxctl      ),
	.eth_rxd        (eth_rxd        ),
	
	.eth_txck       (eth_txck       ),
	.eth_txctl      (eth_txctl      ),
	.eth_txd        (eth_txd        )
);

endmodule
