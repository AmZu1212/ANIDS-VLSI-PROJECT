`timescale 1ns/100ps
`include "anids_defines.vh"

module output_stage_regression_tb;
	localparam integer CASE_COUNT = 30;
	localparam string GENERATED_DIR = "verification/math_regression/generated/output";

	reg                                  clk;
	reg                                  resetN;
	reg                                  enable;
	reg  [`APB_DATA_WIDTH-1:0]           N;
	reg  [`PIPELINE_COUNTER_WIDTH-1:0]   counter;
	reg  signed [`APB_DATA_WIDTH-1:0]    regfile_bus [0:`REG_COUNT-1];
	reg  signed [`OL_INPUT_WIDTH-1:0]    hidden_inputs [0:63];
	wire signed [`OL_RESULT_WIDTH-1:0]   results [0:127];
	wire                                 ready [0:127];

	output_layer dut (
		.clk            (clk),
		.resetN         (resetN),
		.enable         (enable),
		.N              (N),
		.hidden_results (hidden_inputs),
		.counter        (counter),
		.regfile        (regfile_bus),
		.results        (results),
		.ready          (ready)
	);

	always #(`CLK_PERIOD/2) clk = ~clk;

	initial begin
		init_signals;
		run_all_cases;
		$display("RTL_OUTPUT_REGRESSION_DONE");
		$finish;
	end

	task init_signals;
	begin
		clk = 1'b0;
		resetN = 1'b0;
		enable = 1'b0;
		N = 8'd128;
		counter = '0;
	end
	endtask

	task apply_reset;
		integer reg_idx;
		integer hidden_idx;
	begin
		resetN = 1'b0;
		enable = 1'b0;
		counter = '0;
		for (reg_idx = 0; reg_idx < `REG_COUNT; reg_idx = reg_idx + 1)
			regfile_bus[reg_idx] = '0;
		for (hidden_idx = 0; hidden_idx < 64; hidden_idx = hidden_idx + 1)
			hidden_inputs[hidden_idx] = '0;
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
		string prog_file;
		string hidden_file;
		integer step;
		integer neuron;
	begin
		apply_reset;
		prog_file = $sformatf("%0s/output_%03d.prog", GENERATED_DIR, idx);
		hidden_file = $sformatf("%0s/output_%03d.hidden", GENERATED_DIR, idx);
		run_program_file(prog_file);
		load_hidden_file(hidden_file);

		enable = 1'b1;
		for (step = 0; step < 64; step = step + 1) begin
			counter = step[`PIPELINE_COUNTER_WIDTH-1:0];
			@(posedge clk);
			#2;
		end

		for (neuron = 0; neuron < 128; neuron = neuron + 1) begin
			if (ready[neuron] !== 1'b1) begin
				$error("Output regression ready failure case=%0d neuron=%0d", idx, neuron);
				$finish;
			end
		end

		$write("RTL_OUTPUT case=output_%03d data=", idx);
		for (neuron = 0; neuron < 128; neuron = neuron + 1)
			$write("%02x", results[neuron][7:0]);
		$write("\n");
	end
	endtask

	task run_program_file(input string fname);
		integer fd;
		integer rc;
		reg [`APB_ADDR_WIDTH-1:0] addr;
		reg [`APB_DATA_WIDTH-1:0] data;
	begin
		fd = $fopen(fname, "r");
		if (fd == 0)
			$fatal(1, "Cannot open output program file: %0s", fname);
		while (!$feof(fd)) begin
			rc = $fscanf(fd, "%h %h\n", addr, data);
			if (rc == 2)
				regfile_bus[addr] = $signed(data);
		end
		$fclose(fd);
	end
	endtask

	task load_hidden_file(input string fname);
		integer fd;
		integer idx;
		integer rc;
		reg [7:0] raw;
	begin
		fd = $fopen(fname, "r");
		if (fd == 0)
			$fatal(1, "Cannot open hidden input file: %0s", fname);
		for (idx = 0; idx < 64; idx = idx + 1) begin
			rc = $fscanf(fd, "%h\n", raw);
			if (rc != 1)
				$fatal(1, "Bad hidden input format: %0s", fname);
			hidden_inputs[idx] = raw;
		end
		$fclose(fd);
	end
	endtask

endmodule
