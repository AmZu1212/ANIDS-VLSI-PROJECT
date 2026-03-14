// ANIDS - Loss Function Testbench
`timescale 1ns/100ps
`include "anids_defines.vh"

module loss_function_tb;

	localparam FEATURE_PAIR_WIDTH = `LF_FEATURE_PAIR_WIDTH;
	localparam RESULT_IN_WIDTH    = `LF_RESULT_IN_WIDTH;
	localparam RESULT_WIDTH       = `LF_OUT_WIDTH;
	localparam COUNTER_WIDTH      = `PIPELINE_COUNTER_WIDTH;
	localparam LUT_ADDR_WIDTH     = `LUT_ADDR_WIDTH;
	localparam LUT_DATA_WIDTH     = `LUT_DATA_WIDTH;
	localparam LUT_DEPTH          = (1 << LUT_ADDR_WIDTH);

	reg                               clk;
	reg                               resetN;
	reg                               enable;
	reg  [`APB_DATA_WIDTH-1:0]        N;
	reg  [COUNTER_WIDTH-1:0]          counter;
	reg  [LUT_ADDR_WIDTH-1:0]         lut_wr_addr;
	reg  [LUT_DATA_WIDTH-1:0]         lut_wr_data;
	reg                               lut_wr_en;
	reg  [FEATURE_PAIR_WIDTH-1:0]     x_in;
	reg  signed [RESULT_IN_WIDTH-1:0] result_0;
	reg  signed [RESULT_IN_WIDTH-1:0] result_1;
	wire signed [RESULT_WIDTH-1:0]    result;
	wire                              ready;

	reg  [LUT_DATA_WIDTH-1:0]         lut_file_ref [0:LUT_DEPTH-1];
	reg  [LUT_DATA_WIDTH-1:0]         lut_ref      [0:LUT_DEPTH-1];

	integer                           acc_model;
	integer                           step_sum;
	integer                           i;

	loss_function dut (
		.clk         (clk),
		.resetN      (resetN),
		.enable      (enable),
		.N           (N),
		.counter     (counter),
		.lut_wr_addr (lut_wr_addr),
		.lut_wr_data (lut_wr_data),
		.lut_wr_en   (lut_wr_en),
		.x_in        (x_in),
		.result_0    (result_0),
		.result_1    (result_1),
		.result      (result),
		.ready       (ready)
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
		lut_wr_addr= {LUT_ADDR_WIDTH{1'b0}};
		lut_wr_data= {LUT_DATA_WIDTH{1'b0}};
		lut_wr_en  = 1'b0;
		x_in       = {FEATURE_PAIR_WIDTH{1'b0}};
		result_0   = '0;
		result_1   = '0;
		acc_model  = 0;

		for (i = 0; i < LUT_DEPTH; i = i + 1) begin
			lut_file_ref[i] = {LUT_DATA_WIDTH{1'b0}};
			lut_ref[i]      = {LUT_DATA_WIDTH{1'b0}};
		end

		#2;
		check_outputs(1'b0, 8'sd0, "reset clears outputs");

		resetN = 1'b1;
		@(posedge clk);
		#2;
		check_outputs(1'b0, 8'sd0, "idle after reset");

		$readmemh("ANIDS/tb/data/sigmoid_lut.data", lut_file_ref, 0, 127);
		load_lut_from_file;

		run_real_lut_single_pair_test;
		run_real_lut_two_pair_test;
		run_negative_function_override_test;

		$display("LOSS_FUNCTION TB PASSED");
		$finish;
	end

	task run_real_lut_single_pair_test;
		integer expected;
	begin
		$display("SECTION: real LUT single-pair");
		reset_runtime_only;

		N        = 8'd2; // one pair-step
		enable   = 1'b1;
		counter  = 7'd0;
		x_in     = 2'b00;
		result_0 = 8'sd0;
		result_1 = 8'sd1;

		expected = trunc8_value(model_pair_loss(x_in, result_0, result_1));

		@(posedge clk);
		#2;
		check_outputs(1'b1, expected[RESULT_WIDTH-1:0], "single pair uses mapped LUT outputs");

		enable = 1'b0;
		@(posedge clk);
		#2;
		check_outputs(1'b0, expected[RESULT_WIDTH-1:0], "result holds after disable");
	end
	endtask

	task run_real_lut_two_pair_test;
		integer expected;
	begin
		$display("SECTION: real LUT two-pair accumulation");
		reset_runtime_only;

		N        = 8'd4; // two pair-steps
		enable   = 1'b1;
		counter  = 7'd0;
		x_in     = 2'b01;
		result_0 = -8'sd64;
		result_1 = 8'sd32;
		acc_model = model_pair_loss(x_in, result_0, result_1);

		@(posedge clk);
		#2;
		check_outputs(1'b0, 8'sd0, "first pair accumulates without ready");

		counter  = 7'd1;
		x_in     = 2'b10;
		result_0 = 8'sd64;
		result_1 = -8'sd32;
		acc_model = acc_model + model_pair_loss(x_in, result_0, result_1);
		expected = trunc8_value(acc_model);

		@(posedge clk);
		#2;
		check_outputs(1'b1, expected[RESULT_WIDTH-1:0], "two-pair accumulation matches reference model");
	end
	endtask

	task run_negative_function_override_test;
		integer expected;
	begin
		$display("SECTION: signed function LUT outputs");
		reset_runtime_only;

		// Overwrite two LUT entries with negative values to verify sign handling.
		write_lut(8'd128, -8'sd32);
		write_lut(8'd129, -8'sd64);

		N        = 8'd2;
		enable   = 1'b1;
		counter  = 7'd0;
		x_in     = 2'b11;
		result_0 = 8'sd0;  // maps to address 128
		result_1 = 8'sd1;  // maps to address 129

		expected = trunc8_value(model_pair_loss(x_in, result_0, result_1));

		@(posedge clk);
		#2;
		check_outputs(1'b1, expected[RESULT_WIDTH-1:0], "negative function outputs are sign-extended correctly");
	end
	endtask

	task reset_runtime_only;
	begin
		enable    = 1'b0;
		counter   = {COUNTER_WIDTH{1'b0}};
		x_in      = {FEATURE_PAIR_WIDTH{1'b0}};
		result_0  = '0;
		result_1  = '0;
		acc_model = 0;
		@(posedge clk);
		#2;
	end
	endtask

	task write_lut(
		input [LUT_ADDR_WIDTH-1:0] addr,
		input [LUT_DATA_WIDTH-1:0] data
	);
	begin
		@(posedge clk);
		lut_wr_addr = addr;
		lut_wr_data = data;
		lut_wr_en   = 1'b1;
		lut_ref[addr] = data;
		@(posedge clk);
		#2;
		lut_wr_en   = 1'b0;
	end
	endtask

	task load_lut_from_file;
	begin
		for (i = 0; i < LUT_DEPTH; i = i + 1) begin
			write_lut(i[LUT_ADDR_WIDTH-1:0], lut_file_ref[i]);
		end
	end
	endtask

	function [LUT_ADDR_WIDTH-1:0] map_addr;
		input signed [RESULT_IN_WIDTH-1:0] value;
	begin
		if (LUT_ADDR_WIDTH == RESULT_IN_WIDTH) begin
			map_addr = {~value[RESULT_IN_WIDTH-1], value[RESULT_IN_WIDTH-2:0]};
		end
		else begin
			map_addr = {~value[RESULT_IN_WIDTH-1], value[RESULT_IN_WIDTH-2:1]};
		end
	end
	endfunction

	function integer signed_lut_value;
		input [LUT_ADDR_WIDTH-1:0] addr;
	begin
		signed_lut_value = $signed(lut_ref[addr]);
	end
	endfunction

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
		input signed [RESULT_IN_WIDTH-1:0]        pair_r0;
		input signed [RESULT_IN_WIDTH-1:0]        pair_r1;
		integer fx0;
		integer fx1;
	begin
		fx0 = signed_lut_value(map_addr(pair_r0));
		fx1 = signed_lut_value(map_addr(pair_r1));
		model_pair_loss =
			abs_int((pair_x[0] ? 1 : 0) - fx0) +
			abs_int((pair_x[1] ? 1 : 0) - fx1);
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
