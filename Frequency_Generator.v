////////////////////////////////////////////////////////////////////////////////
 /*
 FPGA Project Name     : Ready Steady Bang
 Top level Entity Name : Frequency_Generator
 Target Device		   : Cyclone V
 
 Code Authors          : Sanjith Chandran and Shrajan Bhandary 
 Date Created          : 19/04/2019 
 Location 			   : University of Leeds
 Module 			   : ELEC5566M FPGA Design for System-on-chip
 
 -------------------------------------------------------------------------------
 
 Description of the Verilog Module: 
	The module is used to reduce the incoming clock rate to a fixed value. 
	The fixed value is 2 Hz and the incoming clock rate is 50 MHz.
 
 */
//////////////////////////////////////////////////////////////////////////////// 

module Frequency_Generator #(													// Start of the module.

    /* Parameter List of the Frequency_Generator */
    parameter 	INCOMING_CLOCK_FREQUENCY  		= 50000000,						// The maximum operable frequency is set to 50 MHz.
	parameter 	INTERMEDIATE_CLOCK_FREQUENCY	= 100000,						// The intermediate operable frequency is set to 100 kHz.
	parameter 	FIXED_CLOCK_FREQUENCY    		= 10							// The fixed operable frequency is set to 10 Hz.
)(
	/* Port List of the Frequency_Generator */
    input     	clock_in,														// The incoming clock is connected to this port.	
    input       reset_in,														// The reset pin is connected to this port.
    output  	clock_out														// This provides the fixed clock rate depending upon the divider value.
);
	wire  clock_intermediate; 													// Since the input clock is quite large compared to the fixed clock frequency, the division is carried
																				// out in two stages.
	
	/* Instantiating the first frequency divider to reduce the complexity of the generator */
	Frequency_Divider # 	  	   (
		. INCOMING_CLOCK_FREQUENCY ( INCOMING_CLOCK_FREQUENCY	  ),
		. FIXED_CLOCK_FREQUENCY	   ( INTERMEDIATE_CLOCK_FREQUENCY )
	
	) FG_STAGE_1			  (
		. FD_CLOCK_IN		  ( clock_in	       ),
		. FD_RESET		  	  ( reset_in	       ),
		. FD_CLOCK_OUT     	  ( clock_intermediate )
	);
	
	/* Instantiating the second frequency divider to obtain the final fixed frequency */
	Frequency_Divider # 	  	   (
		. INCOMING_CLOCK_FREQUENCY ( INTERMEDIATE_CLOCK_FREQUENCY	  ),
		. FIXED_CLOCK_FREQUENCY	   ( FIXED_CLOCK_FREQUENCY			  )
	
	) FG_STAGE_2			  (
		. FD_CLOCK_IN		  ( clock_intermediate ),
		. FD_RESET		  	  ( reset_in	       ),
		. FD_CLOCK_OUT     	  ( clock_out		   )
	);
	
endmodule
