// ANIDS Loss Function
`include "anids_defines.vh"

module loss_function (
		clk,
		resetN,
		enable,
		N,
		counter,
		lut_wr_addr,
		lut_wr_data,
		lut_wr_en,
		x_in,
		result_0,
		result_1,
		result,
		ready
	);

	parameter FEATURE_PAIR_WIDTH = `LF_FEATURE_PAIR_WIDTH;
	parameter RESULT_IN_WIDTH    = `LF_RESULT_IN_WIDTH;
	parameter RESULT_WIDTH       = `LF_OUT_WIDTH;
	parameter COUNTER_WIDTH      = `PIPELINE_COUNTER_WIDTH;
	parameter ABS_WIDTH          = `LF_ABS_WIDTH;
	parameter PAIR_SUM_WIDTH     = `LF_PAIR_SUM_WIDTH;
	parameter ACC_WIDTH          = `LF_ACC_WIDTH;
	parameter LUT_ADDR_WIDTH     = `LUT_ADDR_WIDTH;
	parameter LUT_DATA_WIDTH     = `LUT_DATA_WIDTH;

	// ----------------------------------------------------------------------
	//                  		I/O Ports
	// ----------------------------------------------------------------------
	input  wire                                clk;
	input  wire                                resetN;
	input  wire                                enable;
	input  wire [`APB_DATA_WIDTH-1:0]          N;
	input  wire [COUNTER_WIDTH-1:0]            counter;
	input  wire [LUT_ADDR_WIDTH-1:0]           lut_wr_addr;
	input  wire [LUT_DATA_WIDTH-1:0]           lut_wr_data;
	input  wire                                lut_wr_en;
	input  wire [FEATURE_PAIR_WIDTH-1:0]       x_in;
	input  wire signed [RESULT_IN_WIDTH-1:0]   result_0;
	input  wire signed [RESULT_IN_WIDTH-1:0]   result_1;
	output reg  signed [RESULT_WIDTH-1:0]      result;
	output reg                                 ready;

	// ----------------------------------------------------------------------
	//                  		Datapath
	// ----------------------------------------------------------------------
	reg signed [ACC_WIDTH-1:0] acc;
	wire [LUT_ADDR_WIDTH-1:0] lut_rd_addr_0;
	wire [LUT_ADDR_WIDTH-1:0] lut_rd_addr_1;
	wire signed [LUT_DATA_WIDTH-1:0] function_0;
	wire signed [LUT_DATA_WIDTH-1:0] function_1;

	// Map signed outputs into *ascending* LUT address space, then apply the
	// configured function table before computing the loss delta.
	memory_mapper mapper_0 (
		.in_value (result_0),
		.lut_addr (lut_rd_addr_0)
	);

	memory_mapper mapper_1 (
		.in_value (result_1),
		.lut_addr (lut_rd_addr_1)
	);

	lut_mem function_lut_0 (
		.clk     (clk),
		.resetN  (resetN),
		.rd_addr (lut_rd_addr_0),
		.wr_addr (lut_wr_addr),
		.wr_en   (lut_wr_en),
		.wr_data (lut_wr_data),
		.rd_data (function_0)
	);

	lut_mem function_lut_1 (
		.clk     (clk),
		.resetN  (resetN),
		.rd_addr (lut_rd_addr_1),
		.wr_addr (lut_wr_addr),
		.wr_en   (lut_wr_en),
		.wr_data (lut_wr_data),
		.rd_data (function_1)
	);

	// Last valid pair-step for the current vector length.
	wire [COUNTER_WIDTH-1:0] last_pair_index =
		((N >> 1) - 1'b1);

	// Extend original feature bits into the same numeric space as the function-LUT outputs.
	wire signed [RESULT_IN_WIDTH:0] x0_ext = x_in[0] ? 9'sd1 : 9'sd0;
	wire signed [RESULT_IN_WIDTH:0] x1_ext = x_in[1] ? 9'sd1 : 9'sd0;
	wire signed [RESULT_IN_WIDTH:0] r0_ext = {function_0[LUT_DATA_WIDTH-1], function_0};
	wire signed [RESULT_IN_WIDTH:0] r1_ext = {function_1[LUT_DATA_WIDTH-1], function_1};

	// Per-feature reconstruction error before magnitude.
	wire signed [RESULT_IN_WIDTH:0] delta_0 = x0_ext - r0_ext;
	wire signed [RESULT_IN_WIDTH:0] delta_1 = x1_ext - r1_ext;

	// Absolute error for each feature in the pair.
	wire [ABS_WIDTH-1:0] abs_0 = delta_0[RESULT_IN_WIDTH] ? -delta_0 : delta_0;
	wire [ABS_WIDTH-1:0] abs_1 = delta_1[RESULT_IN_WIDTH] ? -delta_1 : delta_1;

	// Combined per-cycle loss increment.
	wire [PAIR_SUM_WIDTH-1:0] pair_sum = abs_0 + abs_1;

	// Running accumulated loss value.
	wire signed [ACC_WIDTH-1:0] acc_next =
		acc + $signed({{(ACC_WIDTH-PAIR_SUM_WIDTH){1'b0}}, pair_sum});

	// TRUN8 keeps the sign bit and the top 7 remaining bits.
	wire signed [RESULT_WIDTH-1:0] trunc8 = acc_next[ACC_WIDTH-1 -: RESULT_WIDTH];

	// ----------------------------------------------------------------------
	//                  		Sequential Logic
	// ----------------------------------------------------------------------
	always @(posedge clk or negedge resetN) begin
		if (!resetN) begin
			acc    <= #1 {ACC_WIDTH{1'b0}};
			result <= #1 {RESULT_WIDTH{1'b0}};
			ready  <= #1 1'b0;
		end
		else if (!enable) begin
			acc   <= #1 {ACC_WIDTH{1'b0}};
			ready <= #1 1'b0;
		end
		else begin
			ready <= #1 1'b0;

			if (counter == last_pair_index) begin
				acc    <= #1 {ACC_WIDTH{1'b0}};
				result <= #1 trunc8;
				ready  <= #1 1'b1;
			end
			else begin
				acc <= #1 acc_next;
			end
		end
	end
endmodule
