// ANIDS Hidden Layer
`include "anids_defines.vh"

module hidden_layer_unrolled (
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
`define HIDDEN_NEURON_BLOCK(IDX) \
	localparam integer HIDDEN_``IDX``_WEIGHT_BASE = `HL_WEIGHT_BASE + (IDX * 128); \
	localparam integer HIDDEN_``IDX``_BIAS_INDEX  = `HL_BIAS_BASE + IDX; \
	wire [REGFILE_ADDR_WIDTH-1:0] hidden_``IDX``_weight_idx0 = HIDDEN_``IDX``_WEIGHT_BASE + (counter * 2); \
	wire [REGFILE_ADDR_WIDTH-1:0] hidden_``IDX``_weight_idx1 = HIDDEN_``IDX``_WEIGHT_BASE + (counter * 2) + 1'b1; \
	wire signed [RESULT_WIDTH-1:0] hidden_``IDX``_pre_relu_result; \
	hidden_layer_unit neuron_inst_``IDX`` ( \
		.clk         (clk), \
		.resetN      (resetN), \
		.enable      (enable), \
		.N           (N), \
		.counter     (counter), \
		.features_in (features), \
		.weight_0    (regfile[hidden_``IDX``_weight_idx0]), \
		.weight_1    (regfile[hidden_``IDX``_weight_idx1]), \
		.bias        (regfile[HIDDEN_``IDX``_BIAS_INDEX]), \
		.result      (hidden_``IDX``_pre_relu_result), \
		.ready       (ready[IDX]) \
	); \
	relu_unit relu_inst_``IDX`` ( \
		.in_data  (hidden_``IDX``_pre_relu_result), \
		.resetN   (resetN), \
		.ready    (ready[IDX]), \
		.out_data (results[IDX]) \
	);

	`HIDDEN_NEURON_BLOCK(0)
	`HIDDEN_NEURON_BLOCK(1)
	`HIDDEN_NEURON_BLOCK(2)
	`HIDDEN_NEURON_BLOCK(3)
	`HIDDEN_NEURON_BLOCK(4)
	`HIDDEN_NEURON_BLOCK(5)
	`HIDDEN_NEURON_BLOCK(6)
	`HIDDEN_NEURON_BLOCK(7)
	`HIDDEN_NEURON_BLOCK(8)
	`HIDDEN_NEURON_BLOCK(9)
	`HIDDEN_NEURON_BLOCK(10)
	`HIDDEN_NEURON_BLOCK(11)
	`HIDDEN_NEURON_BLOCK(12)
	`HIDDEN_NEURON_BLOCK(13)
	`HIDDEN_NEURON_BLOCK(14)
	`HIDDEN_NEURON_BLOCK(15)
	`HIDDEN_NEURON_BLOCK(16)
	`HIDDEN_NEURON_BLOCK(17)
	`HIDDEN_NEURON_BLOCK(18)
	`HIDDEN_NEURON_BLOCK(19)
	`HIDDEN_NEURON_BLOCK(20)
	`HIDDEN_NEURON_BLOCK(21)
	`HIDDEN_NEURON_BLOCK(22)
	`HIDDEN_NEURON_BLOCK(23)
	`HIDDEN_NEURON_BLOCK(24)
	`HIDDEN_NEURON_BLOCK(25)
	`HIDDEN_NEURON_BLOCK(26)
	`HIDDEN_NEURON_BLOCK(27)
	`HIDDEN_NEURON_BLOCK(28)
	`HIDDEN_NEURON_BLOCK(29)
	`HIDDEN_NEURON_BLOCK(30)
	`HIDDEN_NEURON_BLOCK(31)
	`HIDDEN_NEURON_BLOCK(32)
	`HIDDEN_NEURON_BLOCK(33)
	`HIDDEN_NEURON_BLOCK(34)
	`HIDDEN_NEURON_BLOCK(35)
	`HIDDEN_NEURON_BLOCK(36)
	`HIDDEN_NEURON_BLOCK(37)
	`HIDDEN_NEURON_BLOCK(38)
	`HIDDEN_NEURON_BLOCK(39)
	`HIDDEN_NEURON_BLOCK(40)
	`HIDDEN_NEURON_BLOCK(41)
	`HIDDEN_NEURON_BLOCK(42)
	`HIDDEN_NEURON_BLOCK(43)
	`HIDDEN_NEURON_BLOCK(44)
	`HIDDEN_NEURON_BLOCK(45)
	`HIDDEN_NEURON_BLOCK(46)
	`HIDDEN_NEURON_BLOCK(47)
	`HIDDEN_NEURON_BLOCK(48)
	`HIDDEN_NEURON_BLOCK(49)
	`HIDDEN_NEURON_BLOCK(50)
	`HIDDEN_NEURON_BLOCK(51)
	`HIDDEN_NEURON_BLOCK(52)
	`HIDDEN_NEURON_BLOCK(53)
	`HIDDEN_NEURON_BLOCK(54)
	`HIDDEN_NEURON_BLOCK(55)
	`HIDDEN_NEURON_BLOCK(56)
	`HIDDEN_NEURON_BLOCK(57)
	`HIDDEN_NEURON_BLOCK(58)
	`HIDDEN_NEURON_BLOCK(59)
	`HIDDEN_NEURON_BLOCK(60)
	`HIDDEN_NEURON_BLOCK(61)
	`HIDDEN_NEURON_BLOCK(62)
	`HIDDEN_NEURON_BLOCK(63)
`undef HIDDEN_NEURON_BLOCK

endmodule
