// ANIDS Top Level Defines

// Clock Period, this is 5ns period (200MHz clock)
`define CLK_PERIOD		16'd5

// APB can work with 8,16,32 bit data width
`define APB_DATA_WIDTH	8
`define APB_ADDR_WIDTH	16 // according to register count...

// DMA Data Width is input vector size, which is 128 bits
`define DMA_DATA_WIDTH	128


// Sizes (bytes)
`define HL_WEIGHT_BYTES   (64*128)   // 8192
`define HL_BIAS_BYTES     (64)       // 64
`define OL_WEIGHT_BYTES   (128*64)   // 8192
`define OL_BIAS_BYTES     (128)      // 128


// ANIDS Control Register Addresses
`define START_REG		`APB_ADDR_WIDTH'h0000
`define N_REG			`APB_ADDR_WIDTH'h0001
`define THRESHOLD_REG	`APB_ADDR_WIDTH'h0002
`define RESULT_REG		`APB_ADDR_WIDTH'h0003
`define CTRL1_REG		`APB_ADDR_WIDTH'h0004
`define CTRL2_REG		`APB_ADDR_WIDTH'h0005
`define CTRL3_REG		`APB_ADDR_WIDTH'h0006
`define CTRL4_REG		`APB_ADDR_WIDTH'h0007

// Hidden Layer Register Mapping
`define HL_WEIGHT_BASE			`APB_ADDR_WIDTH'h0008 // 64*128 bytes: 	0x0008 -> 0x2007
`define HL_BIAS_BASE			`APB_ADDR_WIDTH'h2008 // 64 bytes:    	0x2008 -> 0x2047

// Output Layer Register Mapping
`define OL_WEIGHT_BASE			`APB_ADDR_WIDTH'h2048 // 128*64 bytes:  0x2048 -> 0x4047
`define OL_BIAS_BASE			`APB_ADDR_WIDTH'h4048 // 128 	bytes:  0x4048 -> 0x40C7



// End addresses (inclusive)
`define HL_WEIGHT_END     (`HL_WEIGHT_BASE + `HL_WEIGHT_BYTES - 1) // 0x2007
`define HL_BIAS_END       (`HL_BIAS_BASE   + `HL_BIAS_BYTES   - 1) // 0x2047
`define OL_WEIGHT_END     (`OL_WEIGHT_BASE + `OL_WEIGHT_BYTES - 1) // 0x4047
`define OL_BIAS_END       (`OL_BIAS_BASE   + `OL_BIAS_BYTES   - 1) // 0x40C7

// Optional: overall map end (inclusive)
`define ANIDS_MAP_END     (`OL_BIAS_END)


// Pipeline Cycle Definitions
`define INPUT_LAYER_CYCLES 		64
`define HIDDEN_LAYER_CYCLES 	64
`define OUTPUT_LAYER_CYCLES 	64
`define LOSS_FUNCTION_CYCLES 	64
`define OUTLIER_CYCLES 			1
`define RESULT_CYCLES 			1
`define PIPE_FILL_CYCLES (
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
