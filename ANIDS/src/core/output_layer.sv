// ANIDS Output Layer
`include "anids_defines.vh"

module output_layer (
		clk,
		resetN,
		enable,
		N,
		hidden_results,
		counter,
		regfile,
		results,
		ready
	);

	parameter INPUT_WIDTH       = `OL_INPUT_WIDTH;
	parameter WEIGHT_WIDTH      = `OL_WEIGHT_WIDTH;
	parameter BIAS_WIDTH        = `OL_BIAS_WIDTH;
	parameter RESULT_WIDTH      = `OL_RESULT_WIDTH;
	parameter COUNTER_WIDTH     = `PIPELINE_COUNTER_WIDTH;
	parameter REGFILE_ADDR_WIDTH = `APB_ADDR_WIDTH;
	parameter INPUT_COUNT       = 64;
	parameter NEURON_COUNT      = 128;

	// ----------------------------------------------------------------------
	//                  		I/O Ports
	// ----------------------------------------------------------------------
	input  wire                                     clk;
	input  wire                                     resetN;
	input  wire                                     enable;
	input  wire [`APB_DATA_WIDTH-1:0]               N;
	input  wire signed [INPUT_WIDTH-1:0]            hidden_results [0:INPUT_COUNT-1];
	input  wire [COUNTER_WIDTH-1:0]                 counter;
	input  wire signed [`APB_DATA_WIDTH-1:0]        regfile [0:`REG_COUNT-1];
	output wire signed [RESULT_WIDTH-1:0]           results [0:NEURON_COUNT-1];
	output wire                                     ready   [0:NEURON_COUNT-1];

	// ----------------------------------------------------------------------
	//                  		Output Neuron Bank
	// ----------------------------------------------------------------------
	genvar i;
	generate
		for (i = 0; i < NEURON_COUNT; i = i + 1) begin : output_neurons
			localparam integer WEIGHT_BASE = `OL_WEIGHT_BASE + (i * INPUT_COUNT);
			localparam integer BIAS_INDEX  = `OL_BIAS_BASE + i;

			// Each output neuron consumes one hidden-layer result and one weight per cycle.
			wire [REGFILE_ADDR_WIDTH-1:0] weight_idx = WEIGHT_BASE + counter;

			output_layer_processing_unit neuron_inst (
				.clk       (clk),
				.resetN    (resetN),
				.enable    (enable),
				.N         (N),
				.counter   (counter),
				.hidden_in (hidden_results[counter]),
				.weight    (regfile[weight_idx]),
				.bias      (regfile[BIAS_INDEX]),
				.result    (results[i]),
				.ready     (ready[i])
			);
		end
	endgenerate

endmodule
