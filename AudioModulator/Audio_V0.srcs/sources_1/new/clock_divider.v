`timescale 1ns / 1ns

module clock_divider #(
    parameter FREQ_IN    = 100_000_000,  // 100 MHz
    parameter FREQ_OUT   = 9600
)(
    input 	   clk_i,
    input 	   reset_i,
    output reg clk_o,
    output reg pulse_o
);  

    localparam COUNT_MAX = FREQ_IN / FREQ_OUT;
    reg [$clog2(COUNT_MAX)-1:0] counter;
    
    // Clock divider counter
    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i)
            counter  <= {$clog2(COUNT_MAX){1'b0}};
        else if (counter == COUNT_MAX - 1)
            counter  <= {$clog2(COUNT_MAX){1'b0}};
        else
            counter  <= counter + 1;
    end

    // Output clock signal
	always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            clk_o  	 <= 1'b0;
            pulse_o  <= 1'b0;
        end else begin
            clk_o  	 <= (counter >= COUNT_MAX/2);
            pulse_o  <= (counter == COUNT_MAX/2);
		end
    end

endmodule