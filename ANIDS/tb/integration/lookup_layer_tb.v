`timescale 1ns/100ps
`include "anids_defines.vh"

module lookup_layer_tb;

	localparam RESULT_IN_WIDTH  = `LF_RESULT_IN_WIDTH;
	localparam RESULT_OUT_WIDTH = `LUT_DATA_WIDTH;
	localparam LUT_ADDR_WIDTH   = `LUT_ADDR_WIDTH;
	localparam COUNTER_WIDTH    = `PIPELINE_COUNTER_WIDTH;

	reg                               clk;
	reg                               resetN;
	reg                               lookup_enable;
	reg                               loss_enable;
	reg  [`APB_DATA_WIDTH-1:0]        N;
	reg  [COUNTER_WIDTH-1:0]          counter;
	reg  [LUT_ADDR_WIDTH-1:0]         lut_wr_addr;
	reg  [RESULT_OUT_WIDTH-1:0]       lut_wr_data;
	reg                               lut_wr_en;
	reg  signed [RESULT_IN_WIDTH-1:0] result_0;
	reg  signed [RESULT_IN_WIDTH-1:0] result_1;
	wire signed [RESULT_OUT_WIDTH-1:0] function_0;
	wire signed [RESULT_OUT_WIDTH-1:0] function_1;
	wire                              lookup_ready;

	lookup_layer dut (
		.clk           (clk),
		.resetN        (resetN),
		.lookup_enable (lookup_enable),
		.loss_enable   (loss_enable),
		.N             (N),
		.counter       (counter),
		.lut_wr_addr   (lut_wr_addr),
		.lut_wr_data   (lut_wr_data),
		.lut_wr_en     (lut_wr_en),
		.result_0      (result_0),
		.result_1      (result_1),
		.function_0    (function_0),
		.function_1    (function_1),
		.lookup_ready  (lookup_ready)
	);

	initial clk = 1'b0;
	always #(`CLK_PERIOD/2.0) clk = ~clk;

	initial begin
		$dumpfile("lookup_layer_tb.vcd");
		$dumpvars(0, lookup_layer_tb);

		resetN        = 1'b0;
		lookup_enable = 1'b0;
		loss_enable   = 1'b0;
		N             = 8'd4;
		counter       = {COUNTER_WIDTH{1'b0}};
		lut_wr_addr   = {LUT_ADDR_WIDTH{1'b0}};
		lut_wr_data   = {RESULT_OUT_WIDTH{1'b0}};
		lut_wr_en     = 1'b0;
		result_0      = {RESULT_IN_WIDTH{1'b0}};
		result_1      = {RESULT_IN_WIDTH{1'b0}};

		repeat (2) @(posedge clk);
		#2;
		check_equal_signed(function_0, 0, "reset keeps function_0 low");
		check_equal_signed(function_1, 0, "reset keeps function_1 low");
		check_equal_bit(lookup_ready, 1'b0, "reset keeps ready low");

		resetN = 1'b1;
		repeat (1) @(posedge clk);
		#2;
		check_equal_signed(function_0, 0, "idle function_0 stays low");
		check_equal_signed(function_1, 0, "idle function_1 stays low");
		check_equal_bit(lookup_ready, 1'b0, "idle ready stays low");

		// Program the LUT entries used by the first bank.
		write_lut_entry(mapped_addr(-128), 8'h11);
		write_lut_entry(mapped_addr(0),    8'h22);
		write_lut_entry(mapped_addr(127),  8'h33);
		write_lut_entry(mapped_addr(-1),   8'h44);

		// Program the LUT entries used by the second bank.
		write_lut_entry(mapped_addr(1),    8'h55);
		write_lut_entry(mapped_addr(-64),  8'h66);
		write_lut_entry(mapped_addr(32),   8'h77);
		write_lut_entry(mapped_addr(-32),  8'h88);

		// Reprogram zero so both LUT lanes prove the shared write path.
		write_lut_entry(mapped_addr(0),    8'h99);

		// First lookup bank: pairs (0,1) and (2,3). Loss side should still be invalid.
		drive_lookup_cycle(0, -128,   0, 0);
		check_equal_signed(function_0, 0, "loss output hidden during first lookup pair");
		check_equal_signed(function_1, 0, "loss output hidden during first lookup pair");
		check_equal_bit(lookup_ready, 1'b0, "ready low before first bank completes");

		drive_lookup_cycle(1,  127,  -1, 0);
		check_equal_signed(function_0, 0, "loss output hidden during second lookup pair");
		check_equal_signed(function_1, 0, "loss output hidden during second lookup pair");
		check_equal_bit(lookup_ready, 1'b0, "ready low while last address is still in flight");

		idle_cycle(0, 0);
		check_equal_bit(lookup_ready, 1'b1, "ready pulses when the first bank is captured");

		// Read back bank 0 by pair.
		drive_loss_cycle(0);
		check_equal_signed(function_0, 8'sh11, "bank0 pair0 lane0 value");
		check_equal_signed(function_1, 8'sh99, "bank0 pair0 lane1 value uses rewritten zero entry");
		check_equal_bit(lookup_ready, 1'b0, "ready returns low after pulse");

		drive_loss_cycle(1);
		check_equal_signed(function_0, 8'sh33, "bank0 pair1 lane0 value");
		check_equal_signed(function_1, 8'sh44, "bank0 pair1 lane1 value");

		idle_cycle(0, 0);
		check_equal_signed(function_0, 0, "loss outputs clear when loss_enable drops");
		check_equal_signed(function_1, 0, "loss outputs clear when loss_enable drops");

		// While loss reads bank 0, fill bank 1 using the same shared counter.
		drive_overlap_cycle(0, 1,  -64);
		check_equal_signed(function_0, 8'sh11, "bank0 pair0 lane0 stays stable during bank1 write");
		check_equal_signed(function_1, 8'sh99, "bank0 pair0 lane1 stays stable during bank1 write");
		check_equal_bit(lookup_ready, 1'b0, "ready low while second bank is in flight");

		drive_overlap_cycle(1, 32, -32);
		check_equal_bit(lookup_ready, 1'b0, "ready still low before second bank capture");

		idle_cycle(0, 1);
		check_equal_bit(lookup_ready, 1'b1, "ready pulses when the second bank is captured");

		// Read back bank 1 and confirm the read bank swapped.
		drive_loss_cycle(0);
		check_equal_signed(function_0, 8'sh55, "bank1 pair0 lane0 value");
		check_equal_signed(function_1, 8'sh66, "bank1 pair0 lane1 value");

		drive_loss_cycle(1);
		check_equal_signed(function_0, 8'sh77, "bank1 pair1 lane0 value");
		check_equal_signed(function_1, 8'sh88, "bank1 pair1 lane1 value");

		$display("LOOKUP_LAYER TB PASSED");
		$finish;
	end

	task write_lut_entry(
		input [LUT_ADDR_WIDTH-1:0] addr,
		input [RESULT_OUT_WIDTH-1:0] data
	);
	begin
		@(negedge clk);
		lookup_enable = 1'b0;
		loss_enable   = 1'b0;
		counter       = {COUNTER_WIDTH{1'b0}};
		lut_wr_addr   = addr;
		lut_wr_data   = data;
		lut_wr_en     = 1'b1;
		@(posedge clk);
		#2;
		@(negedge clk);
		lut_wr_en     = 1'b0;
	end
	endtask

	task drive_lookup_cycle(
		input [COUNTER_WIDTH-1:0] pair_idx,
		input signed [RESULT_IN_WIDTH-1:0] pair_result_0,
		input signed [RESULT_IN_WIDTH-1:0] pair_result_1,
		input loss_active
	);
	begin
		@(negedge clk);
		counter       = pair_idx;
		result_0      = pair_result_0;
		result_1      = pair_result_1;
		lookup_enable = 1'b1;
		loss_enable   = loss_active;
		@(posedge clk);
		#2;
	end
	endtask

	task drive_loss_cycle(
		input [COUNTER_WIDTH-1:0] pair_idx
	);
	begin
		@(negedge clk);
		counter       = pair_idx;
		lookup_enable = 1'b0;
		loss_enable   = 1'b1;
		@(posedge clk);
		#2;
	end
	endtask

	task drive_overlap_cycle(
		input [COUNTER_WIDTH-1:0] pair_idx,
		input signed [RESULT_IN_WIDTH-1:0] pair_result_0,
		input signed [RESULT_IN_WIDTH-1:0] pair_result_1
	);
	begin
		@(negedge clk);
		counter       = pair_idx;
		result_0      = pair_result_0;
		result_1      = pair_result_1;
		lookup_enable = 1'b1;
		loss_enable   = 1'b1;
		@(posedge clk);
		#2;
	end
	endtask

	task idle_cycle(
		input lookup_active,
		input loss_active
	);
	begin
		@(negedge clk);
		lookup_enable = lookup_active;
		loss_enable   = loss_active;
		@(posedge clk);
		#2;
	end
	endtask

	task check_equal_signed(
		input signed [RESULT_OUT_WIDTH-1:0] actual,
		input integer expected,
		input [255:0] test_name
	);
	begin
		if ($signed(actual) !== expected) begin
			$error("FAIL: %0s | actual=%0d expected=%0d", test_name, $signed(actual), expected);
			$finish;
		end
	end
	endtask

	task check_equal_bit(
		input actual,
		input expected,
		input [255:0] test_name
	);
	begin
		if (actual !== expected) begin
			$error("FAIL: %0s | actual=%0b expected=%0b", test_name, actual, expected);
			$finish;
		end
	end
	endtask

	function [LUT_ADDR_WIDTH-1:0] mapped_addr(
		input signed [RESULT_IN_WIDTH-1:0] value
	);
	begin
		mapped_addr = {~value[RESULT_IN_WIDTH-1], value[RESULT_IN_WIDTH-2:0]};
	end
	endfunction

endmodule
