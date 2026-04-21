// ANIDS - Loss Function Testbench
`timescale 1ns/100ps
`include "anids_defines.vh"

module loss_function_tb;

	localparam FEATURE_PAIR_WIDTH = `LF_FEATURE_PAIR_WIDTH;
	localparam RESULT_IN_WIDTH    = `LF_RESULT_IN_WIDTH;
	localparam RESULT_WIDTH       = `LF_OUT_WIDTH;
	localparam COUNTER_WIDTH      = `PIPELINE_COUNTER_WIDTH;

	reg                               clk;
	reg                               resetN;
	reg                               enable;
	reg  [`APB_DATA_WIDTH-1:0]        N;
	reg  [COUNTER_WIDTH-1:0]          counter;
	reg  [FEATURE_PAIR_WIDTH-1:0]     x_in;
	reg  signed [RESULT_IN_WIDTH-1:0] function_0;
	reg  signed [RESULT_IN_WIDTH-1:0] function_1;
	wire signed [RESULT_WIDTH-1:0]    result;
	wire                              ready;

	integer                           acc_model;

	loss_function dut (
		.clk        (clk),
		.resetN     (resetN),
		.enable     (enable),
		.N          (N),
		.counter    (counter),
		.x_in       (x_in),
		.function_0 (function_0),
		.function_1 (function_1),
		.result     (result),
		.ready      (ready)
	);

	always #2.5 clk = ~clk;

	initial begin
		$dumpfile("loss_function_tb.vcd");
		$dumpvars(0, loss_function_tb);

		clk        = 1'b0;
		resetN     = 1'b0;
		enable     = 1'b0;
		N          = 8'd2;
		counter    = {COUNTER_WIDTH{1'b0}};
		x_in       = {FEATURE_PAIR_WIDTH{1'b0}};
		function_0 = '0;
		function_1 = '0;
		acc_model  = 0;

		#2;
		check_outputs(1'b0, 8'sd0, "reset clears outputs");

		resetN = 1'b1;
		@(posedge clk);
		#2;
		check_outputs(1'b0, 8'sd0, "idle after reset");

		run_single_pair_test;
		run_two_pair_accumulation_test;
		run_negative_function_test;
		run_disable_clears_accumulator_test;

		$display("LOSS_FUNCTION TB PASSED");
		$finish;
	end

	task run_single_pair_test;
		integer expected;
	begin
		$display("SECTION: single pair");
		reset_runtime_only;

		N          = 8'd2;
		enable     = 1'b1;
		counter    = 7'd0;
		x_in       = 2'b01;
		function_0 = 8'sd0;
		function_1 = 8'sd1;

		expected = trunc8_value(model_pair_loss(x_in, function_0, function_1));

		@(posedge clk);
		#2;
		check_outputs(1'b1, expected[RESULT_WIDTH-1:0], "single pair result matches");

		enable = 1'b0;
		@(posedge clk);
		#2;
		check_outputs(1'b0, expected[RESULT_WIDTH-1:0], "result holds after disable");
	end
	endtask

	task run_two_pair_accumulation_test;
		integer expected;
	begin
		$display("SECTION: two-pair accumulation");
		reset_runtime_only;

		N          = 8'd4;
		enable     = 1'b1;
		counter    = 7'd0;
		x_in       = 2'b11;
		function_0 = -8'sd32;
		function_1 = 8'sd20;
		acc_model  = model_pair_loss(x_in, function_0, function_1);

		@(posedge clk);
		#2;
		check_outputs(1'b0, 8'sd0, "first pair accumulates without ready");

		counter    = 7'd1;
		x_in       = 2'b10;
		function_0 = 8'sd64;
		function_1 = -8'sd64;
		acc_model  = acc_model + model_pair_loss(x_in, function_0, function_1);
		expected   = trunc8_value(acc_model);

		@(posedge clk);
		#2;
		check_outputs(1'b1, expected[RESULT_WIDTH-1:0], "two-pair accumulation matches");
	end
	endtask

	task run_negative_function_test;
		integer expected;
	begin
		$display("SECTION: signed looked-up values");
		reset_runtime_only;

		N          = 8'd2;
		enable     = 1'b1;
		counter    = 7'd0;
		x_in       = 2'b00;
		function_0 = -8'sd32;
		function_1 = -8'sd64;

		expected = trunc8_value(model_pair_loss(x_in, function_0, function_1));

		@(posedge clk);
		#2;
		check_outputs(1'b1, expected[RESULT_WIDTH-1:0], "negative looked-up values are sign-extended correctly");
	end
	endtask

	task run_disable_clears_accumulator_test;
	begin
		$display("SECTION: disable clears accumulator");
		reset_runtime_only;

		N          = 8'd4;
		enable     = 1'b1;
		counter    = 7'd0;
		x_in       = 2'b11;
		function_0 = 8'sd32;
		function_1 = 8'sd32;

		@(posedge clk);
		#2;
		check_outputs(1'b0, 8'sd0, "partial accumulation still not ready");

		enable = 1'b0;
		@(posedge clk);
		#2;
		check_outputs(1'b0, 8'sd0, "disable clears in-flight accumulation");

		enable     = 1'b1;
		N          = 8'd2;
		counter    = 7'd0;
		x_in       = 2'b01;
		function_0 = 8'sd0;
		function_1 = 8'sd0;

		@(posedge clk);
		#2;
		check_outputs(1'b1, 8'sd0, "restart begins from a clean accumulator");
	end
	endtask

	task reset_runtime_only;
	begin
		enable     = 1'b0;
		counter    = {COUNTER_WIDTH{1'b0}};
		x_in       = {FEATURE_PAIR_WIDTH{1'b0}};
		function_0 = '0;
		function_1 = '0;
		acc_model  = 0;
		@(posedge clk);
		#2;
	end
	endtask

	function integer abs_int;
		input integer value;
	begin
		if (value < 0)
			abs_int = -value;
		else
			abs_int = value;
	end
	endfunction

	function integer model_pair_loss;
		input [FEATURE_PAIR_WIDTH-1:0]            pair_x;
		input signed [RESULT_IN_WIDTH-1:0]        pair_f0;
		input signed [RESULT_IN_WIDTH-1:0]        pair_f1;
	begin
		model_pair_loss =
			abs_int((pair_x[0] ? 1 : 0) - pair_f0) +
			abs_int((pair_x[1] ? 1 : 0) - pair_f1);
	end
	endfunction

	function integer trunc8_value;
		input integer acc_value;
	begin
		trunc8_value = acc_value >>> 7;
	end
	endfunction

	task check_outputs(
		input                              expected_ready,
		input signed [RESULT_WIDTH-1:0]    expected_result,
		input [255:0]                      test_name
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

endmodule
