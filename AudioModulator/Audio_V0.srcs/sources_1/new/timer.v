`timescale 1ns / 1ns

module timer #(
    parameter CLOCK_PERIOD = 10,  // 100 MHz
    parameter TIME_NS      = 10_000
)(
    input 	   clk_i,
    input 	   reset_i,
	input 	   active_i,
    output     done_o
);  

    localparam COUNT_MAX 	= TIME_NS / CLOCK_PERIOD;
    reg [$clog2(COUNT_MAX+1) : 0] counter;
    
    // Clock divider counter
    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i)
            counter  <= 'b0;
        else if(active_i & ~done_o)
            counter  <= counter + 1;
    end

    assign done_o = (counter == COUNT_MAX);

endmodule