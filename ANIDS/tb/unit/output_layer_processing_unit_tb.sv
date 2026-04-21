// ANIDS - Output Layer Processing Unit Testbench
`timescale 1ns/100ps
`include "anids_defines.vh"

module output_layer_processing_unit_tb;

	localparam INPUT_WIDTH    = `OL_INPUT_WIDTH;
	localparam WEIGHT_WIDTH   = `OL_WEIGHT_WIDTH;
	localparam BIAS_WIDTH     = `OL_BIAS_WIDTH;
	localparam RESULT_WIDTH   = `OL_RESULT_WIDTH;
	localparam COUNTER_WIDTH  = `PIPELINE_COUNTER_WIDTH;
	localparam ACC_WIDTH      = `OL_ACC_WIDTH;

	reg                               clk;
	reg                               resetN;
	reg                               enable;
	reg  [`APB_DATA_WIDTH-1:0]        N;
	reg  [COUNTER_WIDTH-1:0]          counter;
	reg  signed [INPUT_WIDTH-1:0]     hidden_in;
	reg  signed [WEIGHT_WIDTH-1:0]    weight;
	reg  signed [BIAS_WIDTH-1:0]      bias;
	wire signed [RESULT_WIDTH-1:0]    result;
	wire                              ready;

	output_layer_processing_unit dut (
		.clk       (clk),
		.resetN    (resetN),
		.enable    (enable),
		.N         (N),
		.counter   (counter),
		.hidden_in (hidden_in),
		.weight    (weight),
		.bias      (bias),
		.result    (result),
		.ready     (ready)
	);

	always #2.5 clk = ~clk;

	initial begin
		$dumpfile("output_layer_processing_unit_tb.vcd");
		$dumpvars(0, output_layer_processing_unit_tb);

		clk      = 1'b0;
		resetN   = 1'b0;
		enable   = 1'b0;
		N        = 8'd4;
		counter  = {COUNTER_WIDTH{1'b0}};
		hidden_in = '0;
		weight   = '0;
		bias     = '0;

		#2;
		check_outputs(1'b0, 8'sd0, "reset clears outputs");
		check_acc(15'sd0, "reset clears accumulator");

		resetN = 1'b1;
		@(posedge clk);
		#2;
		check_outputs(1'b0, 8'sd0, "idle after reset");

		run_basic_math_test;
		run_one_cycle_step_test;
		run_disable_reset_test;
		run_positive_saturation_test;
		run_negative_saturation_test;

		$display("OUTPUT_LAYER_PROCESSING_UNIT TB PASSED");
		$finish;
	end

	task run_basic_math_test;
	begin
		$display("SECTION: basic math");
		enable    = 1'b1;
		N         = 8'd4; // two cycles, last index = 1
		bias      = 8'sd1;
		counter   = 7'd0;
		hidden_in = 8'sd64;
		weight    = 8'sd64; // 0.5 * 0.5 -> 0.25 -> 32
		@(posedge clk);
		#2;
		check_acc(15'sd32, "first MAC contribution is accumulated in one cycle");
		check_outputs(1'b0, 8'sd0, "result stays unchanged before final cycle");

		counter   = 7'd1;
		hidden_in = 8'sd64;
		weight    = 8'sd64;
		@(posedge clk);
		#2;
		check_outputs(1'b1, 8'sd1, "two MAC steps produce expected biased result");
		check_acc(15'sd0, "accumulator clears after final cycle");
	end
	endtask

	task run_one_cycle_step_test;
	begin
		$display("SECTION: one-cycle completion");
		enable    = 1'b0;
		counter   = 7'd0;
		@(posedge clk);
		#2;

		enable    = 1'b1;
		N         = 8'd2; // one cycle, last index = 0
		counter   = 7'd0;
		bias      = 8'sd0;
		hidden_in = 8'sd127;
		weight    = 8'sd64; // ~0.992 * 0.5 -> truncated to 63
		@(posedge clk);
		#2;
		check_outputs(1'b1, 8'sd0, "single accumulation step finishes in one cycle");
		check_acc(15'sd0, "single-cycle completion clears accumulator");
	end
	endtask

	task run_disable_reset_test;
	begin
		$display("SECTION: disable behavior");
		enable    = 1'b0;
		counter   = 7'd0;
		hidden_in = 8'sd64;
		weight    = 8'sd64;
		@(posedge clk);
		#2;
		check_outputs(1'b0, 8'sd0, "ready drops after completion");
		check_outputs(1'b0, 8'sd0, "result holds when enable goes low");

		enable    = 1'b1;
		N         = 8'd4;
		bias      = 8'sd0;
		counter   = 7'd0;
		hidden_in = 8'sd64;
		weight    = 8'sd64;
		@(posedge clk);
		#2;
		check_acc(15'sd32, "accumulator restarts cleanly after re-enable");

		enable    = 1'b0;
		@(posedge clk);
		#2;
		check_acc(15'sd0, "disable clears in-progress accumulation");
	end
	endtask

	task run_positive_saturation_test;
		integer i;
	begin
		$display("SECTION: positive saturation");
		enable    = 1'b0;
		@(posedge clk);
		#2;

		enable    = 1'b1;
		N         = 8'd128; // 64 cycles
		bias      = 8'sd127;
		hidden_in = 8'sd127;
		weight    = 8'sd127;
		counter   = 7'd0;

		for (i = 0; i < 63; i = i + 1) begin
			@(posedge clk);
			#2;
			check_outputs(1'b0, result, "positive saturation stays busy before final cycle");
			counter = counter + 1'b1;
		end

		@(posedge clk);
		#2;
		check_outputs(1'b1, 8'sd127, "positive overflow saturates at +127");
		check_acc(15'sd0, "accumulator clears after positive saturation");
	end
	endtask

	task run_negative_saturation_test;
		integer i;
	begin
		$display("SECTION: negative saturation");
		enable    = 1'b0;
		@(posedge clk);
		#2;

		enable    = 1'b1;
		N         = 8'd128; // 64 cycles
		bias      = -8'sd127;
		hidden_in = -8'sd128;
		weight    = 8'sd127;
		counter   = 7'd0;

		for (i = 0; i < 63; i = i + 1) begin
			@(posedge clk);
			#2;
			counter = counter + 1'b1;
		end

		@(posedge clk);
		#2;
		check_outputs(1'b1, -8'sd128, "negative overflow saturates at -128");
		check_acc(15'sd0, "accumulator clears after negative saturation");
	end
	endtask

	task check_outputs(
		input                             expected_ready,
		input signed [RESULT_WIDTH-1:0]   expected_result,
		input [255:0]                     test_name
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

	task check_acc(
		input signed [ACC_WIDTH-1:0]      expected_acc,
		input [255:0]                     test_name
	);
	begin
		if (dut.acc !== expected_acc) begin
			$error("FAIL: %0s | acc=%0d expected_acc=%0d", test_name, dut.acc, expected_acc);
			$finish;
		end
		else begin
			$display("PASS: %0s", test_name);
		end
	end
	endtask

endmodule
