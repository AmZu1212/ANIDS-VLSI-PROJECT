// ANIDS Hidden Layer
`include "anids_defines.vh"

module hidden_layer (
		clk,
		resetN,
		enable,
		N,
		features,
		counter,
		regfile,
		results,
		ready
	);

	parameter FEATURE_PAIR_WIDTH = `HL_FEATURE_PAIR_WIDTH;
	parameter WEIGHT_WIDTH       = `HL_WEIGHT_WIDTH;
	parameter BIAS_WIDTH         = `HL_BIAS_WIDTH;
	parameter RESULT_WIDTH       = `HL_RESULT_WIDTH;
	parameter COUNTER_WIDTH      = `PIPELINE_COUNTER_WIDTH;
	parameter REGFILE_ADDR_WIDTH = `APB_ADDR_WIDTH;
	parameter NEURON_COUNT       = 64;
	parameter N_WIDTH            = `APB_DATA_WIDTH;

	// ----------------------------------------------------------------------
	//                  		I/O Ports
	// ----------------------------------------------------------------------
	input  wire                                     clk;
	input  wire                                     resetN;
	input  wire                                     enable;
	input  wire [N_WIDTH-1:0]                       N;
	input  wire [FEATURE_PAIR_WIDTH-1:0]            features;
	input  wire [COUNTER_WIDTH-1:0]                 counter;
	input  wire signed [`APB_DATA_WIDTH-1:0]        regfile [0:`REG_COUNT-1];
	output wire signed [RESULT_WIDTH-1:0]           results [0:NEURON_COUNT-1];
	output wire                                     ready   [0:NEURON_COUNT-1];

	// ----------------------------------------------------------------------
	//                  		Hidden Neuron Bank + ReLU
	// ----------------------------------------------------------------------
	genvar i;
	generate
		for (i = 0; i < NEURON_COUNT; i = i + 1) begin : hidden_neurons
			localparam integer WEIGHT_BASE = `HL_WEIGHT_BASE + (i * 128);
			localparam integer BIAS_INDEX  = `HL_BIAS_BASE + i;

			// counter * 2 is the index of the feature pair
			wire [REGFILE_ADDR_WIDTH-1:0] weight_idx0 = WEIGHT_BASE + (counter * 2);
			wire [REGFILE_ADDR_WIDTH-1:0] weight_idx1 = WEIGHT_BASE + (counter * 2) + 1'b1;
			wire signed [RESULT_WIDTH-1:0] pre_relu_result;

			hidden_layer_unit neuron_inst (
				.clk         (clk),
				.resetN      (resetN),
				.enable      (enable),
				.N           (N),
				.counter     (counter),
				.features_in (features),
				.weight_0    (regfile[weight_idx0]),
				.weight_1    (regfile[weight_idx1]),
				.bias        (regfile[BIAS_INDEX]),
				.result      (pre_relu_result),
				.ready       (ready[i])
			);

			relu_unit relu_inst (
				.in_data  (pre_relu_result),
				.resetN   (resetN),
				.ready    (1'b1),
				.out_data (results[i])
			);
		end
	endgenerate

endmodule
