// ANIDS Defines
// Clock Period, this is 5ns period (200MHz clock)
`define CLK_PERIOD				16'd5


// APB can work with 8, 16, 32 bit data width
`define APB_DATA_WIDTH			8
`define APB_ADDR_WIDTH			16 							// 15 bits needed, but we use 16.


// DMA Data Width is input vector size, which is 128 bits
`define DMA_DATA_WIDTH			128

// Memory Fetch Unit widths
`define MFU_DATA_WIDTH			`DMA_DATA_WIDTH
`define MFU_FEATURE_WIDTH		`MFU_DATA_WIDTH				// stored feature vector width

// Pipeline Manager widths and history depth
`define PIPELINE_VECTOR_WIDTH	`MFU_FEATURE_WIDTH			// vector width propagated through pipeline manager
`define PIPELINE_COUNTER_WIDTH	7							// counter width for indices 0..127
`define PIPELINE_HISTORY_DEPTH	2							// number of coarse vector buffers before validation
`define PIPELINE_STAGE_CYCLES	64							// 128-bit vector processed over 64 cycles
`define PIPELINE_STAGE_COUNT_W	6							// counter width for 0..63 stage timing

// Input layer widths
`define INPUT_LAYER_FEATURE_WIDTH	`PIPELINE_VECTOR_WIDTH	// full feature vector width seen by input layer
`define INPUT_LAYER_PAIR_WIDTH		2						// number of feature bits processed per counter step

// Hidden layer unit widths
`define HL_FEATURE_PAIR_WIDTH		`INPUT_LAYER_PAIR_WIDTH	// number of feature bits consumed per cycle
`define HL_WEIGHT_WIDTH				8						// signed Q0.7 weight width
`define HL_BIAS_WIDTH				8						// signed Q0.7 bias width
`define HL_RESULT_WIDTH				8						// signed Q0.7 hidden neuron output width
`define HL_PAIR_SUM_WIDTH			9						// sum of two weighted feature contributions
`define HL_ACC_WIDTH				15						// accumulation register width before truncation

// LUT Address and Data Sizes
`define LUT_ADDR_WIDTH			7
`define LUT_DATA_WIDTH			8

`define RELU_WIDTH 				8
`define LF_OUT_WIDTH			8



// Weight & Bias Counts
`define HL_WEIGHT_COUNT   		64 * 128   	// 8192
`define HL_BIAS_COUNT      		64       	// 64
`define OL_WEIGHT_COUNT    		128 * 64   	// 8192
`define OL_BIAS_COUNT      		128      	// 128


// ANIDS Control Register Addresses
`define START_REG				0
`define N_REG					1
`define THRESHOLD_REG			2
`define RESULT_REG				3


// Indirect LUT Read/Write Registers
`define LUT_ADDR				4
`define LUT_DATA				5
`define LUT_CTRL				6
`define FREE_REG				7


// Hidden Layer Register Mapping
`define HL_WEIGHT_BASE			8
`define HL_BIAS_BASE			`HL_WEIGHT_BASE + `HL_WEIGHT_COUNT


// Output Layer Register Mapping
`define OL_WEIGHT_BASE			`HL_BIAS_BASE + `HL_BIAS_COUNT
`define OL_BIAS_BASE			`OL_WEIGHT_BASE + `OL_WEIGHT_COUNT


// ANIDS memory map borders
`define ANIDS_MAP_START   		`HL_WEIGHT_BASE
`define ANIDS_MAP_END     		`OL_BIAS_BASE + `OL_BIAS_COUNT
`define REG_COUNT				`ANIDS_MAP_END 	// (correct count due to 0-based indexing)


// Pipeline Stage Cycles
`define INPUT_LAYER_CYCLES 		1
`define HIDDEN_LAYER_CYCLES 	64
`define OUTPUT_LAYER_CYCLES 	64
`define LOSS_FUNCTION_CYCLES 	64
`define OUTLIER_CYCLES 			1
`define RESULT_CYCLES 			1


// Pipeline Fill and Latency in cycles (pipefill = 195, latency = 66)
`define PIPE_FILL_CYCLES 		(`INPUT_LAYER_CYCLES + `HIDDEN_LAYER_CYCLES + `OUTPUT_LAYER_CYCLES + `LOSS_FUNCTION_CYCLES + `OUTLIER_CYCLES + `RESULT_CYCLES)
`define LATENCY_IN_CYCLES 		(`LOSS_FUNCTION_CYCLES + `OUTLIER_CYCLES + `RESULT_CYCLES )
