// ANIDS Top Level Defines
// APB can work with 8,16,32 bit data width
`define APB_DATA_WIDTH	8

// DMA Data Width is input vector size, which is 128 bits
`define DMA_DATA_WIDTH	128

// ANIDS Control Register Addresses
`define START_REG		16'h0000;
`define N_REG			16'h0001;
`define THRESHOLD_REG	16'h0002;
`define RESULT_REG		16'h0003;
`define CTRL1_REG		16'h0004;
`define CTRL2_REG		16'h0005;
`define CTRL3_REG		16'h0006;
`define CTRL4_REG		16'h0007;

// Hidden Layer Memory Mapping
`define W_BASE			16'h0008; // 64*128 bytes: 	0x0008 -> 0x2007
`define HL_BIAS_BASE	16'h2008; // 64 bytes:    	0x2008 -> 0x2047

// Output Layer Memory Mapping
`define O_BASE			16'h2048; // 128*64 bytes:  0x2048 -> 0x4047
`define OL_BIAS_BASE	16'h4048; // 128 	bytes:  0x4048 -> 0x40C7

// Clock Generator (not sure if needed) this is 5ns period (200MHz clock)
`define CLK_PERIOD		16'd5


// Pipeline Cycle Definitions
`define INPUT_LAYER_CYCLES 		64
`define HIDDEN_LAYER_CYCLES 	64
`define OUTPUT_LAYER_CYCLES 	64
`define LOSS_FUNCTION_CYCLES 	64
`define OUTLIER_CYCLES 			1
`define RESULT_CYCLES 			1
`define FILL_CYCLES (
					`INPUT_LAYER_CYCLES 	+
					`HIDDEN_LAYER_CYCLES 	+
					`OUTPUT_LAYER_CYCLES 	+
					`LOSS_FUNCTION_CYCLES 	+
					`OUTLIER_CYCLES 		+
					`RESULT_CYCLES )	 // = 259

`define LATENCY_IN_CYCLES (
					`LOSS_FUNCTION_CYCLES 	+
					`OUTLIER_CYCLES 		+
					`RESULT_CYCLES ) 	 // = 66



