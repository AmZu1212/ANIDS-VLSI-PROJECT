// ANIDS Top Level Defines


// Clock Period, this is 5ns period (200MHz clock)
`define CLK_PERIOD				16'd5


// APB can work with 8, 16, 32 bit data width
`define APB_DATA_WIDTH			8
`define APB_ADDR_WIDTH			16 			// 15 bits needed, but we use 16.


// DMA Data Width is input vector size, which is 128 bits
`define DMA_DATA_WIDTH			128


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
// * TODO: remove if not used ( dont forget to update addresses below!)
`define CTRL1_REG				4
`define CTRL2_REG				5
`define CTRL3_REG				6
`define CTRL4_REG				7


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