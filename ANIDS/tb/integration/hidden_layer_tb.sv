// ANIDS - Hidden Layer Integration Testbench
`timescale 1ns/100ps
`include "anids_defines.vh"

module hidden_layer_tb;

	localparam FEATURE_PAIR_WIDTH = `HL_FEATURE_PAIR_WIDTH;
	localparam RESULT_WIDTH       = `HL_RESULT_WIDTH;
	localparam COUNTER_WIDTH      = `PIPELINE_COUNTER_WIDTH;
	localparam NEURON_COUNT       = 64;
	localparam N_WIDTH            = `APB_DATA_WIDTH;

	reg                                  clk;
	reg                                  resetN;
	reg                                  enable;
	reg  [N_WIDTH-1:0]                   N;
	reg  [FEATURE_PAIR_WIDTH-1:0]        features;
	reg  [COUNTER_WIDTH-1:0]             counter;

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

	hidden_layer dut (
		.clk      (clk),
		.resetN   (resetN),
		.enable   (enable),
		.N        (N),
		.features (features),
		.counter  (counter),
		.regfile  (regfile_bus),
		.results  (results),
		.ready    (ready)
	);

	always #2.5 clk = ~clk;

	initial begin
		$dumpfile("hidden_layer_tb.vcd");
		$dumpvars(0, hidden_layer_tb);

		init_tb;

		run_math_and_gating_tests;
		run_weight_index_tests;
		run_ready_control_tests;

		$display("HIDDEN_LAYER TB PASSED");
		$finish;
	end

	task init_tb;
	begin
		clk      = 1'b0;
		resetN   = 1'b0;
		enable   = 1'b0;
		N        = 8'd4;
		features = 2'b00;
		counter  = {COUNTER_WIDTH{1'b0}};
		paddr    = '0;
		pwdata   = '0;
		psel     = 1'b0;
		penable  = 1'b0;
		pwrite   = 1'b0;
	end
	endtask

	task reset_dut;
	begin
		resetN   = 1'b0;
		enable   = 1'b0;
		features = 2'b00;
		counter  = {COUNTER_WIDTH{1'b0}};
		#2;
		resetN   = 1'b1;
		@(posedge clk);
		#2;
	end
	endtask

	task run_math_and_gating_tests;
	begin
		$display("SECTION: math and feature gating");
		reset_dut;

		// Neuron 0:
		// pair0 -> w0=64, w1=32
		// pair1 -> w2=64, w3=64
		// bias   -> 1
		// acc = 224, trunc8 = 1, result = 2
		cpu_write_APB(`HL_WEIGHT_BASE + 0, 8'd64);
		cpu_write_APB(`HL_WEIGHT_BASE + 1, 8'd32);
		cpu_write_APB(`HL_WEIGHT_BASE + 2, 8'd64);
		cpu_write_APB(`HL_WEIGHT_BASE + 3, 8'd64);
		cpu_write_APB(`HL_BIAS_BASE + 0, 8'd1);

		// Neuron 1:
		// only feature[1] should contribute
		// pair0 -> w0=100, w1=64
		// pair1 -> w2=100, w3=64
		// bias   -> 0
		// with features=2'b10 for both cycles, acc = 128, result = 1
		cpu_write_APB(`HL_WEIGHT_BASE + 128 + 0, 8'd100);
		cpu_write_APB(`HL_WEIGHT_BASE + 128 + 1, 8'd64);
		cpu_write_APB(`HL_WEIGHT_BASE + 128 + 2, 8'd100);
		cpu_write_APB(`HL_WEIGHT_BASE + 128 + 3, 8'd64);

		// Neuron 2:
		// no active features contribute, bias only -> 5
		cpu_write_APB(`HL_BIAS_BASE + 2, 8'd5);

		enable   = 1'b1;
		features = 2'b10;
		counter  = 7'd0;
		@(posedge clk);
		#2;
		check_neuron(0, 1'b0, 8'sd0, "math: neuron 0 accumulates first pair");
		check_neuron(1, 1'b0, 8'sd0, "gating: neuron 1 accumulates first pair");

		features = 2'b11;
		counter  = 7'd1;
		@(posedge clk);
		#2;
		check_neuron(0, 1'b1, 8'sd2, "math: neuron 0 completes with expected result");
		check_neuron(1, 1'b1, 8'sd1, "gating: neuron 1 ignores feature[0] weights");
		check_neuron(2, 1'b1, 8'sd5, "math: neuron 2 completes from bias only");
	end
	endtask

	task run_weight_index_tests;
	begin
		$display("SECTION: weight indexing");
		reset_dut;
		N = 8'd8; // 4 pair-steps, last pair index is 3

		// Neuron 3: only pair index 3 should contribute -> result 1
		cpu_write_APB(`HL_WEIGHT_BASE + (3 * 128) + 6, 8'd64);
		cpu_write_APB(`HL_WEIGHT_BASE + (3 * 128) + 7, 8'd64);

		// Neuron 4: only pair index 2 should contribute -> result 1
		cpu_write_APB(`HL_WEIGHT_BASE + (4 * 128) + 4, 8'd64);
		cpu_write_APB(`HL_WEIGHT_BASE + (4 * 128) + 5, 8'd64);

		enable   = 1'b1;
		features = 2'b11;
		counter  = 7'd0;
		@(posedge clk);
		#2;
		check_neuron(3, 1'b0, 8'sd0, "indexing: neuron 3 ignores early weight slots");
		check_neuron(4, 1'b0, 8'sd0, "indexing: neuron 4 ignores pair 0");

		counter  = 7'd1;
		@(posedge clk);
		#2;
		check_neuron(3, 1'b0, 8'sd0, "indexing: neuron 3 still idle at pair 1");
		check_neuron(4, 1'b0, 8'sd0, "indexing: neuron 4 still below threshold after pair 1");

		counter  = 7'd2;
		@(posedge clk);
		#2;
		check_neuron(3, 1'b0, 8'sd0, "indexing: neuron 3 still waiting for pair 3");
		check_neuron(4, 1'b0, 8'sd0, "indexing: neuron 4 accumulates its programmed pair");

		counter  = 7'd3;
		@(posedge clk);
		#2;
		check_neuron(3, 1'b1, 8'sd1, "indexing: neuron 3 reads pair-3 weights");
		check_neuron(4, 1'b1, 8'sd1, "indexing: neuron 4 reads pair-2 weights");
	end
	endtask

	task run_ready_control_tests;
	begin
		$display("SECTION: ready and hold behavior");
		enable   = 1'b0;
		counter  = 7'd0;
		features = 2'b00;
		@(posedge clk);
		#2;
		check_neuron(3, 1'b0, 8'sd1, "control: ready drops after completion");
		check_neuron(4, 1'b0, 8'sd1, "control: result holds after enable drops");
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
