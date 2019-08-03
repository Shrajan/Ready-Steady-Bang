////////////////////////////////////////////////////////////////////////////////
 /*
 FPGA Project Name     : Ready Steady Bang
 Top level Entity Name : LT24Top
 Target Device		   : Cyclone V
 
 Code Authors          : Sanjith Chandran and Shrajan Bhandary 
 Date Created          : 20/04/2019 
 Location 			   : University of Leeds
 Module 			   : ELEC5566M FPGA Design for System-on-chip
 
 -------------------------------------------------------------------------------
 
 Description of the Verilog Module: 
	The module is the main control panel of the game. All the control inputs and 
	screen states are manipulated to create game-play.
 
 */
//////////////////////////////////////////////////////////////////////////////// 

/* ceil(log2(N)) Preprocessor Macro */
`define clog2(x) ( \
	((x) <= 2) ? 1 : \
	((x) <= 4) ? 2 : \
	((x) <= 8) ? 3 : \
	((x) <= 16) ? 4 : \
	((x) <= 32) ? 5 : \
	((x) <= 64) ? 6 : \
	((x) <= 128) ? 7 : \
	((x) <= 256) ? 8 : \
	((x) <= 512) ? 9 : \
	((x) <= 1024) ? 10 : \
	((x) <= 2048) ? 11 : \
	((x) <= 4096) ? 12 : 16)

module LT24Top # (
	
	parameter   PLAYER_ID			     = 1	   ,							// The ID is either 1 or 2 depending on the board that the program runs.
	parameter	INVERTED_INPUT   		 = 1       ,							// Parameter to select between active LOW ( Invert = 1 ) inputs and active HIGH ( Invert = 0 )inputs. 
	parameter	INVERTED_OUTPUT   		 = 1       ,							// Parameter to select between active LOW ( Invert = 1 ) outputs and active HIGH ( Invert = 0 )outputs.

	parameter	WINNING_SCORE			 = 5	   ,							// The game ends when either one of the player is the first to score the winning points.
	parameter	SCORE_ADDRESS_WIDTH		 = `clog2(WINNING_SCORE)        		// Determine the required width to of the scores.
	

)
(
    // Global Clock/Reset
    // - Clock
    input              clock,
    // - Global Reset
    input              globalReset,
	
	/* Game-play control inputs. */
	input 		game_touch_1_button									,			// The touch input on screen 1.
	input 		game_touch_2_button									,			// The touch input on screen 2.
	input 		game_up_button										,			// To switch between one player and two player version.
	input 		game_down_button									,			// To switch between one player and two player version.
	input 		game_select_button									,			// To select between one player or two player version.
	
	output reg	output_game_touch_button							,			// The touch input on screen 1.
	output 		output_game_up_button								,			// To switch between one player and two player version.
	output 		output_game_down_button								,			// To switch between one player and two player version.
	output 		output_game_select_button							,			// To select between one player or two player version.
	output      output_clock										,
	output      output_reset										,
	
    // - Application Reset - for debug
    output             resetApp,
	
	output			  [6:0]seven_segment_0,
	output			  [6:0]seven_segment_1,
	output			  [6:0]seven_segment_2,
	output			  [6:0]seven_segment_3,
	output			  [6:0]seven_segment_4,
	output			  [6:0]seven_segment_5,
    
    // LT24 Interface
    output             LT24Wr_n,
    output             LT24Rd_n,
    output             LT24CS_n,
    output             LT24RS,
    output             LT24Reset_n,
    output [     15:0] LT24Data,
    output             LT24LCDOn
);

	assign output_game_up_button = game_up_button;
	assign output_game_down_button = game_down_button;
	assign output_game_select_button = game_select_button;
	assign output_clock = clock;
	assign output_reset = globalReset;
	
	//
	// Local Variables
	//
	wire [ 7:0] xAddr;
	wire [ 8:0] yAddr;
	reg  [15:0] pixelData;
	wire        pixelReady;
	reg         pixelWrite;

	wire [15:0]	state_pixel_value;
	wire [4:0] state_value;
	
	wire [3:0] seven_segment_value_0;
	wire [3:0] seven_segment_value_1 = 4'b1011;
	wire [3:0] seven_segment_value_2 = 4'b1111;
	wire [3:0] seven_segment_value_3;
	wire [3:0] seven_segment_value_4 = 4'b1010;
	wire [3:0] seven_segment_value_5 = 4'b1111;
	
	
	
	wire [3:0] temp_score_1;
	wire [3:0] temp_score_2;
	
	Hex_Disp # (
		
		.INVERT_OUTPUT  ( INVERTED_OUTPUT )
	) SEVEN_SEGMENT_DISPLAY_0 	(
		
		.a	 ( seven_segment_value_0 ),
		.hex ( seven_segment_0	     )
	);
	
	Hex_Disp # (
		
		.INVERT_OUTPUT  ( INVERTED_OUTPUT )
	) SEVEN_SEGMENT_DISPLAY_1 	(
		
		.a	 ( seven_segment_value_1 ),
		.hex ( seven_segment_1	     )
	);
	
	Hex_Disp # (
		
		.INVERT_OUTPUT  ( INVERTED_OUTPUT )
	) SEVEN_SEGMENT_DISPLAY_2 	(
		
		.a	 ( seven_segment_value_2 ),
		.hex ( seven_segment_2	     )
	);
	
	Hex_Disp # (
		
		.INVERT_OUTPUT  ( INVERTED_OUTPUT )
	) SEVEN_SEGMENT_DISPLAY_3 	(
		
		.a	 ( seven_segment_value_3 ),
		.hex ( seven_segment_3	     )
	);
	
	Hex_Disp # (
		
		.INVERT_OUTPUT  ( INVERTED_OUTPUT )
	) SEVEN_SEGMENT_DISPLAY_4 	(
		
		.a	 ( seven_segment_value_4 ),
		.hex ( seven_segment_4	     )
	);
	
	Hex_Disp # (
		
		.INVERT_OUTPUT  ( INVERTED_OUTPUT )
	) SEVEN_SEGMENT_DISPLAY_5 	(
		
		.a	 ( seven_segment_value_5 ),
		.hex ( seven_segment_5	     )
	);
	
	//
	// LCD Display
	//
	localparam LCD_WIDTH  = 240;
	localparam LCD_HEIGHT = 320;

	LT24Display #(
		.WIDTH       (LCD_WIDTH  ),
		.HEIGHT      (LCD_HEIGHT ),
		.CLOCK_FREQ  (50000000   )
	) Display (
		.clock       (clock      ),
		.globalReset (globalReset),
		.resetApp    (resetApp   ),
		.xAddr       (xAddr      ),
		.yAddr       (yAddr      ),
		.pixelData   (pixelData  ),
		.pixelWrite  (pixelWrite ),
		.pixelReady  (pixelReady ),
		.pixelRawMode(1'b0       ),
		.cmdData     (8'b0       ),
		.cmdWrite    (1'b0       ),
		.cmdDone     (1'b0       ),
		.cmdReady    (           ),
		.LT24Wr_n    (LT24Wr_n   ),
		.LT24Rd_n    (LT24Rd_n   ),
		.LT24CS_n    (LT24CS_n   ),
		.LT24RS      (LT24RS     ),
		.LT24Reset_n (LT24Reset_n),
		.LT24Data    (LT24Data   ),
		.LT24LCDOn   (LT24LCDOn  )
	);

	//
	// X Counter
	//
	UpCounterNbit #(
		.WIDTH    (          8),
		.MAX_VALUE(LCD_WIDTH-1)
	) xCounter (
		.clock     (clock     ),
		.reset     (resetApp  ),
		.enable    (pixelReady),
		.countValue(xAddr     )
	);

	//
	// Y Counter
	//
	wire yCntEnable = pixelReady && (xAddr == (LCD_WIDTH-1));
	UpCounterNbit #(
		.WIDTH    (           9),
		.MAX_VALUE(LCD_HEIGHT-1)
	) yCounter (
		.clock     (clock     ),
		.reset     (resetApp  ),
		.enable    (yCntEnable),
		.countValue(yAddr     )
	);

	//
	// Pixel Write
	//
	always @ (posedge clock or posedge resetApp) begin
		if (resetApp) begin
			pixelWrite <= 1'b0;
		end else begin
			//In this example we always set write high, and use pixelReady to detect when
			//to update the data.
			pixelWrite <= 1'b1;
			//You could also control pixelWrite and pixelData in a State Machine.
		end
	end

	//
	// This is a simple test pattern generator.
	//
	// We create a different colour for each pixel based on 
	// the X-Y coordinate.
	//
	always @ (posedge clock or posedge resetApp) begin
		if (resetApp) 
			begin
				pixelData <= 16'b0;
			end 
		else if (pixelReady) 
			begin
				pixelData <= state_pixel_value;
			end
	end
	
	always @ ( posedge clock )
		begin
			
			if ( PLAYER_ID == 1 )
				begin 
					output_game_touch_button <= game_touch_1_button;
				end
			
			else if ( PLAYER_ID == 2 )
				begin 
					output_game_touch_button <= game_touch_2_button;
				end 
		end
	
	Game_Engine GAME_GENERATOR (
		
		.game_clock_in		 ( clock			     ),
		.game_reset_in		 ( ~globalReset	         ),
		.game_touch_1_button ( game_touch_1_button   ),
		.game_touch_2_button ( game_touch_2_button   ),		
		.game_up_button		 ( game_up_button	     ),		
		.game_down_button	 ( game_down_button      ),								
		.game_select_button	 ( game_select_button    ),
		.display_game_state  ( state_value		   	 ),
		.p_1_score			 ( seven_segment_value_3 ),
		.p_2_score			 ( seven_segment_value_0 )
	);	
	
	Video_Engine # 	          (
	
		.PLAYER_ID			  ( PLAYER_ID         )
		
	) VIDEO_GENERATOR         (
	
		.lcd_pixel_x_address  ( xAddr			  ),						
		.lcd_pixel_y_address  ( yAddr 			  ),					
		.game_states     	  ( state_value       ),					
		.lcd_pixel_data		  (	state_pixel_value )	
	);	
	
endmodule




