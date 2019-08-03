////////////////////////////////////////////////////////////////////////////////
 /*
 FPGA Project Name     : Ready Steady Bang
 Top level Entity Name : Game_Engine
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

module Game_Engine #(															// Start of the module.

    /* Parameter List of the Game_Engine */
    parameter 	INCOMING_CLOCK_FREQUENCY = 50000000,							// The frequency of the board is 50 MHz.
	parameter 	REDUCED_CLOCK_FREQUENCY	 = 10	   ,							// The fixed operable frequency is set to 2 Hz (Every clock cycle is 0.1 s long).
	
	parameter 	NO_GAME_STATES	 		 = 35	   ,							// The number of possible states (Screens).
	parameter 	STATE_ADDRESS_WIDTH		 = `clog2(NO_GAME_STATES),				// Number of bits required to store the different number of states.
	
	parameter	INVERTED_INPUT   		 = 1       ,							// Parameter to select between active LOW ( Invert = 1 ) inputs and active HIGH ( Invert = 0 )inputs. 
	parameter	INVERTED_OUTPUT   		 = 1       ,							// Parameter to select between active LOW ( Invert = 1 ) outputs and active HIGH ( Invert = 0 )outputs.
	
	parameter	MAXIMUM_BANG_TRIGGER	 = 10	   ,							// The maximum limit of time in seconds when BANG is triggered.
	parameter	MINIMUM_BANG_TRIGGER	 = 2	   ,							// The minimum limit of time in seconds when BANG is triggered.
	parameter	MAXIMUM_BANG_COUNTER	 = MAXIMUM_BANG_TRIGGER * REDUCED_CLOCK_FREQUENCY,	// The maximum number of times the counter should count.
	parameter	MINIMUM_BANG_COUNTER	 = MINIMUM_BANG_TRIGGER * REDUCED_CLOCK_FREQUENCY,	// The maximum number of times the counter should count.
	parameter 	BANG_ADDRESS_WIDTH 		 = `clog2(MAXIMUM_BANG_COUNTER), 		// Determine the required width to of the BANG time.
	
	parameter	WINNING_SCORE			 = 5	   ,							// The game ends when either one of the player is the first to score the winning points.
	parameter	SCORE_ADDRESS_WIDTH		 = `clog2(WINNING_SCORE)       , 		// Determine the required width to of the scores.
	
	parameter	COUNTER_INCREMENT		 = 1	   ,							// The time gap in seconds between start screen, ready screen and steady screen.
	
	parameter	STATE_TIME_GAP			 = 1	   ,							// The time gap in seconds between start screen, ready screen and steady screen.
	parameter	MAX_GAP_COUNTER			 = STATE_TIME_GAP * REDUCED_CLOCK_FREQUENCY,	// The maximum number of times the counter should count.
	parameter 	GAP_ADDRESS_WIDTH 		 = `clog2(MAX_GAP_COUNTER)	 			// Determine the required width to of the gap time.
)(
	/* Port List of the Game_Engine */
	
	/* Clock and Resets Inputs. */
    input     	game_clock_in										,			// The incoming clock is connected to this port.	
    input       game_reset_in										,			// The reset pin is connected to this port.
	
	/* Game-play control inputs. */
	input 		game_touch_1_button									,			// The touch input on screen 1.
	input 		game_touch_2_button									,			// The touch input on screen 2.
	input 		game_up_button										,			// To switch between one player and two player version.
	input 		game_down_button									,			// To switch between one player and two player version.
	input 		game_select_button									,			// To select between one player or two player version.
	
	output		reg [(STATE_ADDRESS_WIDTH-1):0] display_game_state  , 			// The register determines the current state of the game. 
	
	/* Game-play Players' score output registers . */
	output reg [(SCORE_ADDRESS_WIDTH-1):0] p_1_score 				,			// Player 1 score.
	output reg [(SCORE_ADDRESS_WIDTH-1):0] p_2_score 							// Player 2 score.
);	
	
	wire reduced_clock;															// Net that holds the reduced clock speed having reduced clock frequency .
	reg counter_reset = 1'b1;													// Register that resets the counter of the gap calculator.
	
	reg [(GAP_ADDRESS_WIDTH-1):0]current_gap_counter;							// Register that holds value of counting. 
	wire gap_elapsed;															// Net that determines whether gap time has elapsed. 
	
	reg [(BANG_ADDRESS_WIDTH-1):0]current_bang_counter;							// Register that holds the current value of bang counting. 
	reg [(BANG_ADDRESS_WIDTH-1):0]bang_value;									// Register that holds final value of bang counting. 
	reg bang_counter_reset = 1'b1;												// Register that resets the counter of the bang calculator.
	wire bang_elapsed;															// Register that determines whether bang time has elapsed. 
	
	reg [(BANG_ADDRESS_WIDTH-1):0]random_number;								// Register that holds value of the random number. 
	
	/* Register list containing the active states of inputs of the Game_Engine.*/
	reg active_game_reset_in;													// Inverts the input reset signal for active low inputs (if inverted input = 1).
	reg active_game_touch_1_button;												// Inverts the input touch 1 signal for active low inputs (if inverted input = 1).
	reg active_game_touch_2_button;												// Inverts the input touch 2 signal for active low inputs (if inverted input = 1).
	reg active_game_up_button;													// Inverts the input up button signal for active low inputs (if inverted input = 1).
	reg active_game_down_button;												// Inverts the input down button signal for active low inputs (if inverted input = 1).
	reg active_game_select_button;												// Inverts the input select button signal for active low inputs (if inverted input = 1).
	
	
	/* Local Parameters list containing the screen states of LCD of the Game_Engine.*/
	/* States that determine the settings of the game.*/
	localparam A_STATE = 6'b000001;												// Main screen of the game.
	localparam B_STATE = 6'b000010;												// One player version screen of the game.
	localparam C_STATE = 6'b000011;												// Two player version screen of the game.
	
	/* States that control one player version of the game.*/
	localparam D_1_STATE = 6'b000100;											// Start screen of the One player version of the game.
	localparam E_1_STATE = 6'b000101;											// Empty screen 1 of the One player version of the game.
	localparam F_1_STATE = 6'b000110;											// Ready screen of the One player version of the game.
	localparam G_1_STATE = 6'b000111;											// Empty screen 2 of the One player version of the game.
	localparam H_1_STATE = 6'b001000;											// Steady screen of the One player version of the game.
	localparam I_1_STATE = 6'b001001;											// Empty screen 3 of the One player version of the game.
	localparam J_1_STATE = 6'b001010;											// Bang screen of the One player version of the game.
	localparam K_1_STATE = 6'b001011;											// First Player kill screen of the One player version of the game.
	localparam L_1_STATE = 6'b001100;											// Second Player kill screen of the One player version of the game.
	localparam M_1_STATE = 6'b001101;											// Both Player kill screen of the One player version of the game.
	localparam N_1_STATE = 6'b001110;											// Next - First Player kill screen of the One player version of the game.
	localparam O_1_STATE = 6'b001111;											// Next - Second Player kill screen of the One player version of the game.
	localparam P_1_STATE = 6'b010000;											// Next - Both Player kill screen of the One player version of the game.
	localparam Q_1_STATE = 6'b010001;											// Player one Winner screen of the One player version of the game.
	localparam R_1_STATE = 6'b010010;											// Player two Winner screen of the One player version of the game.
	
	/* States that control two player version of the game.*/
	localparam D_2_STATE = 6'b010100;											// Start screen of the Two player version of the game.
	localparam E_2_STATE = 6'b010101;											// Empty screen 1 of the Two player version of the game.
	localparam F_2_STATE = 6'b010110;											// Ready screen of the Two player version of the game.
	localparam G_2_STATE = 6'b010111;											// Empty screen 2 of the Two player version of the game.
	localparam H_2_STATE = 6'b011000;											// Steady screen of the Two player version of the game.
	localparam I_2_STATE = 6'b011001;											// Empty screen 3 of the Two player version of the game.
	localparam J_2_STATE = 6'b011010;											// Bang screen of the Two player version of the game.
	localparam K_2_STATE = 6'b011011;											// First Player kill screen of the Two player version of the game.
	localparam L_2_STATE = 6'b011100;											// Second Player kill screen of the Two player version of the game.
	localparam M_2_STATE = 6'b011101;											// Both Player kill screen of the Two player version of the game.
	localparam N_2_STATE = 6'b011110;											// Next - First Player kill screen of the Two player version of the game.
	localparam O_2_STATE = 6'b011111;											// Next - Second Player kill screen of the Two player version of the game.
	localparam P_2_STATE = 6'b100000;											// Next - Both Player kill screen of the Two player version of the game.
	localparam Q_2_STATE = 6'b100001;											// Player one Winner screen of the Two player version of the game.
	localparam R_2_STATE = 6'b100010;											// Player two Winner screen of the Two player version of the game.
	
	/* Game state-machine register. */
	reg [(STATE_ADDRESS_WIDTH-1):0] game_state = A_STATE;
		
	/* Check the different possible game states and control inputs and determine the next states . */
	always @( posedge game_clock_in or posedge active_game_reset_in ) 
		begin
		
			if ( active_game_reset_in ) 										// Check if the game reset button is pressed.
				begin
					game_state <= A_STATE;										// Main screen of the game is the default page and the reset page .
					
					/* Reset the scores when new game starts. */
					p_1_score <= 0;
					p_2_score <= 0;
				end 
			
			else 																// Other wise check the states of the game.
				begin															
				
					case ( game_state )											// Check current game state and take necessary actions.
						
						//////////////////////////////////    A - STATE    /////////////////////////////////
						A_STATE: begin											// Current state is Main screen of the game.
									if ( active_game_touch_1_button ) 			// Check if touch screen 1 is pressed.
										begin 
											game_state <= B_STATE;				// Go to One player version screen of the game. 
										end 
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= A_STATE;
										end
								end
						
						//////////////////////////////////    B - STATE    /////////////////////////////////
						B_STATE: begin											// Current state is One player version of the game. 
									if ( active_game_select_button ) 			// Check if select button is pressed.
										begin 
											game_state <= D_1_STATE;			// Go to Start screen of the game. 
										end 
										
									else if ( active_game_down_button ) 		// Check if down button is pressed.
										begin 
											game_state <= C_STATE;				// Go to Two player version screen of the game. 
										end 	
										
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= B_STATE;
										end
								end
								
						//////////////////////////////////    C - STATE    /////////////////////////////////
						C_STATE: begin											// Current state is Two player version of the game. 
									if ( active_game_select_button ) 			// Check if select button is pressed.
										begin 
											game_state <= D_2_STATE;			// Go to Start screen of the game. 
										end 
										
									else if ( active_game_up_button ) 			// Check if up button is pressed.
										begin 
											game_state <= B_STATE;				// Go to One player version screen of the game. 
										end 	
										
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= C_STATE;
										end
								end
								
						/////////////////////////////////////////////////////////////////////////////////////////////////////////
						///////////////////////////////////     ONE PLAYER VERSION     //////////////////////////////////////////
						/////////////////////////////////////////////////////////////////////////////////////////////////////////
								
						//////////////////////////////////    D 1 - STATE   /////////////////////////////////
						D_1_STATE: begin										// Current state is Start screen of the one player version of the game. 
									if ( active_game_touch_1_button ) 			// Check if touch screen 1 is pressed.
										begin 
											game_state <= E_1_STATE;			// Go to Empty screen 1 of the one player version of the game. 
										end 	
										
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= D_1_STATE;
										end
								end
						
						//////////////////////////////////   E 1 - STATE   /////////////////////////////////
						E_1_STATE: begin										// Current state is Empty screen 1 of the one player version of the game. 
									if ( gap_elapsed ) 							// Check if time has elapsed.
										begin 
											game_state <= F_1_STATE;			// Go to Ready screen of the one player version of the game. 
											counter_reset  <= 1'b1;
										end 	
										
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= E_1_STATE;
											counter_reset  <= 1'b0;
										end
								end
								
						//////////////////////////////////   F 1 - STATE   /////////////////////////////////
						F_1_STATE: begin										// Current state is Ready screen of the one player version of the game. 
									if ( gap_elapsed ) 							// Check if time has elapsed.
										begin 
											game_state <= G_1_STATE;			// Go to Empty screen 2 of the one player version of the game. 
											counter_reset  <= 1'b1;
										end 	
										
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= F_1_STATE;
											counter_reset  <= 1'b0;
										end
								end
						
						//////////////////////////////////   G 1 - STATE   /////////////////////////////////
						G_1_STATE: begin										// Current state is Empty screen 2 of the one player version of the game. 
									if ( gap_elapsed ) 							// Check if time has elapsed.
										begin 
											game_state <= H_1_STATE;			// Go to Steady screen of the one player version of the game. 
											counter_reset  <= 1'b1;
										end 	
										
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= G_1_STATE;
											counter_reset  <= 1'b0;
										end
								end
								
						//////////////////////////////////   H 1 - STATE   /////////////////////////////////
						H_1_STATE: begin										// Current state is Steady screen of the one player version of the game. 
									if ( gap_elapsed ) 							// Check if time has elapsed.
										begin 
											game_state <= I_1_STATE;			// Go to Empty screen 3 of the one player version of the game. 
											counter_reset  <= 1'b1;
										end 	
										
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= H_1_STATE;
											counter_reset  <= 1'b0;
										end
								end
								
						//////////////////////////////////   I 1 - STATE   /////////////////////////////////
						I_1_STATE: begin										// Current state is Empty screen 3 of the one player version of the game. 
									if ( active_game_touch_1_button )			// Check if the player has tapped the screen pre-maturely.
										begin 
											game_state <= L_1_STATE;			// Go to Second Player kill screen of the one player version of the game.
											bang_counter_reset  <= 1'b1;
											p_2_score <= p_2_score + 1;											
										end
									
									else if ( bang_elapsed ) 					// Check if bang time has elapsed.
										begin 
											game_state <= J_1_STATE;			// Go to Bang screen of the one player version of the game. 
											bang_counter_reset  <= 1'b1;
										end 	
										
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= I_1_STATE;
											bang_counter_reset  <= 1'b0;
										end
								end
								
						//////////////////////////////////   J 1 - STATE   /////////////////////////////////
						J_1_STATE: begin										// Current state is Bang screen of the one player version of the game. 
									
									/* Check if both the player and computer tap at the same time . */
									if ( active_game_touch_1_button && gap_elapsed )			
										begin 
											game_state <= M_1_STATE;			// Go to Both Player kill screen of the one player version of the game.
											counter_reset  <= 1'b1;											
										end
									
									else if ( active_game_touch_1_button )		// Check if the player has tapped the screen.
										begin 
											game_state <= K_1_STATE;			// Go to First Player kill screen of the one player version of the game.
											counter_reset  <= 1'b1;		
											p_1_score <= p_1_score + 1;
										end
									
									else if ( gap_elapsed ) 					// Check if computer time has elapsed.
										begin 
											game_state <= L_1_STATE;			// Go to Second Player kill screen of the one player version of the game. 
											counter_reset  <= 1'b1;
											p_2_score <= p_2_score + 1;
										end 	
										
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= J_1_STATE;
											counter_reset  <= 1'b0;
										end
								end
								
						//////////////////////////////////   K 1 - STATE   /////////////////////////////////
						K_1_STATE: begin										// Current state is First Player kill screen of the one player version of the game.
									
									if ( gap_elapsed )							// Check if certain period of time as elapsed.
										begin 
											counter_reset  <= 1'b1;
											game_state <= N_1_STATE;			// Go to Next - First Player kill screen of the one player version of the game.
										end
																			
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= K_1_STATE;
											counter_reset  <= 1'b0;
										end
								end	
						
						//////////////////////////////////   L 1 - STATE   /////////////////////////////////
						L_1_STATE: begin										// Current state is Second Player kill screen of the one player version of the game. 
									
									if ( gap_elapsed )							// Check if certain period of time as elapsed.
										begin 
											counter_reset  <= 1'b1;
											game_state <= O_1_STATE;			// Go to Next - Second Player kill screen of the one player version of the game.
										end
																			
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= L_1_STATE;
											counter_reset  <= 1'b0;
										end
								end	
						
						//////////////////////////////////   M 1 - STATE   /////////////////////////////////
						M_1_STATE: begin										// Current state is Both Players kill screen of the one player version of the game. 
									
									if ( gap_elapsed )							// Check if certain period of time as elapsed.
										begin 
											counter_reset  <= 1'b1;
											game_state <= P_1_STATE;			// Go to Next - Both Players kill screen of the one player version of the game. 
										end
																			
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= M_1_STATE;
											counter_reset  <= 1'b0;
										end
								end	
								
						//////////////////////////////////   N 1 - STATE   /////////////////////////////////
						N_1_STATE: begin										// Current state is Next - First Player kill screen of the one player version of the game.
									
									if ( active_game_touch_1_button  )			// Check if the player has tapped the screen to proceed to the next screen.
										begin 
										
											/* Determine whether any player has reached the winning score. */
											if ( p_1_score >= WINNING_SCORE )
												begin 
													game_state <= Q_1_STATE;	// Go to Player one Winner screen of the one player version of the game.
												end
											else if ( p_2_score >= WINNING_SCORE )
												begin 
													game_state <= R_1_STATE;	// Go to Player two Winner screen of the one player version of the game.
												end
											else 
												begin
													game_state <= E_1_STATE;	// Otherwise go to Empty Screen 1 of the one player version of the game.
												end
										end	
										
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= N_1_STATE;
										end
								end	
						
						//////////////////////////////////   O 1 - STATE   /////////////////////////////////
						O_1_STATE: begin										// Current state is Next - Second Player kill screen of the one player version of the game.
									
									if ( active_game_touch_1_button )			// Check if the player has tapped the screen to proceed to the next screen.
										begin 
											
											/* Determine whether any player has reached the winning score. */
											if ( p_1_score >= WINNING_SCORE )
												begin 
													game_state <= Q_1_STATE;	// Go to Player one Winner screen of the one player version of the game.
												end
											else if ( p_2_score >= WINNING_SCORE )
												begin 
													game_state <= R_1_STATE;	// Go to Player two Winner screen of the one player version of the game.
												end
											else 
												begin
													game_state <= E_1_STATE;	// Otherwise go to Empty Screen 1 of the one player version of the game.
												end
										end	
										
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= O_1_STATE;
										end
								end	
						
						//////////////////////////////////   P 1 - STATE   /////////////////////////////////
						P_1_STATE: begin										// Current state is Both Players kill screen of the one player version of the game. 
									
									if ( active_game_touch_1_button )			// Check if the player has tapped the screen to proceed to the next screen.
										begin 
											game_state <= E_1_STATE;			// Otherwise go to Empty Screen 1 of the one player version of the game.
										end	
										
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= P_1_STATE;
										end
								end	
						
						//////////////////////////////////   Q 1 - STATE   /////////////////////////////////
						Q_1_STATE: 	game_state <= Q_1_STATE;					// Stay on same state. Current state is First Player winner screen of the one player version of the game.
	
						//////////////////////////////////   R 1 - STATE   /////////////////////////////////
						R_1_STATE: 	game_state <= R_1_STATE;					// Stay on same state. Current state is Second Player winner screen of the one player version of the game.
						
						
						/////////////////////////////////////////////////////////////////////////////////////////////////////////
						///////////////////////////////////     TWO PLAYER VERSION     //////////////////////////////////////////
						/////////////////////////////////////////////////////////////////////////////////////////////////////////
						
						//////////////////////////////////    D 2 - STATE   /////////////////////////////////
						D_2_STATE: begin										// Current state is Start screen of the two player version of the game. 
									if ( active_game_touch_1_button ) 			// Check if touch screen 1 is pressed.
										begin 
											game_state <= E_2_STATE;			// Go to Empty screen 1 of the two player version of the game. 
										end 	
										
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= D_2_STATE;
										end
								end
						
						//////////////////////////////////   E 2 - STATE   /////////////////////////////////
						E_2_STATE: begin										// Current state is Empty screen 1 of the two player version of the game. 
									if ( gap_elapsed ) 							// Check if time has elapsed.
										begin 
											game_state <= F_2_STATE;			// Go to Ready screen of the two player version of the game. 
											counter_reset  <= 1'b1;
										end 	
										
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= E_2_STATE;
											counter_reset  <= 1'b0;
										end
								end
								
						//////////////////////////////////   F 2 - STATE   /////////////////////////////////
						F_2_STATE: begin										// Current state is Ready screen of the two player version of the game. 
									if ( gap_elapsed ) 							// Check if time has elapsed.
										begin 
											game_state <= G_2_STATE;			// Go to Empty screen 2 of the two player version of the game. 
											counter_reset  <= 1'b1;
										end 	
										
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= F_2_STATE;
											counter_reset  <= 1'b0;
										end
								end
						
						//////////////////////////////////   G 2 - STATE   /////////////////////////////////
						G_2_STATE: begin										// Current state is Empty screen 2 of the two player version of the game. 
									if ( gap_elapsed ) 							// Check if time has elapsed.
										begin 
											game_state <= H_2_STATE;			// Go to Steady screen of the two player version of the game. 
											counter_reset  <= 1'b1;
										end 	
										
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= G_2_STATE;
											counter_reset  <= 1'b0;
										end
								end
								
						//////////////////////////////////   H 2 - STATE   /////////////////////////////////
						H_2_STATE: begin										// Current state is Steady screen of the two player version of the game. 
									if ( gap_elapsed ) 							// Check if time has elapsed.
										begin 
											game_state <= I_2_STATE;			// Go to Empty screen 3 of the two player version of the game. 
											counter_reset  <= 1'b1;
										end 	
										
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= H_2_STATE;
											counter_reset  <= 1'b0;
										end
								end
								
						//////////////////////////////////   I 2 - STATE   /////////////////////////////////
						I_2_STATE: begin										// Current state is Empty screen 3 of the two player version of the game. 
									if ( active_game_touch_1_button )			// Check if the player one has tapped the screen pre-maturely.
										begin 
											game_state <= L_2_STATE;			// Go to Second Player kill screen of the two player version of the game.
											bang_counter_reset  <= 1'b1;
											p_2_score <= p_2_score + 1;											
										end
										
									else if ( active_game_touch_2_button )		// Check if the player two has tapped the screen pre-maturely.
										begin 
											game_state <= K_2_STATE;			// Go to First Player kill screen of the two player version of the game.
											bang_counter_reset  <= 1'b1;
											p_1_score <= p_1_score + 1;											
										end
									
									else if ( bang_elapsed ) 					// Check if bang time has elapsed.
										begin 
											game_state <= J_2_STATE;			// Go to Bang screen of the two player version of the game. 
											bang_counter_reset  <= 1'b1;
										end 	
										
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= I_2_STATE;
											bang_counter_reset  <= 1'b0;
										end
								end
								
						//////////////////////////////////   J 2 - STATE   /////////////////////////////////
						J_2_STATE: begin										// Current state is Bang screen of the two player version of the game. 
									
									/* Check if both the players tap at the same time . */
									if ( active_game_touch_1_button && active_game_touch_2_button )			
										begin 
											game_state <= M_2_STATE;			// Go to Both Player kill screen of the two player version of the game.									
										end
									
									else if ( active_game_touch_1_button )		// Check if the player one has tapped the screen.
										begin 
											game_state <= K_2_STATE;			// Go to First Player kill screen of the two player version of the game.	
											p_1_score <= p_1_score + 1;
										end
									
									else if ( active_game_touch_2_button ) 		// Check if the player two has tapped the screen.
										begin 
											game_state <= L_2_STATE;			// Go to Second Player kill screen of the two player version of the game. 
											p_2_score <= p_2_score + 1;
										end 	
										
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= J_2_STATE;
										end
								end
								
						//////////////////////////////////   K 2 - STATE   /////////////////////////////////
						K_2_STATE: begin										// Current state is First Player kill screen of the two player version of the game.
									
									if ( gap_elapsed )							// Check if certain period of time as elapsed.
										begin 
											counter_reset  <= 1'b1;
											game_state <= N_2_STATE;			// Go to Next - First Player kill screen of the two player version of the game.
										end
																			
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= K_2_STATE;
											counter_reset  <= 1'b0;
										end
								end	
						
						//////////////////////////////////   L 2 - STATE   /////////////////////////////////
						L_2_STATE: begin										// Current state is Second Player kill screen of the two player version of the game. 
									
									if ( gap_elapsed )							// Check if certain period of time as elapsed.
										begin 
											counter_reset  <= 1'b1;
											game_state <= O_2_STATE;			// Go to Next - Second Player kill screen of the two player version of the game.
										end
																			
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= L_2_STATE;
											counter_reset  <= 1'b0;
										end
								end	
						
						//////////////////////////////////   M 2 - STATE   /////////////////////////////////
						M_2_STATE: begin										// Current state is Both Players kill screen of the two player version of the game. 
									
									if ( gap_elapsed )							// Check if certain period of time as elapsed.
										begin 
											counter_reset  <= 1'b1;
											game_state <= P_2_STATE;			// Go to Next - Both Players kill screen of the two player version of the game. 
										end
																			
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= M_2_STATE;
											counter_reset  <= 1'b0;
										end
								end	
								
						//////////////////////////////////   N 2 - STATE   /////////////////////////////////
						N_2_STATE: begin										// Current state is Next - First Player kill screen of the two player version of the game.
									
									if ( active_game_touch_1_button  )			// Check if the player has tapped the screen to proceed to the next screen.
										begin 
										
											/* Determine whether any player has reached the winning score. */
											if ( p_1_score >= WINNING_SCORE )
												begin 
													game_state <= Q_2_STATE;	// Go to Player two Winner screen of the two player version of the game.
												end
											else if ( p_2_score >= WINNING_SCORE )
												begin 
													game_state <= R_2_STATE;	// Go to Player two Winner screen of the two player version of the game.
												end
											else 
												begin
													game_state <= E_2_STATE;	// Otherwise go to Empty Screen 2 of the two player version of the game.
												end
										end	
										
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= N_2_STATE;
										end
								end	
						
						//////////////////////////////////   O 2 - STATE   /////////////////////////////////
						O_2_STATE: begin										// Current state is Next - Second Player kill screen of the two player version of the game.
									
									if ( active_game_touch_1_button )			// Check if the player has tapped the screen to proceed to the next screen.
										begin 
											
											/* Determine whether any player has reached the winning score. */
											if ( p_1_score >= WINNING_SCORE )
												begin 
													game_state <= Q_2_STATE;	// Go to Player two Winner screen of the two player version of the game.
												end
											else if ( p_2_score >= WINNING_SCORE )
												begin 
													game_state <= R_2_STATE;	// Go to Player two Winner screen of the two player version of the game.
												end
											else 
												begin
													game_state <= E_2_STATE;	// Otherwise go to Empty Screen 2 of the two player version of the game.
												end
										end	
										
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= O_2_STATE;
										end
								end	
						
						//////////////////////////////////   P 2 - STATE   /////////////////////////////////
						P_2_STATE: begin										// Current state is Both Players kill screen of the two player version of the game. 
									
									if ( active_game_touch_1_button )			// Check if the player has tapped the screen to proceed to the next screen.
										begin 
											game_state <= E_2_STATE;			// Otherwise go to Empty Screen 1 of the two player version of the game.
										end	
										
									else 									  	// Otherwise stay on same state.
										begin
											game_state <= P_2_STATE;
										end
								end	
						
						//////////////////////////////////   Q 2 - STATE   /////////////////////////////////
						Q_2_STATE: 	game_state <= Q_2_STATE;					// Stay on same state. Current state is First Player winner screen of the two player version of the game.
	
						//////////////////////////////////   R 2 - STATE   /////////////////////////////////
						R_2_STATE: 	game_state <= R_2_STATE;					// Stay on same state. Current state is Second Player winner screen of the two player version of the game.
						
						default: game_state <= A_STATE;
					endcase
			end
	end
	
	/* Display the correct output on the LCD based on the game state.  */
	always @( game_state ) 														// Check current game state and take necessary actions by displaying corresponding screens.
		begin		
			
			case ( game_state )
		
				A_STATE: begin 
							display_game_state <= game_state ;
						 end
						 
				B_STATE: begin 
							display_game_state <= game_state ;
						 end
				
				C_STATE: begin 
							display_game_state <= game_state ;
						 end
				
				D_1_STATE: begin 
							display_game_state <= game_state ;
						 end
						
				E_1_STATE: begin 
							display_game_state <= game_state ;
						 end
				
				F_1_STATE: begin 
							display_game_state <= game_state ;
						 end
				
				G_1_STATE: begin 
							display_game_state <= game_state ;
						 end
						
				H_1_STATE: begin 
							display_game_state <= game_state ;
						 end
				
				I_1_STATE: begin 
							display_game_state <= game_state ;
						 end
				
				J_1_STATE: begin 
							display_game_state <= game_state ;
						 end
						
				K_1_STATE: begin 
							display_game_state <= game_state ;
						 end
				
				L_1_STATE: begin 
							display_game_state <= game_state ;
						 end
				
				M_1_STATE: begin 
							display_game_state <= game_state ;
						 end
				
				N_1_STATE: begin 
							display_game_state <= game_state ;
						 end
						
				O_1_STATE: begin 
							display_game_state <= game_state ;
						 end	

				P_1_STATE: begin 
							display_game_state <= game_state ;
						 end
				
				Q_1_STATE: begin 
							display_game_state <= game_state ;
						 end
				
				R_1_STATE: begin 
							display_game_state <= game_state ;
						 end
				
				/* Two player states. */
				
				D_2_STATE: begin 
							display_game_state <= game_state ;
						 end
						
				E_2_STATE: begin 
							display_game_state <= game_state ;
						 end
				
				F_2_STATE: begin 
							display_game_state <= game_state ;
						 end
				
				G_2_STATE: begin 
							display_game_state <= game_state ;
						 end
						
				H_2_STATE: begin 
							display_game_state <= game_state ;
						 end
				
				I_2_STATE: begin 
							display_game_state <= game_state ;
						 end
				
				J_2_STATE: begin 
							display_game_state <= game_state ;
						 end
						
				K_2_STATE: begin 
							display_game_state <= game_state ;
						 end
				
				L_2_STATE: begin 
							display_game_state <= game_state ;
						 end
				
				M_2_STATE: begin 
							display_game_state <= game_state ;
						 end
				
				N_2_STATE: begin 
							display_game_state <= game_state ;
						 end
						
				O_2_STATE: begin 
							display_game_state <= game_state ;
						 end	

				P_2_STATE: begin 
							display_game_state <= game_state ;
						 end
				
				Q_2_STATE: begin 
							display_game_state <= game_state ;
						 end
				
				R_2_STATE: begin 
							display_game_state <= game_state ;
						 end
				
				
				default : begin 
							display_game_state <= game_state ;
						 end
				
				
			endcase
		end

	/* To check whether the inputs are active LOW or not and then take necessary actions */
	always @ ( posedge game_clock_in )
		begin																	// Always statement that changes with input signals.
		
			if ( INVERTED_INPUT )												// Check if the inputs are active LOW or active HIGH.
				begin															// If yes, invert the inputs.
					active_game_reset_in 		<= ~ game_reset_in;									
					active_game_touch_1_button 	<= ~ game_touch_1_button;
					active_game_touch_2_button	<= ~ game_touch_2_button;									
					active_game_up_button 		<= ~ game_up_button;
					active_game_down_button		<= ~ game_down_button;
					active_game_select_button	<= ~ game_select_button;	
				end
				
			else 
				begin															// If no, assign the same inputs.
					active_game_reset_in 		<= game_reset_in;									
					active_game_touch_1_button 	<= game_touch_1_button;
					active_game_touch_2_button	<= game_touch_2_button;									
					active_game_up_button 		<= game_up_button;
					active_game_down_button		<= game_down_button;
					active_game_select_button	<= game_select_button;
				end
		end
		
	/* Instantiating the frequency generator to reduce the speed of the clock. */
	Frequency_Divider # 	  	   (
		. INCOMING_CLOCK_FREQUENCY ( INCOMING_CLOCK_FREQUENCY ),				// Setting the parameter values.
		. FIXED_CLOCK_FREQUENCY	   ( REDUCED_CLOCK_FREQUENCY  )
	
	) FG_BLOCK					   (
		. FD_CLOCK_IN			   ( game_clock_in	  		  ),				// Setting the connections to their corresponding ports. 
		. FD_RESET		  	       ( active_game_reset_in	  ),
		. FD_CLOCK_OUT     	       ( reduced_clock	  		  )
	);
		
	/////////////////////////////////////////////////////////////////////////////////////////////////////////
	///////////////////////////////////     GAP CALCULATOR    ///////////////////////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	always @ ( posedge reduced_clock or posedge counter_reset )
		begin
			
			if ( counter_reset )
				begin 
					current_gap_counter <= 0;
				end
			
			else
				begin 
					current_gap_counter <= current_gap_counter + 1;
				end
		end
		
	assign gap_elapsed = ( current_gap_counter >= MAX_GAP_COUNTER );
	
	/////////////////////////////////////////////////////////////////////////////////////////////////////////
	///////////////////////////////////     RANDOM GENERATOR   //////////////////////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	always @ ( posedge game_clock_in or posedge active_game_reset_in )
		begin
			
			if ( active_game_reset_in ) 
				begin 
					random_number <= 0;
				end 
			
			else 
				begin
					random_number <= random_number + 1;
				end
		end
		
	always @ ( posedge active_game_reset_in or posedge active_game_touch_1_button )
		begin 
			
			if ( active_game_reset_in )
				begin
					bang_value <= 0;
				end
			
			else if ( random_number < MINIMUM_BANG_COUNTER )
				begin 
					bang_value <= random_number + MINIMUM_BANG_COUNTER;
				end
			
			else if ( random_number > MAXIMUM_BANG_COUNTER )
				begin 
					bang_value <= MAXIMUM_BANG_COUNTER;
				end
			
			else 
				begin 
					bang_value <= random_number;
				end
		end
				
	/////////////////////////////////////////////////////////////////////////////////////////////////////////
	///////////////////////////////////     BANG CALCULATOR    //////////////////////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	always @ ( posedge reduced_clock or posedge bang_counter_reset )
		begin
			
			if ( bang_counter_reset )
				begin 
					current_bang_counter <= 0;
				end
			
			else
				begin 
					current_bang_counter <= current_bang_counter + 1;
				end
		end
		
	assign bang_elapsed = ( current_bang_counter >= bang_value );
	
endmodule																		// End of the module.



