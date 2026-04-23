`timescale 1ns/100ps
`include "anids_defines.vh"

module loss_stage_regression_tb;
	localparam integer CASE_COUNT = 30;
	localparam string GENERATED_DIR = "Verification/math_regression/generated/loss";

	reg                                clk;
	reg                                resetN;
	reg                                enable;
	reg  [`APB_DATA_WIDTH-1:0]         N;
	reg  [`PIPELINE_COUNTER_WIDTH-1:0] counter;
	reg  [`LF_FEATURE_PAIR_WIDTH-1:0]  x_in;
	reg  signed [`LF_RESULT_IN_WIDTH-1:0] function_0;
	reg  signed [`LF_RESULT_IN_WIDTH-1:0] function_1;
	wire signed [`LF_OUT_WIDTH-1:0]    result;
	wire                               ready;
	reg  [`DMA_DATA_WIDTH-1:0]         vector_value;
	reg  signed [`LF_RESULT_IN_WIDTH-1:0] function_results [0:127];

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

	always #(`CLK_PERIOD/2) clk = ~clk;

	initial begin
		init_signals;
		run_all_cases;
		$display("RTL_LOSS_REGRESSION_DONE");
		$finish;
	end

	task init_signals;
	begin
		clk = 1'b0;
		resetN = 1'b0;
		enable = 1'b0;
		N = 8'd128;
		counter = '0;
		x_in = '0;
		function_0 = '0;
		function_1 = '0;
		vector_value = '0;
	end
	endtask

	task apply_reset;
	begin
		resetN = 1'b0;
		enable = 1'b0;
		counter = '0;
		x_in = '0;
		function_0 = '0;
		function_1 = '0;
		repeat (3) @(posedge clk);
		resetN = 1'b1;
		repeat (1) @(posedge clk);
	end
	endtask

	task run_all_cases;
		integer idx;
	begin
		for (idx = 0; idx < CASE_COUNT; idx = idx + 1)
			run_case(idx);
	end
	endtask

	task run_case(input integer idx);
		string vector_file;
		string output_file;
		string lut_file;
		integer step;
	begin
		apply_reset;
		vector_file = $sformatf("%0s/loss_%03d.vector", GENERATED_DIR, idx);
		output_file = $sformatf("%0s/loss_%03d.function", GENERATED_DIR, idx);
		load_vector_file(vector_file);
		load_function_file(output_file);

		enable = 1'b1;
		for (step = 0; step < 64; step = step + 1) begin
			counter = step[`PIPELINE_COUNTER_WIDTH-1:0];
			x_in = (vector_value >> (step * 2)) & 2'b11;
			function_0 = function_results[step * 2];
			function_1 = function_results[(step * 2) + 1];
			@(posedge clk);
			#2;
		end

		if (ready !== 1'b1) begin
			$error("Loss regression ready failure case=%0d", idx);
			$finish;
		end

		$display("RTL_LOSS case=loss_%03d loss=%0d", idx, result);
	end
	endtask

	task load_vector_file(input string fname);
		integer fd;
	begin
		fd = $fopen(fname, "r");
		if (fd == 0)
			$fatal(1, "Cannot open loss vector file: %0s", fname);
		if ($fscanf(fd, "%h\n", vector_value) != 1)
			$fatal(1, "Bad loss vector format: %0s", fname);
		$fclose(fd);
	end
	endtask

	task load_function_file(input string fname);
		integer fd;
		integer idx;
		integer rc;
		reg [7:0] raw;
	begin
		fd = $fopen(fname, "r");
		if (fd == 0)
			$fatal(1, "Cannot open loss function file: %0s", fname);
		for (idx = 0; idx < 128; idx = idx + 1) begin
			rc = $fscanf(fd, "%h\n", raw);
			if (rc != 1)
				$fatal(1, "Bad loss function format: %0s", fname);
			function_results[idx] = raw;
		end
		$fclose(fd);
	end
	endtask

endmodule
