`timescale 1ns / 1ns

module crc32_parallel #(
    parameter               TP = 1
)(
	input		            clk_i,
	input		            reset_i,
	input		            enable_i,
	input		            clk_en,
	input  [8-1  : 0]       crc_i,
    output [32-1 : 0]       crc_o
); 

reg  [31:0] crc_reg;
wire [31:0] next_crc_reg;


// Flow control
always@(posedge clk_i or posedge reset_i) begin
    if(reset_i) 
        crc_reg <= #TP 32'hFFFF_FFFF;
    else if(~enable_i)
        crc_reg <= #TP 32'hFFFF_FFFF;
    else if(clk_en)
        crc_reg <= #TP next_crc_reg; 
end

assign crc_o = ~{next_crc_reg[0],  next_crc_reg[1],  next_crc_reg[2],  next_crc_reg[3],
                 next_crc_reg[4],  next_crc_reg[5],  next_crc_reg[6],  next_crc_reg[7],
                 next_crc_reg[8],  next_crc_reg[9],  next_crc_reg[10], next_crc_reg[11],
                 next_crc_reg[12], next_crc_reg[13], next_crc_reg[14], next_crc_reg[15],
                 next_crc_reg[16], next_crc_reg[17], next_crc_reg[18], next_crc_reg[19],
                 next_crc_reg[20], next_crc_reg[21], next_crc_reg[22], next_crc_reg[23],
                 next_crc_reg[24], next_crc_reg[25], next_crc_reg[26], next_crc_reg[27],
                 next_crc_reg[28], next_crc_reg[29], next_crc_reg[30], next_crc_reg[31] };


// Calculate next CRC using its polynom
assign next_crc_reg[0]  = crc_reg[24] ^ crc_reg[30] ^ crc_i[7-0]   ^ crc_i[7-6]; 
assign next_crc_reg[1]  = crc_reg[24] ^ crc_reg[25] ^ crc_reg[30] ^ crc_reg[31] ^ crc_i[7-0] ^ crc_i[7-1] ^ crc_i[7-6] ^ crc_i[7-7]; 
assign next_crc_reg[2]  = crc_reg[24] ^ crc_reg[25] ^ crc_reg[26] ^ crc_reg[30] ^ crc_reg[31] ^ crc_i[7-0] ^ crc_i[7-1] ^ crc_i[7-2] ^ crc_i[7-6] ^ crc_i[7-7]; 
assign next_crc_reg[3]  = crc_reg[25] ^ crc_reg[26] ^ crc_reg[27] ^ crc_reg[31] ^ crc_i[7-1] ^ crc_i[7-2] ^ crc_i[7-3] ^ crc_i[7-7]; 
assign next_crc_reg[4]  = crc_reg[24] ^ crc_reg[26] ^ crc_reg[27] ^ crc_reg[28] ^ crc_reg[30] ^ crc_i[7-0] ^ crc_i[7-2] ^ crc_i[7-3] ^ crc_i[7-4] ^ crc_i[7-6]; 
assign next_crc_reg[5]  = crc_reg[24] ^ crc_reg[25] ^ crc_reg[27] ^ crc_reg[28] ^ crc_reg[29] ^ crc_reg[30] ^ crc_reg[31] ^ crc_i[7-0] ^ crc_i[7-1] ^ crc_i[7-3] ^ crc_i[7-4] ^ crc_i[7-5] ^ crc_i[7-6] ^ crc_i[7-7]; 
assign next_crc_reg[6]  = crc_reg[25] ^ crc_reg[26] ^ crc_reg[28] ^ crc_reg[29] ^ crc_reg[30] ^ crc_reg[31] ^ crc_i[7-1] ^ crc_i[7-2] ^ crc_i[7-4] ^ crc_i[7-5] ^ crc_i[7-6] ^ crc_i[7-7]; 
assign next_crc_reg[7]  = crc_reg[24] ^ crc_reg[26] ^ crc_reg[27] ^ crc_reg[29] ^ crc_reg[31] ^ crc_i[7-0] ^ crc_i[7-2] ^ crc_i[7-3] ^ crc_i[7-5] ^ crc_i[7-7]; 
assign next_crc_reg[8]  = crc_reg[0]  ^ crc_reg[24] ^ crc_reg[25] ^ crc_reg[27] ^ crc_reg[28] ^ crc_i[7-0] ^ crc_i[7-1] ^ crc_i[7-3] ^ crc_i[7-4]; 
assign next_crc_reg[9]  = crc_reg[1]  ^ crc_reg[25] ^ crc_reg[26] ^ crc_reg[28] ^ crc_reg[29] ^ crc_i[7-1] ^ crc_i[7-2] ^ crc_i[7-4] ^ crc_i[7-5]; 
assign next_crc_reg[10] = crc_reg[2]  ^ crc_reg[24] ^ crc_reg[26] ^ crc_reg[27] ^ crc_reg[29] ^ crc_i[7-0] ^ crc_i[7-2] ^ crc_i[7-3] ^ crc_i[7-5]; 
assign next_crc_reg[11] = crc_reg[3]  ^ crc_reg[24] ^ crc_reg[25] ^ crc_reg[27] ^ crc_reg[28] ^ crc_i[7-0] ^ crc_i[7-1] ^ crc_i[7-3] ^ crc_i[7-4]; 
assign next_crc_reg[12] = crc_reg[4]  ^ crc_reg[24] ^ crc_reg[25] ^ crc_reg[26] ^ crc_reg[28] ^ crc_reg[29] ^ crc_reg[30] ^ crc_i[7-0] ^ crc_i[7-1] ^ crc_i[7-2] ^ crc_i[7-4] ^ crc_i[7-5] ^ crc_i[7-6]; 
assign next_crc_reg[13] = crc_reg[5]  ^ crc_reg[25] ^ crc_reg[26] ^ crc_reg[27] ^ crc_reg[29] ^ crc_reg[30] ^ crc_reg[31] ^ crc_i[7-1] ^ crc_i[7-2] ^ crc_i[7-3] ^ crc_i[7-5] ^ crc_i[7-6] ^ crc_i[7-7]; 
assign next_crc_reg[14] = crc_reg[6]  ^ crc_reg[26] ^ crc_reg[27] ^ crc_reg[28] ^ crc_reg[30] ^ crc_reg[31] ^ crc_i[7-2] ^ crc_i[7-3] ^ crc_i[7-4] ^ crc_i[7-6] ^ crc_i[7-7]; 
assign next_crc_reg[15] = crc_reg[7]  ^ crc_reg[27] ^ crc_reg[28] ^ crc_reg[29] ^ crc_reg[31] ^ crc_i[7-3] ^ crc_i[7-4] ^ crc_i[7-5] ^ crc_i[7-7]; 
assign next_crc_reg[16] = crc_reg[8]  ^ crc_reg[24] ^ crc_reg[28] ^ crc_reg[29] ^ crc_i[7-0] ^ crc_i[7-4] ^ crc_i[7-5];
assign next_crc_reg[17] = crc_reg[9]  ^ crc_reg[25] ^ crc_reg[29] ^ crc_reg[30] ^ crc_i[7-1] ^ crc_i[7-5] ^ crc_i[7-6];
assign next_crc_reg[18] = crc_reg[10] ^ crc_reg[26] ^ crc_reg[30] ^ crc_reg[31] ^ crc_i[7-2] ^ crc_i[7-6] ^ crc_i[7-7];
assign next_crc_reg[19] = crc_reg[11] ^ crc_reg[27] ^ crc_reg[31] ^ crc_i[7-3] ^ crc_i[7-7]; 
assign next_crc_reg[20] = crc_reg[12] ^ crc_reg[28] ^ crc_i[7-4]; 
assign next_crc_reg[21] = crc_reg[13] ^ crc_reg[29] ^ crc_i[7-5]; 
assign next_crc_reg[22] = crc_reg[14] ^ crc_reg[24] ^ crc_i[7-0]; 
assign next_crc_reg[23] = crc_reg[15] ^ crc_reg[24] ^ crc_reg[25] ^ crc_reg[30] ^ crc_i[7-0] ^ crc_i[7-1] ^ crc_i[7-6];
assign next_crc_reg[24] = crc_reg[16] ^ crc_reg[25] ^ crc_reg[26] ^ crc_reg[31] ^ crc_i[7-1] ^ crc_i[7-2] ^ crc_i[7-7];
assign next_crc_reg[25] = crc_reg[17] ^ crc_reg[26] ^ crc_reg[27] ^ crc_i[7-2] ^ crc_i[7-3];              
assign next_crc_reg[26] = crc_reg[18] ^ crc_reg[24] ^ crc_reg[27] ^ crc_reg[28] ^ crc_reg[30] ^ crc_i[7-0] ^ crc_i[7-3] ^ crc_i[7-4] ^ crc_i[7-6]; 
assign next_crc_reg[27] = crc_reg[19] ^ crc_reg[25] ^ crc_reg[28] ^ crc_reg[29] ^ crc_reg[31] ^ crc_i[7-1] ^ crc_i[7-4] ^ crc_i[7-5] ^ crc_i[7-7]; 
assign next_crc_reg[28] = crc_reg[20] ^ crc_reg[26] ^ crc_reg[29] ^ crc_reg[30] ^ crc_i[7-2] ^ crc_i[7-5] ^ crc_i[7-6]; 
assign next_crc_reg[29] = crc_reg[21] ^ crc_reg[27] ^ crc_reg[30] ^ crc_reg[31] ^ crc_i[7-3] ^ crc_i[7-6] ^ crc_i[7-7]; 
assign next_crc_reg[30] = crc_reg[22] ^ crc_reg[28] ^ crc_reg[31] ^ crc_i[7-4] ^ crc_i[7-7]; 
assign next_crc_reg[31] = crc_reg[23] ^ crc_reg[29] ^ crc_i[7-5]; 
 
endmodule 
