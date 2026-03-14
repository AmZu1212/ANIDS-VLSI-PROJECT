// ANIDS - Output Layer Integration Testbench
`timescale 1ns/100ps
`include "anids_defines.vh"

module output_layer_tb;

	localparam INPUT_WIDTH    = `OL_INPUT_WIDTH;
	localparam RESULT_WIDTH   = `OL_RESULT_WIDTH;
	localparam COUNTER_WIDTH  = `PIPELINE_COUNTER_WIDTH;
	localparam INPUT_COUNT    = 64;
	localparam NEURON_COUNT   = 128;

	reg                                  clk;
	reg                                  resetN;
	reg                                  enable;
	reg  [`APB_DATA_WIDTH-1:0]           N;
	reg  [COUNTER_WIDTH-1:0]             counter;
	reg  signed [INPUT_WIDTH-1:0]        hidden_results [0:INPUT_COUNT-1];

	reg  [`APB_ADDR_WIDTH-1:0]           paddr;
	reg  [`APB_DATA_WIDTH-1:0]           pwdata;
	wire [`APB_DATA_WIDTH-1:0]           prdata;
	reg                                  psel;
	reg                                  penable;
	reg                                  pwrite;
	wire                                 pready;
	wire signed [`APB_DATA_WIDTH-1:0]    regfile_bus [0:`REG_COUNT-1];

	wire signed [RESULT_WIDTH-1:0]       results [0:NEURON_COUNT-1];
	wire                                 ready   [0:NEURON_COUNT-1];

	regfile regfile_inst (
		.pclk    (clk),
		.presetN (resetN),
		.paddr   (paddr),
		.pwdata  (pwdata),
		.prdata  (prdata),
		.psel    (psel),
		.penable (penable),
		.pwrite  (pwrite),
		.pready  (pready),
		.hw_wr_en   (1'b0),
		.hw_wr_addr ({`APB_ADDR_WIDTH{1'b0}}),
		.hw_wr_data ({`APB_DATA_WIDTH{1'b0}}),
		.regfile (regfile_bus)
	);

	output_layer dut (
		.clk            (clk),
		.resetN         (resetN),
		.enable         (enable),
		.N              (N),
		.hidden_results (hidden_results),
		.counter        (counter),
		.regfile        (regfile_bus),
		.results        (results),
		.ready          (ready)
	);

	always #2.5 clk = ~clk;

	initial begin
		$dumpfile("output_layer_tb.vcd");
		$dumpvars(0, output_layer_tb);

		init_tb;

		run_reset_and_idle_tests;
		run_math_and_index_tests;
		run_weight_select_tests;
		run_hold_behavior_tests;

		$display("OUTPUT_LAYER TB PASSED");
		$finish;
	end

	task init_tb;
		integer i;
	begin
		clk      = 1'b0;
		resetN   = 1'b0;
		enable   = 1'b0;
		N        = 8'd4; // two cycles for short tests
		counter  = {COUNTER_WIDTH{1'b0}};
		paddr    = '0;
		pwdata   = '0;
		psel     = 1'b0;
		penable  = 1'b0;
		pwrite   = 1'b0;

		for (i = 0; i < INPUT_COUNT; i = i + 1) begin
			hidden_results[i] = '0;
		end
	end
	endtask

	task reset_dut;
		integer i;
	begin
		resetN   = 1'b0;
		enable   = 1'b0;
		counter  = {COUNTER_WIDTH{1'b0}};
		for (i = 0; i < INPUT_COUNT; i = i + 1) begin
			hidden_results[i] = '0;
		end
		#2;
		resetN   = 1'b1;
		@(posedge clk);
		#2;
	end
	endtask

	task run_reset_and_idle_tests;
	begin
		$display("SECTION: reset and idle");
		reset_dut;
		check_neuron(0, 1'b0, 8'sd0, "reset clears neuron 0");
		check_neuron(1, 1'b0, 8'sd0, "reset clears neuron 1");
		check_neuron(2, 1'b0, 8'sd0, "reset clears neuron 2");
	end
	endtask

	task run_math_and_index_tests;
	begin
		$display("SECTION: math and indexing");
		reset_dut;

		hidden_results[0] = 8'sd64;
		hidden_results[1] = 8'sd64;

		// Neuron 0: two 0.5*0.5 products -> 32 + 32, bias 1 -> result 1
		cpu_write_APB(`OL_WEIGHT_BASE + 0, 8'd64);
		cpu_write_APB(`OL_WEIGHT_BASE + 1, 8'd64);
		cpu_write_APB(`OL_BIAS_BASE + 0, 8'd1);

		// Neuron 1: first cycle only because second weight slot is zero -> result 0
		cpu_write_APB(`OL_WEIGHT_BASE + 64 + 0, 8'd64);

		// Neuron 2: bias-only result -> 5
		cpu_write_APB(`OL_BIAS_BASE + 2, 8'd5);

		enable  = 1'b1;
		counter = 7'd0;
		@(posedge clk);
		#2;
		check_neuron(0, 1'b0, 8'sd0, "math: neuron 0 accumulates first hidden result");
		check_neuron(1, 1'b0, 8'sd0, "math: neuron 1 accumulates first hidden result");

		counter = 7'd1;
		@(posedge clk);
		#2;
		check_neuron(0, 1'b1, 8'sd1, "math: neuron 0 completes with expected biased result");
		check_neuron(1, 1'b1, 8'sd0, "indexing: neuron 1 uses its own weight block");
		check_neuron(2, 1'b1, 8'sd5, "math: neuron 2 completes from bias only");
	end
	endtask

	task run_weight_select_tests;
	begin
		$display("SECTION: weight selection");
		reset_dut;
		N = 8'd8; // four cycles, last index = 3

		hidden_results[0] = 8'sd64;
		hidden_results[1] = 8'sd64;
		hidden_results[2] = 8'sd64;
		hidden_results[3] = 8'sd64;

		// Neuron 3: only weight slot 3 should contribute -> result 0 after one 32 contribution
		cpu_write_APB(`OL_WEIGHT_BASE + (3 * 64) + 3, 8'd64);

		// Neuron 4: only weight slot 2 and bias 1 -> final result 1
		cpu_write_APB(`OL_WEIGHT_BASE + (4 * 64) + 2, 8'd64);
		cpu_write_APB(`OL_BIAS_BASE + 4, 8'd1);

		enable  = 1'b1;
		counter = 7'd0;
		@(posedge clk);
		#2;
		check_neuron(3, 1'b0, 8'sd0, "selection: neuron 3 ignores early hidden slots");
		check_neuron(4, 1'b0, 8'sd0, "selection: neuron 4 ignores slot 0");

		counter = 7'd1;
		@(posedge clk);
		#2;
		check_neuron(3, 1'b0, 8'sd0, "selection: neuron 3 still idle at slot 1");
		check_neuron(4, 1'b0, 8'sd0, "selection: neuron 4 still idle at slot 1");

		counter = 7'd2;
		@(posedge clk);
		#2;
		check_neuron(3, 1'b0, 8'sd0, "selection: neuron 3 still waiting for slot 3");
		check_neuron(4, 1'b0, 8'sd0, "selection: neuron 4 accumulates only at slot 2");

		counter = 7'd3;
		@(posedge clk);
		#2;
		check_neuron(3, 1'b1, 8'sd0, "selection: neuron 3 reads the programmed late slot");
		check_neuron(4, 1'b1, 8'sd1, "selection: neuron 4 late result includes bias");
	end
	endtask

	task run_hold_behavior_tests;
	begin
		$display("SECTION: hold and ready behavior");
		enable  = 1'b0;
		counter = 7'd0;
		@(posedge clk);
		#2;
		check_neuron(3, 1'b0, 8'sd0, "control: ready drops after completion");
		check_neuron(4, 1'b0, 8'sd1, "control: result holds after disable");
	end
	endtask

	task cpu_write_APB(
		input [`APB_ADDR_WIDTH-1:0] addr,
		input [`APB_DATA_WIDTH-1:0] data
	);
	begin
		@(posedge clk);
		paddr   <= #1 addr;
		pwdata  <= #1 data;
		psel    <= #1 1'b1;
		penable <= #1 1'b0;
		pwrite  <= #1 1'b1;

		@(posedge clk);
		penable <= #1 1'b1;

		while (!pready)
			@(posedge clk);

		@(posedge clk);
		psel    <= #1 1'b0;
		penable <= #1 1'b0;
		pwrite  <= #1 1'b0;
	end
	endtask

	task check_neuron(
		input integer                          idx,
		input                                  expected_ready,
		input signed [RESULT_WIDTH-1:0]        expected_result,
		input [255:0]                          test_name
	);
	begin
		if (ready[idx] !== expected_ready || results[idx] !== expected_result) begin
			$error("FAIL: %0s | neuron=%0d ready=%0b expected_ready=%0b result=%0d expected_result=%0d",
				test_name, idx, ready[idx], expected_ready, results[idx], expected_result);
			$finish;
		end
		else begin
			$display("PASS: %0s", test_name);
		end
	end
	endtask

endmodule
