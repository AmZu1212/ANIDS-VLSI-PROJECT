// ANIDS - Hidden Layer Unit Testbench
`timescale 1ns/100ps
`include "anids_defines.vh"

module hidden_layer_unit_tb;

	localparam FEATURE_PAIR_WIDTH = `HL_FEATURE_PAIR_WIDTH;
	localparam WEIGHT_WIDTH       = `HL_WEIGHT_WIDTH;
	localparam BIAS_WIDTH         = `HL_BIAS_WIDTH;
	localparam RESULT_WIDTH       = `HL_RESULT_WIDTH;
	localparam COUNTER_WIDTH      = `PIPELINE_COUNTER_WIDTH;

	reg                                 clk;
	reg                                 resetN;
	reg                                 enable;
	reg  [COUNTER_WIDTH-1:0]            N;
	reg  [COUNTER_WIDTH-1:0]            counter;
	reg  [FEATURE_PAIR_WIDTH-1:0]       features_in;
	reg  signed [WEIGHT_WIDTH-1:0]      weight_0;
	reg  signed [WEIGHT_WIDTH-1:0]      weight_1;
	reg  signed [BIAS_WIDTH-1:0]        bias;
	wire signed [RESULT_WIDTH-1:0]      result;
	wire                                ready;

	hidden_layer_unit dut (
		.clk         (clk),
		.resetN      (resetN),
		.enable      (enable),
		.N           (N),
		.counter     (counter),
		.features_in (features_in),
		.weight_0    (weight_0),
		.weight_1    (weight_1),
		.bias        (bias),
		.result      (result),
		.ready       (ready)
	);

	always #2.5 clk = ~clk;

	initial begin
		$dumpfile("hidden_layer_unit_tb.vcd");
		$dumpvars(0, hidden_layer_unit_tb);

		clk         = 1'b0;
		resetN      = 1'b0;
		enable      = 1'b0;
		N           = 7'd3;
		counter     = {COUNTER_WIDTH{1'b0}};
		features_in = {FEATURE_PAIR_WIDTH{1'b0}};
		weight_0    = '0;
		weight_1    = '0;
		bias        = '0;

		#2;
		check_outputs(1'b0, 8'sd0, "reset clears outputs");

		resetN = 1'b1;
		@(posedge clk);
		#2;
		check_outputs(1'b0, 8'sd0, "idle after reset");

		// Case 1: small positive accumulation with zero bias.
		// pair 0: 0.5 + 0.25 = 0.75  => 96 in Q0.7
		// pair 1: 0.5 + 0.5  = 1.0   => 128 in Q0.7
		// acc total = 224, trunc8(acc[14:7]) = 1
		enable      = 1'b1;
		bias        = 8'sd0;
		counter     = 7'd0;
		features_in = 2'b11;
		weight_0    = 8'sd64;
		weight_1    = 8'sd32;
		@(posedge clk);
		#2;
		check_outputs(1'b0, 8'sd0, "first accumulation cycle");

		counter     = 7'd1;
		features_in = 2'b11;
		weight_0    = 8'sd64;
		weight_1    = 8'sd64;
		@(posedge clk);
		#2;
		check_outputs(1'b1, 8'sd1, "final cycle produces truncated result");

		enable  = 1'b0;
		counter = 7'd0;
		@(posedge clk);
		#2;
		check_outputs(1'b0, 8'sd1, "ready pulses for one cycle only");

		check_outputs(1'b0, 8'sd1, "disable leaves registered result unchanged");

		// Case 2: positive saturation after bias over the full 64 pair-steps.
		enable      = 1'b1;
		N           = 7'd127;
		counter     = 7'd0;
		features_in = 2'b11;
		weight_0    = 8'sd127;
		weight_1    = 8'sd127;
		bias        = 8'sd10;
		run_until_last_pair;
		check_outputs(1'b1, 8'sd127, "positive saturation at final cycle");

		enable  = 1'b0;
		counter = 7'd0;
		@(posedge clk);
		#2;
		check_outputs(1'b0, 8'sd127, "ready drops after positive saturation");

		// Case 3: negative saturation after bias over the full 64 pair-steps.
		enable      = 1'b0;
		@(posedge clk);
		#2;

		enable      = 1'b1;
		N           = 7'd127;
		counter     = 7'd0;
		features_in = 2'b11;
		weight_0    = -8'sd128;
		weight_1    = -8'sd128;
		bias        = -8'sd10;
		run_until_last_pair;
		check_outputs(1'b1, -8'sd128, "negative saturation at final cycle");

		$display("HIDDEN_LAYER_UNIT TB PASSED");
		$finish;
	end

	task check_outputs(
		input                      expected_ready,
		input signed [RESULT_WIDTH-1:0] expected_result,
		input [255:0]              test_name
	);
	begin
		if (ready !== expected_ready || result !== expected_result) begin
			$error("FAIL: %0s | ready=%0b expected_ready=%0b result=%0d expected_result=%0d",
				test_name, ready, expected_ready, result, expected_result);
			$finish;
		end
		else begin
			$display("PASS: %0s", test_name);
		end
	end
	endtask

	task run_until_last_pair;
		integer i;
	begin
		for (i = 0; i < 63; i = i + 1) begin
			@(posedge clk);
			#2;
			counter = counter + 1'b1;
		end
		@(posedge clk);
		#2;
	end
	endtask

endmodule
