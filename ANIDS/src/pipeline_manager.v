// ANIDS Pipeline Manager
`include "anids_defines.vh"

module pipeline_manager (
		clk,
		resetN,
		start,
		N,
		mfu_features,
		mfu_updated,
		fetch,
		enable,
		next_vector,
		validate_vector,
		counter
	);


	parameter VECTOR_WIDTH   = `PIPELINE_VECTOR_WIDTH;
	parameter COUNTER_WIDTH  = `PIPELINE_COUNTER_WIDTH;


	// ----------------------------------------------------------------------
	//                  		I/O Ports
	// ----------------------------------------------------------------------

	// system signals
	input  wire                         clk;
	input  wire                         resetN;
	input  wire                         start;
	input  wire [`APB_DATA_WIDTH-1:0]   N;					// vector size, e.g. 128

	// data vector signals
	input  wire [VECTOR_WIDTH-1:0]      mfu_features;		// new data vector
	input  wire                         mfu_updated;		// signals new vector arrival
	output reg                          fetch;				// fetch new vector signal

	// outputs to engine
	output reg                          enable;				// inference engine enable signal
	output reg  [VECTOR_WIDTH-1:0]      next_vector; 		// goes to input layer
	output reg  [VECTOR_WIDTH-1:0]      validate_vector;	// goes to loss function
	output reg  [COUNTER_WIDTH-1:0]     counter;			// current feature index


	// ----------------------------------------------------------------------
	//                  		Buffer Registers
	// ----------------------------------------------------------------------
	reg [VECTOR_WIDTH-1:0] history_1;
	reg [VECTOR_WIDTH-1:0] history_2;


	// ----------------------------------------------------------------------
	//                  		Manager States
	// ----------------------------------------------------------------------
	reg [1:0] state;
	localparam STATE_IDLE        = 2'd0;
	localparam STATE_WAIT_VECTOR = 2'd1;
	localparam STATE_RUN         = 2'd2;

	// Input layer / hidden layer consume 2 features per cycle, so the
	// pipeline counter runs over pair-steps rather than raw feature bits.
	wire [COUNTER_WIDTH-1:0] last_pair_index =
		((N >> 1) - 1'b1);


	// ----------------------------------------------------------------------
	//                  		Manager Logic
	// ----------------------------------------------------------------------
	always @(posedge clk or negedge resetN) begin
		if (!resetN) begin
			fetch           <= #1 1'b0;
			enable          <= #1 1'b0;
			next_vector     <= #1 {VECTOR_WIDTH{1'b0}};
			validate_vector <= #1 {VECTOR_WIDTH{1'b0}};
			history_1       <= #1 {VECTOR_WIDTH{1'b0}};
			history_2       <= #1 {VECTOR_WIDTH{1'b0}};
			counter         <= #1 {COUNTER_WIDTH{1'b0}};
			state           <= #1 STATE_IDLE;
		end
		else begin
			fetch <= #1 1'b0;

			case (state)
				STATE_IDLE: begin
					enable  <= #1 1'b0;
					counter <= #1 {COUNTER_WIDTH{1'b0}};

					// waiting for start signal.
					// (start needs to be held on 1 to run engine)
					if (start) begin
						fetch <= #1 1'b1;
						state <= #1 STATE_WAIT_VECTOR;
					end
				end

				STATE_WAIT_VECTOR: begin
					enable <= #1 1'b0;

					if (!start) begin
						// engine stop routine
						next_vector     <= #1 {VECTOR_WIDTH{1'b0}};
						validate_vector <= #1 {VECTOR_WIDTH{1'b0}};
						history_1       <= #1 {VECTOR_WIDTH{1'b0}};
						history_2       <= #1 {VECTOR_WIDTH{1'b0}};
						counter         <= #1 {COUNTER_WIDTH{1'b0}};
						state           <= #1 STATE_IDLE;
					end
					else if (mfu_updated) begin
						// coarse shift vector forward
						next_vector     <= #1 mfu_features; // goes to input layer
						history_1       <= #1 next_vector;	// buffer 1
						history_2       <= #1 history_1;	// buffer 2
						validate_vector <= #1 history_2;	// goes to loss function

						// prepare for running
						counter         <= #1 {COUNTER_WIDTH{1'b0}};
						enable          <= #1 1'b1;
						state           <= #1 STATE_RUN;
					end
				end

				STATE_RUN: begin
					if (!start) begin
						// engine stop routine
						enable          <= #1 1'b0;
						next_vector     <= #1 {VECTOR_WIDTH{1'b0}};
						validate_vector <= #1 {VECTOR_WIDTH{1'b0}};
						history_1       <= #1 {VECTOR_WIDTH{1'b0}};
						history_2       <= #1 {VECTOR_WIDTH{1'b0}};
						counter         <= #1 {COUNTER_WIDTH{1'b0}};
						state           <= #1 STATE_IDLE;
					end
					else begin
						enable <= #1 1'b1;
						// increment counter until we need to fetch new vector
						if (counter == last_pair_index) begin
							counter <= #1 {COUNTER_WIDTH{1'b0}};
							fetch   <= #1 1'b1;
							enable  <= #1 1'b0;
							state   <= #1 STATE_WAIT_VECTOR;
						end
						else begin
							counter <= #1 counter + 1'b1;
						end
					end
				end

				//*** this is redundant, remove later
				default: begin
					// by default return to idle.
					fetch   <= #1 1'b0;
					enable  <= #1 1'b0;
					counter <= #1 {COUNTER_WIDTH{1'b0}};
					state   <= #1 STATE_IDLE;
				end
			endcase
		end
	end
endmodule
