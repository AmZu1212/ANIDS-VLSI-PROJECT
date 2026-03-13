// ANIDS Hidden Layer Unit
`include "anids_defines.vh"

module hidden_layer_unit (
		clk,
		resetN,
		enable,
		N,
		counter,
		features_in,
		weight_0,
		weight_1,
		bias,
		result,
		ready
	);

	parameter FEATURE_PAIR_WIDTH = `HL_FEATURE_PAIR_WIDTH;
	parameter WEIGHT_WIDTH       = `HL_WEIGHT_WIDTH;
	parameter BIAS_WIDTH         = `HL_BIAS_WIDTH;
	parameter RESULT_WIDTH       = `HL_RESULT_WIDTH;
	parameter COUNTER_WIDTH      = `PIPELINE_COUNTER_WIDTH;
	parameter PAIR_SUM_WIDTH     = `HL_PAIR_SUM_WIDTH;
	parameter ACC_WIDTH          = `HL_ACC_WIDTH;

	// ----------------------------------------------------------------------
	//                  		I/O Ports
	// ----------------------------------------------------------------------
	input  wire                                 clk;
	input  wire                                 resetN;
	input  wire                                 enable;
	input  wire [COUNTER_WIDTH-1:0]             N;
	input  wire [COUNTER_WIDTH-1:0]             counter;

	input  wire [FEATURE_PAIR_WIDTH-1:0]        features_in;
	input  wire signed [WEIGHT_WIDTH-1:0]       weight_0;
	input  wire signed [WEIGHT_WIDTH-1:0]       weight_1;
	input  wire signed [BIAS_WIDTH-1:0]         bias;


	output reg  signed [RESULT_WIDTH-1:0]       result;
	output reg                                  ready;

	// ----------------------------------------------------------------------
	//                  		Datapath
	// ----------------------------------------------------------------------
	reg signed [ACC_WIDTH-1:0] acc;

	//*** check this counter calc later
	wire [COUNTER_WIDTH-1:0] last_pair_index =
		((({1'b0, N} + 1'b1) >> 1) - 1'b1);

	// first 2 "multipliers" - in this case they are muxes, due to 1-hot encoding of the input vector.
	wire signed [WEIGHT_WIDTH-1:0] gated_weight_0 =
		features_in[0] ? weight_0 : {WEIGHT_WIDTH{1'b0}};
	wire signed [WEIGHT_WIDTH-1:0] gated_weight_1 =
		features_in[1] ? weight_1 : {WEIGHT_WIDTH{1'b0}};

	// first sum
	wire signed [PAIR_SUM_WIDTH-1:0] pair_sum =
		$signed({gated_weight_0[WEIGHT_WIDTH-1], gated_weight_0}) +
		$signed({gated_weight_1[WEIGHT_WIDTH-1], gated_weight_1});

	// next accumulator result
	wire signed [ACC_WIDTH-1:0] acc_next =
		acc + $signed({{(ACC_WIDTH-PAIR_SUM_WIDTH){pair_sum[PAIR_SUM_WIDTH-1]}}, pair_sum});

	// trunc8 - we take MSBs + sign bit --> trunc_result = {sign bit , 7 more data bits}
	wire signed [RESULT_WIDTH-1:0] trunc8 = acc_next[ACC_WIDTH-1 -: RESULT_WIDTH];


	// saturating adder - *** go back to make sure you understand the syntax here
	wire signed [RESULT_WIDTH:0] biased_sum =
		$signed({trunc8[RESULT_WIDTH-1], trunc8}) +
		$signed({bias[BIAS_WIDTH-1], bias});

	reg signed [RESULT_WIDTH-1:0] sat_result;

	// saturation logic
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

			if (counter == last_pair_index) begin
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
