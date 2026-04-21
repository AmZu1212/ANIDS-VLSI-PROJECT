// ANIDS Input Layer
`include "anids_defines.vh"

module input_layer (
		clk,
		resetN,
		enable,
		features,
		counter,
		current_features
	);

	parameter FEATURE_WIDTH = `INPUT_LAYER_FEATURE_WIDTH;
	parameter COUNTER_WIDTH = `PIPELINE_COUNTER_WIDTH;
	parameter PAIR_WIDTH    = `INPUT_LAYER_PAIR_WIDTH;

	// ----------------------------------------------------------------------
	//                  		I/O Ports
	// ----------------------------------------------------------------------
	input  wire                         clk;
	input  wire                         resetN;
	input  wire                         enable;
	input  wire [FEATURE_WIDTH-1:0]     features;
	input  wire [COUNTER_WIDTH-1:0]     counter;
	output reg  [PAIR_WIDTH-1:0]        current_features;

	// ----------------------------------------------------------------------
	//                  		Feature Pair Selection
	// ----------------------------------------------------------------------
	always @(posedge clk or negedge resetN) begin
		if (!resetN) begin
			current_features <= #1 {PAIR_WIDTH{1'b0}};
		end
		else if (!enable) begin
			current_features <= #1 {PAIR_WIDTH{1'b0}};
		end
		else begin
			current_features <= #1 {features[(counter * PAIR_WIDTH) + 1], features[counter * PAIR_WIDTH]};
		end
	end
endmodule
