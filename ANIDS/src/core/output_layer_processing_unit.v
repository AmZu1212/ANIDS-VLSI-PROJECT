// ANIDS Output Layer Processing Unit
`include "anids_defines.vh"

module output_layer_processing_unit (
		clk,
		resetN,
		enable,
		N,
		counter,
		hidden_in,
		weight,
		bias,
		result,
		ready
	);

	parameter INPUT_WIDTH         = `OL_INPUT_WIDTH;
	parameter WEIGHT_WIDTH        = `OL_WEIGHT_WIDTH;
	parameter BIAS_WIDTH          = `OL_BIAS_WIDTH;
	parameter RESULT_WIDTH        = `OL_RESULT_WIDTH;
	parameter COUNTER_WIDTH       = `PIPELINE_COUNTER_WIDTH;
	parameter PRODUCT_WIDTH       = `OL_PRODUCT_WIDTH;
	parameter TRUNC_PRODUCT_WIDTH = `OL_TRUNC_PRODUCT_WIDTH;
	parameter ACC_WIDTH           = `OL_ACC_WIDTH;

	// ----------------------------------------------------------------------
	//                  		I/O Ports
	// ----------------------------------------------------------------------
	input  wire                                 clk;
	input  wire                                 resetN;
	input  wire                                 enable;
	input  wire [`APB_DATA_WIDTH-1:0]           N;
	input  wire [COUNTER_WIDTH-1:0]             counter;
	input  wire signed [INPUT_WIDTH-1:0]        hidden_in;
	input  wire signed [WEIGHT_WIDTH-1:0]       weight;
	input  wire signed [BIAS_WIDTH-1:0]         bias;
	output reg  signed [RESULT_WIDTH-1:0]       result;
	output reg                                  ready;

	// ----------------------------------------------------------------------
	//                  		Datapath
	// ----------------------------------------------------------------------
	reg signed [ACC_WIDTH-1:0] acc;

	// Last active pair-step index for one full hidden-layer sweep.
	wire [COUNTER_WIDTH-1:0] last_step_index =
		((N >> 1) - 1'b1);

	// Full signed Q0.7 x Q0.7 multiply result before truncation.
	wire signed [PRODUCT_WIDTH-1:0] product_full = hidden_in * weight;

	// Product converted back to signed Q0.7 by dropping 7 LSB fractional bits.
	wire signed [TRUNC_PRODUCT_WIDTH-1:0] product_q07 =
		product_full[PRODUCT_WIDTH-2 -: TRUNC_PRODUCT_WIDTH];

	// Next accumulator value after adding the current MAC contribution.
	wire signed [ACC_WIDTH-1:0] acc_next =
		acc + $signed({{(ACC_WIDTH-TRUNC_PRODUCT_WIDTH){product_q07[TRUNC_PRODUCT_WIDTH-1]}}, product_q07});

	// TRUN8 keeps the sign bit and top 7 remaining bits of the accumulated sum.
	wire signed [RESULT_WIDTH-1:0] trunc8 = acc_next[ACC_WIDTH-1 -: RESULT_WIDTH];

	// Signed bias add uses one extra bit to detect overflow before saturation.
	wire signed [RESULT_WIDTH:0] biased_sum =
		$signed({trunc8[RESULT_WIDTH-1], trunc8}) +
		$signed({bias[BIAS_WIDTH-1], bias});

	reg signed [RESULT_WIDTH-1:0] sat_result;
	always @(*) begin
		if (biased_sum > $signed({1'b0, {RESULT_WIDTH-1{1'b1}}})) begin
			sat_result = {1'b0, {RESULT_WIDTH-1{1'b1}}};
		end
		else if (biased_sum < $signed({1'b1, {RESULT_WIDTH-1{1'b0}}})) begin
			sat_result = {1'b1, {RESULT_WIDTH-1{1'b0}}};
		end
		else begin
			sat_result = biased_sum[RESULT_WIDTH-1:0];
		end
	end

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

			if (counter == last_step_index) begin
				acc    <= #1 {ACC_WIDTH{1'b0}};
				result <= #1 sat_result;
				ready  <= #1 1'b1;
			end
			else begin
				acc <= #1 acc_next;
			end
		end
	end

endmodule
