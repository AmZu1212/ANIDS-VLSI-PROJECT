// ANIDS - Pipeline Manager Testbench
`timescale 1ns/100ps
`include "anids_defines.vh"

module pipeline_manager_tb;

	localparam VECTOR_WIDTH  = `PIPELINE_VECTOR_WIDTH;
	localparam COUNTER_WIDTH = `PIPELINE_COUNTER_WIDTH;

	reg                         clk;
	reg                         resetN;
	reg                         start;
	reg  [`APB_DATA_WIDTH-1:0]  N;
	reg                         valid;
	reg  [VECTOR_WIDTH-1:0]     mem_data;
	wire                        fetch;
	wire                        hidden_layer_enable;
	wire                        output_layer_enable;
	wire                        loss_layer_enable;
	wire                        mfu_ready;
	wire [VECTOR_WIDTH-1:0]     mfu_features;
	wire                        mfu_updated;
	wire [VECTOR_WIDTH-1:0]     next_vector;
	wire [VECTOR_WIDTH-1:0]     validate_vector;
	wire [COUNTER_WIDTH-1:0]    counter;

	pipeline_manager #(
		.VECTOR_WIDTH  (VECTOR_WIDTH),
		.COUNTER_WIDTH (COUNTER_WIDTH)
	) dut (
		.clk             (clk),
		.resetN          (resetN),
		.start           (start),
		.N               (N),
		.mfu_features    (mfu_features),
		.mfu_updated     (mfu_updated),
		.fetch               (fetch),
		.hidden_layer_enable (hidden_layer_enable),
		.output_layer_enable (output_layer_enable),
		.loss_layer_enable   (loss_layer_enable),
		.next_vector         (next_vector),
		.validate_vector     (validate_vector),
		.counter             (counter)
	);

	mem_fetch_unit #(
		.DATA_WIDTH    (VECTOR_WIDTH),
		.FEATURE_WIDTH (VECTOR_WIDTH)
	) mfu (
		.clk          (clk),
		.resetN       (resetN),
		.fetch        (fetch),
		.valid        (valid),
		.mem_data     (mem_data),
		.ready        (mfu_ready),
		.features_out (mfu_features),
		.updated      (mfu_updated)
	);

	always #2.5 clk = ~clk;

	initial begin
		$dumpfile("pipeline_manager_tb.vcd");
		$dumpvars(0, pipeline_manager_tb);

		clk      = 1'b0;
		resetN   = 1'b0;
		start    = 1'b0;
		N        = 8'd8; // four pair-steps per epoch
		valid    = 1'b0;
		mem_data = {VECTOR_WIDTH{1'b0}};
		#2;

		check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 7'd0,
			128'h00000000000000000000000000000000,
			128'h00000000000000000000000000000000,
			"reset clears outputs");

		resetN <= 1'b1;
		@(posedge clk);
		#2;
		check_outputs(fetch, 1'b0, 1'b0, 1'b0, 7'd0,
			128'h00000000000000000000000000000000,
			128'h00000000000000000000000000000000,
			"idle before start");

		start <= 1'b1;
		wait (fetch === 1'b1);
		send_vector(128'h11112222333344445555666677778888);
		wait (hidden_layer_enable === 1'b1);
		@(posedge clk);
		#2;
		check_outputs(fetch, 1'b1, 1'b0, 1'b0, counter,
			128'h11112222333344445555666677778888,
			128'h00000000000000000000000000000000,
			"first epoch starts with hidden stage only");

		send_vector(128'h9999AAAABBBBCCCCDDDDEEEEFFFF0000);
		run_to_epoch_start;
		check_outputs(fetch, 1'b1, 1'b1, 1'b0, 7'd0,
			128'h9999AAAABBBBCCCCDDDDEEEEFFFF0000,
			128'h00000000000000000000000000000000,
			"second epoch enables output stage");

		send_vector(128'h0123456789ABCDEFFEDCBA9876543210);
		run_to_epoch_start;
		check_outputs(fetch, 1'b1, 1'b1, 1'b1, 7'd0,
			128'h0123456789ABCDEFFEDCBA9876543210,
			128'h11112222333344445555666677778888,
			"third epoch enables loss stage and aligns validate vector");

		send_vector(128'h13579BDF2468ACE013579BDF2468ACE0);
		run_to_epoch_start;
		check_outputs(fetch, 1'b1, 1'b1, 1'b1, 7'd0,
			128'h13579BDF2468ACE013579BDF2468ACE0,
			128'h9999AAAABBBBCCCCDDDDEEEEFFFF0000,
			"steady-state pipeline keeps all stages enabled");

		start <= 1'b0;
		@(posedge clk);
		#2;
		check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 7'd0,
			128'h00000000000000000000000000000000,
			128'h00000000000000000000000000000000,
			"start low returns module to idle");

		$display("PIPELINE_MANAGER TB PASSED");
		$finish;
	end

	task check_outputs(
		input                      expected_fetch,
		input                      expected_hidden_enable,
		input                      expected_output_enable,
		input                      expected_loss_enable,
		input [COUNTER_WIDTH-1:0]  expected_counter,
		input [VECTOR_WIDTH-1:0]   expected_next_vector,
		input [VECTOR_WIDTH-1:0]   expected_validate_vector,
		input [255:0]              test_name
	);
	begin
		if (fetch !== expected_fetch ||
			hidden_layer_enable !== expected_hidden_enable ||
			output_layer_enable !== expected_output_enable ||
			loss_layer_enable !== expected_loss_enable ||
			counter !== expected_counter ||
			next_vector !== expected_next_vector ||
			validate_vector !== expected_validate_vector) begin
			$error("FAIL: %0s | fetch=%0b expected_fetch=%0b hidden=%0b expected_hidden=%0b output=%0b expected_output=%0b loss=%0b expected_loss=%0b counter=%0d expected_counter=%0d next=%032h expected_next=%032h validate=%032h expected_validate=%032h",
				test_name, fetch, expected_fetch, hidden_layer_enable, expected_hidden_enable,
				output_layer_enable, expected_output_enable, loss_layer_enable, expected_loss_enable,
				counter, expected_counter, next_vector, expected_next_vector,
				validate_vector, expected_validate_vector);
			$finish;
		end
		else begin
			$display("PASS: %0s", test_name);
		end
	end
	endtask

	task send_vector(
		input [VECTOR_WIDTH-1:0] vec
	);
	begin
		wait (mfu_ready === 1'b1);
		mem_data <= vec;
		valid    <= 1'b1;
		@(posedge clk);
		#2;
		valid    <= 1'b0;
		mem_data <= {VECTOR_WIDTH{1'b0}};
	end
	endtask

	task run_to_epoch_start;
	begin
		while (counter !== 7'd0 || hidden_layer_enable !== 1'b1) begin
			@(posedge clk);
			#2;
		end
	end
	endtask

endmodule
