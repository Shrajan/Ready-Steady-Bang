/*
 * 4-Bit Hex Display
 * ----------------
 * By: Sanjy
 * For: University of Leeds
 * Date: 
 *
 * Description
 * -----------
 * The module is a simple 4-bit Hex Display
 *
 */
 
module Hex_Disp #(
    parameter INVERT_OUTPUT = 1  //Number of bits in adder (default 4)
)(
//Declare input and output ports for Full Adder
    input  [3:0] a,
    output reg [6:0] hex
 
);

always @ * begin
	if (INVERT_OUTPUT) begin
	case(a)
	//0
		4'b0000:hex = 7'b1000000;//7'b0111111;
	//1	
		4'b0001:hex = 7'b1111001;//7'b0000110;
	//2	
		4'b0010:hex = 7'b0100100;//7'b1011011;
	//3	
		4'b0011:hex = 7'b0110000;//7'b1001111;
	//4	
		4'b0100:hex = 7'b0011001;//7'b1100110;
	//5	
		4'b0101:hex = 7'b0010010;//7'b1101101;
	//6	
		4'b0110:hex = 7'b0000010;//7'b1111101;
	//7	
		4'b0111:hex = 7'b1111000;//7'b0000111;
	//8	
		4'b1000:hex = 7'b0000000;//7'b1111111;
	//9	
		4'b1001:hex = 7'b0010000;//7'b1101111;
	//A	
		4'b1010:hex = 7'b0001000;//7'b1110111;
	//B	
		4'b1011:hex = 7'b0000011;//7'b1111100;
	//C	
		4'b1100:hex = 7'b1000110;//7'b0111001;
	//D	
		4'b1101:hex = 7'b0100001;//7'b1011110;
	//E	
		4'b1110:hex = 7'b0000110;//7'b1111001;
	//F	
		4'b1111:hex = 7'b0001100;//7'b1110001;
	endcase
		end else begin
	case(a)
	//0
		4'b0000:hex = 7'b0111111;
	//1	
		4'b0001:hex = 7'b0000110;
	//2	
		4'b0010:hex = 7'b1011011;
	//3	
		4'b0011:hex = 7'b1001111;
	//4	
		4'b0100:hex = 7'b1100110;
	//5	
		4'b0101:hex = 7'b1101101;
	//6	
		4'b0110:hex = 7'b1111101;
	//7	
		4'b0111:hex = 7'b0000111;
	//8	
		4'b1000:hex = 7'b1111111;
	//9	
		4'b1001:hex = 7'b1101111;
	//A	
		4'b1010:hex = 7'b1110111;
	//B	
		4'b1011:hex = 7'b1111100;
	//C	
		4'b1100:hex = 7'b0111001;
	//D	
		4'b1101:hex = 7'b1011110;
	//E	
		4'b1110:hex = 7'b1111001;
	//F	
		4'b1111:hex = 7'b1110011;
	endcase
end
end

 endmodule
 
 