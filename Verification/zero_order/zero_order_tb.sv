// ANIDS - Zero Order End-to-End System Testbench
`timescale 1ns/100ps
`include "anids_defines.vh"

module zero_order_tb;

	localparam [7:0] STATUS_NOT_ANOMALY = 8'd0;
	localparam [7:0] STATUS_ANOMALY     = 8'd1;
	localparam [7:0] STATUS_WAITING     = 8'd2;
	localparam [7:0] STATUS_IDLE        = 8'd3;
	localparam [`LUT_ADDR_WIDTH-1:0] ZERO_LUT_ADDR = (1 << (`LUT_ADDR_WIDTH - 1));
	localparam integer VECTOR_REPEATS   = 1;
	localparam integer POLL_TIMEOUT     = 768;
	localparam integer RESULT_EVENT_COUNT = 2;

	// ----------------------------------------------------------------------
	//                  		DUT Signals
	// ----------------------------------------------------------------------
	reg                           sys_clk;
	reg                           sys_reset_n;
	reg  [`APB_ADDR_WIDTH-1:0]    paddr;
	reg  [`APB_DATA_WIDTH-1:0]    pwdata;
	wire [`APB_DATA_WIDTH-1:0]    prdata;
	reg                           psel;
	reg                           penable;
	reg                           pwrite;
	wire                          pready;
	wire                          done;
	reg                           dma_valid;
	wire                          dma_ack;
	reg  [`DMA_DATA_WIDTH-1:0]    dma_data;
	integer                       cycle_count;
	integer                       last_start_cycle;
	reg                           prev_start_core;

	anids_top dut (
		.sys_clk     (sys_clk),
		.sys_reset_n (sys_reset_n),
		.pclk        (sys_clk),
		.presetN     (sys_reset_n),
		.paddr       (paddr),
		.pwdata      (pwdata),
		.prdata      (prdata),
		.psel        (psel),
		.penable     (penable),
		.pwrite      (pwrite),
		.pready      (pready),
		.done        (done),
		.dma_valid   (dma_valid),
		.dma_ack     (dma_ack),
		.dma_data    (dma_data)
	);

	always #(`CLK_PERIOD/2) sys_clk = ~sys_clk;

	always @(posedge sys_clk or negedge sys_reset_n) begin
		if (!sys_reset_n) begin
			cycle_count      <= 0;
			last_start_cycle <= 0;
			prev_start_core  <= 1'b0;
		end
		else begin
			cycle_count <= cycle_count + 1;
			if (!prev_start_core && dut.core_inst.start_core)
				last_start_cycle <= cycle_count + 1;
			prev_start_core <= dut.core_inst.start_core;
		end
	end

	initial begin
		$dumpfile("zero_order_tb.vcd");
		$dumpvars(0, zero_order_tb);

		init_signals;

		run_zero_order_case(
			"verification/zero_order/data/dma_all_zeros.data",
			8'd1,
			8'h00,
			1'b0,
			"all-zero vectors stay non-anomalous"
		);

		run_zero_order_case(
			"verification/zero_order/data/dma_all_ones.data",
			8'd0,
			8'hFF,
			1'b1,
			"configured anomaly case reaches anomalous status"
		);

		run_first_result_timing_analysis(
			"verification/zero_order/data/dma_all_zeros.data",
			8'd1,
			8'h00,
			"first-result timing analysis"
		);

		run_steady_state_gap_case(
			"verification/zero_order/data/dma_all_zeros.data",
			8'd1,
			8'h00,
			"steady-state result spacing"
		);

		$display("ZERO_ORDER SYSTEM TB PASSED");
		$finish;
	end

	task init_signals;
	begin
		sys_clk     = 1'b0;
		sys_reset_n = 1'b0;
		paddr       = '0;
		pwdata      = '0;
		psel        = 1'b0;
		penable     = 1'b0;
		pwrite      = 1'b0;
		dma_valid   = 1'b0;
		dma_data    = '0;
		cycle_count = 0;
		last_start_cycle = 0;
		prev_start_core = 1'b0;
	end
	endtask

	task run_first_result_timing_analysis(
		input string vector_file,
		input [`APB_DATA_WIDTH-1:0] threshold_value,
		input [`LUT_DATA_WIDTH-1:0] lut_zero_value,
		input [255:0] test_name
	);
		integer start_cycle;
		integer fetch_cycle;
		integer mfu_cycle;
		integer hidden_cycle;
		integer output_cycle;
		integer lookup_cycle;
		integer loss_cycle;
		integer loss_ready_cycle;
		integer done_cycle;
	begin
		$display("SECTION: %0s", test_name);
		apply_reset;
		program_zero_order_model(threshold_value, lut_zero_value);

		start_cycle      = -1;
		fetch_cycle      = -1;
		mfu_cycle        = -1;
		hidden_cycle     = -1;
		output_cycle     = -1;
		lookup_cycle     = -1;
		loss_cycle       = -1;
		loss_ready_cycle = -1;
		done_cycle       = -1;

		fork
			begin
				@(posedge dut.core_inst.start_core);
				start_cycle = cycle_count;
			end
			begin
				@(posedge dut.core_inst.fetch_next_vector);
				fetch_cycle = cycle_count;
			end
			begin
				@(posedge dut.mfu_updated);
				mfu_cycle = cycle_count;
			end
			begin
				@(posedge dut.core_inst.hidden_layer_enable);
				hidden_cycle = cycle_count;
			end
			begin
				@(posedge dut.core_inst.output_layer_enable);
				output_cycle = cycle_count;
			end
			begin
				@(posedge dut.core_inst.lookup_layer_enable);
				lookup_cycle = cycle_count;
			end
			begin
				@(posedge dut.core_inst.loss_layer_enable);
				loss_cycle = cycle_count;
			end
			begin
				@(posedge dut.core_inst.loss_ready);
				loss_ready_cycle = cycle_count;
			end
			begin
				@(posedge dut.core_done);
				done_cycle = cycle_count;
			end
			begin
				cpu_write_APB(`START_REG, 8'd1);
				dma_send_vector_file_repeat(vector_file, 1);
			end
		join

		$display("INFO: %0s | start_core      @ cycle %0d", test_name, start_cycle);
		$display("INFO: %0s | fetch pulse      @ cycle %0d", test_name, fetch_cycle);
		$display("INFO: %0s | first mfu_updated@ cycle %0d", test_name, mfu_cycle);
		$display("INFO: %0s | hidden_enable    @ cycle %0d", test_name, hidden_cycle);
		$display("INFO: %0s | output_layer_enable @ cycle %0d", test_name, output_cycle);
		$display("INFO: %0s | lookup_layer_enable @ cycle %0d", test_name, lookup_cycle);
		$display("INFO: %0s | loss_layer_enable   @ cycle %0d", test_name, loss_cycle);
		$display("INFO: %0s | loss_ready       @ cycle %0d", test_name, loss_ready_cycle);
		$display("INFO: %0s | core_done        @ cycle %0d", test_name, done_cycle);
		$display("INFO: %0s | start -> fetch        = %0d cycles", test_name, fetch_cycle - start_cycle);
		$display("INFO: %0s | fetch -> mfu_updated  = %0d cycles", test_name, mfu_cycle - fetch_cycle);
		$display("INFO: %0s | mfu_updated -> hidden = %0d cycles", test_name, hidden_cycle - mfu_cycle);
		$display("INFO: %0s | hidden -> output      = %0d cycles", test_name, output_cycle - hidden_cycle);
		$display("INFO: %0s | output -> lookup      = %0d cycles", test_name, lookup_cycle - output_cycle);
		$display("INFO: %0s | lookup -> loss        = %0d cycles", test_name, loss_cycle - lookup_cycle);
		$display("INFO: %0s | loss -> loss_ready    = %0d cycles", test_name, loss_ready_cycle - loss_cycle);
		$display("INFO: %0s | loss_ready -> done    = %0d cycles", test_name, done_cycle - loss_ready_cycle);
		$display("INFO: %0s | start -> done         = %0d cycles", test_name, done_cycle - start_cycle);

		cpu_write_APB(`START_REG, 8'd0);
		check_status_reg(STATUS_IDLE, "timing analysis returns to idle");
	end
	endtask

	task run_steady_state_gap_case(
		input string vector_file,
		input [`APB_DATA_WIDTH-1:0] threshold_value,
		input [`LUT_DATA_WIDTH-1:0] lut_zero_value,
		input [255:0] test_name
	);
	begin
		$display("SECTION: %0s", test_name);
		apply_reset;
		program_zero_order_model(threshold_value, lut_zero_value);

		fork
			dma_send_vector_file_repeat(vector_file, RESULT_EVENT_COUNT + 3);
			begin
				cpu_write_APB(`START_REG, 8'd1);
				wait_for_status_reg(STATUS_WAITING, "steady-state setup enters waiting");
				poll_for_multiple_terminals(STATUS_NOT_ANOMALY, RESULT_EVENT_COUNT, test_name);
			end
			poll_for_done_events(RESULT_EVENT_COUNT, test_name);
		join

		cpu_write_APB(`START_REG, 8'd0);
		check_status_reg(STATUS_IDLE, "steady-state setup returns to idle");
	end
	endtask

	task poll_for_done_events(
		input integer expected_count,
		input [255:0] test_name
	);
		integer hit_count;
		integer first_done_cycle;
		integer prev_done_cycle;
	begin
		hit_count        = 0;
		first_done_cycle = -1;
		prev_done_cycle  = -1;

		while (hit_count < expected_count) begin
			@(posedge done);
			hit_count = hit_count + 1;

			if (first_done_cycle < 0) begin
				first_done_cycle = cycle_count;
				prev_done_cycle  = cycle_count;
			end
			else begin
				$display(
					"INFO: %0s | core_done gap = %0d cycles",
					test_name,
					cycle_count - prev_done_cycle
				);
				prev_done_cycle = cycle_count;
			end
		end

		$display(
			"INFO: %0s | first core_done after %0d cycles from start_core",
			test_name,
			first_done_cycle - last_start_cycle
		);
	end
	endtask

	task apply_reset;
	begin
		sys_reset_n = 1'b0;
		psel        = 1'b0;
		penable     = 1'b0;
		pwrite      = 1'b0;
		dma_valid   = 1'b0;
		dma_data    = '0;
		repeat (4) @(posedge sys_clk);
		sys_reset_n = 1'b1;
		repeat (4) @(posedge sys_clk);
	end
	endtask

	task poll_for_multiple_terminals(
		input [`APB_DATA_WIDTH-1:0] expected_final,
		input integer                expected_count,
		input [255:0]                test_name
	);
		integer poll_count;
		integer hit_count;
		integer first_hit_cycle;
		integer prev_hit_cycle;
		reg [`APB_DATA_WIDTH-1:0] status_value;
	begin
		poll_count      = 0;
		hit_count       = 0;
		first_hit_cycle = -1;
		prev_hit_cycle  = -1;

		while (poll_count < POLL_TIMEOUT && hit_count < expected_count) begin
			cpu_read_APB(`RESULT_REG, status_value);
			poll_count = poll_count + 1;

			if (status_value == expected_final) begin
				hit_count = hit_count + 1;
				if (first_hit_cycle < 0) begin
					first_hit_cycle = cycle_count;
					prev_hit_cycle  = cycle_count;
				end
				else begin
					$display(
						"INFO: %0s | result %0d arrived %0d cycles after previous result",
						test_name,
						hit_count,
						cycle_count - prev_hit_cycle
					);
					prev_hit_cycle = cycle_count;
				end

				while (status_value == expected_final && poll_count < POLL_TIMEOUT) begin
					cpu_read_APB(`RESULT_REG, status_value);
					poll_count = poll_count + 1;
				end
			end
		end

		if (hit_count != expected_count) begin
			$error("FAIL: %0s | saw %0d terminal results, expected %0d", test_name, hit_count, expected_count);
			$finish;
		end
		else begin
			$display(
				"INFO: %0s | first result after %0d cycles from start_core",
				test_name,
				first_hit_cycle - last_start_cycle
			);
			$display("PASS: %0s", test_name);
		end
	end
	endtask

	task run_zero_order_case(
		input string vector_file,
		input [`APB_DATA_WIDTH-1:0] threshold_value,
		input [`LUT_DATA_WIDTH-1:0] lut_zero_value,
		input        expect_anomaly,
		input [255:0] test_name
	);
	begin
		$display("SECTION: %0s", test_name);
		apply_reset;
		check_status_reg(STATUS_IDLE, "status is idle after reset");

		program_zero_order_model(threshold_value, lut_zero_value);
		check_status_reg(STATUS_IDLE, "status stays idle before start");

		fork
			dma_send_vector_file_repeat(vector_file, VECTOR_REPEATS);
			begin
				cpu_write_APB(`START_REG, 8'd1);
				wait_for_status_reg(STATUS_WAITING, "start drives RESULT_REG to waiting");
				poll_for_expected_terminal(expect_anomaly, test_name);
			end
		join

		cpu_write_APB(`START_REG, 8'd0);
		check_status_reg(STATUS_IDLE, "stopping core returns RESULT_REG to idle");
	end
	endtask

	task program_zero_order_model(
		input [`APB_DATA_WIDTH-1:0] threshold_value,
		input [`LUT_DATA_WIDTH-1:0] lut_zero_value
	);
	begin
		// Zero-order model relies on reset defaults: all hidden/output weights and
		// biases remain zero in the regfile. Because all layer outputs stay at
		// zero, the function LUT is only read at the mapped zero-input address.
		cpu_write_APB(`START_REG, 8'd0);
		cpu_write_APB(`N_REG, 8'd128);
		cpu_write_APB(`THRESHOLD_REG, threshold_value);
		write_function_lut_entry(ZERO_LUT_ADDR, lut_zero_value);
	end
	endtask

	task write_function_lut_entry(
		input [`LUT_ADDR_WIDTH-1:0] lut_addr,
		input [`LUT_DATA_WIDTH-1:0] lut_data
	);
	begin
		cpu_write_APB(`LUT_ADDR, lut_addr);
		cpu_write_APB(`LUT_DATA, lut_data);
		cpu_write_APB(`LUT_CTRL, 8'd1);
		cpu_write_APB(`LUT_CTRL, 8'd0);
	end
	endtask

	task cpu_write_APB(
		input [`APB_ADDR_WIDTH-1:0] addr,
		input [`APB_DATA_WIDTH-1:0] data
	);
	begin
		@(posedge sys_clk);
		paddr   <= #1 addr;
		pwdata  <= #1 data;
		psel    <= #1 1'b1;
		penable <= #1 1'b0;
		pwrite  <= #1 1'b1;

		@(posedge sys_clk);
		penable <= #1 1'b1;

		while (!pready)
			@(posedge sys_clk);

		@(posedge sys_clk);
		psel    <= #1 1'b0;
		penable <= #1 1'b0;
		pwrite  <= #1 1'b0;
	end
	endtask

	task cpu_read_APB(
		input  [`APB_ADDR_WIDTH-1:0] addr,
		output [`APB_DATA_WIDTH-1:0] data
	);
	begin
		@(posedge sys_clk);
		paddr   <= #1 addr;
		psel    <= #1 1'b1;
		penable <= #1 1'b0;
		pwrite  <= #1 1'b0;

		@(posedge sys_clk);
		penable <= #1 1'b1;

		while (!pready)
			@(posedge sys_clk);

		data = prdata;

		@(posedge sys_clk);
		psel    <= #1 1'b0;
		penable <= #1 1'b0;
	end
	endtask

task check_status_reg(
		input [`APB_DATA_WIDTH-1:0] expected_status,
		input [255:0]               test_name
	);
		reg [`APB_DATA_WIDTH-1:0] status_value;
	begin
		cpu_read_APB(`RESULT_REG, status_value);
		if (status_value !== expected_status) begin
			$error("FAIL: %0s | status=%0d expected_status=%0d", test_name, status_value, expected_status);
			$finish;
		end
		else begin
			$display("PASS: %0s", test_name);
		end
	end
	endtask

	task wait_for_status_reg(
		input [`APB_DATA_WIDTH-1:0] expected_status,
		input [255:0]               test_name
	);
		integer poll_count;
		reg [`APB_DATA_WIDTH-1:0] status_value;
	begin
		poll_count = 0;
		while (poll_count < POLL_TIMEOUT) begin
			cpu_read_APB(`RESULT_REG, status_value);
			if (status_value === expected_status) begin
				$display("PASS: %0s", test_name);
				disable wait_for_status_reg;
			end
			poll_count = poll_count + 1;
		end

		$error("FAIL: %0s | timed out waiting for status=%0d", test_name, expected_status);
		$finish;
	end
	endtask

	task poll_for_expected_terminal(
		input        expect_anomaly,
		input [255:0] test_name
	);
		integer poll_count;
		reg [`APB_DATA_WIDTH-1:0] status_value;
		reg [`APB_DATA_WIDTH-1:0] expected_final;
	begin
		expected_final = expect_anomaly ? STATUS_ANOMALY : STATUS_NOT_ANOMALY;
		poll_count     = 0;

		while (poll_count < POLL_TIMEOUT) begin
			cpu_read_APB(`RESULT_REG, status_value);
			poll_count = poll_count + 1;

			if (status_value == expected_final) begin
				$display("INFO: %0s | terminal status after %0d cycles from start_core", test_name, cycle_count - last_start_cycle);
				$display("PASS: %0s", test_name);
				disable poll_for_expected_terminal;
			end
		end

		if (poll_count >= POLL_TIMEOUT) begin
			$error("FAIL: %0s | timed out waiting for terminal status %0d", test_name, expected_final);
			$finish;
		end
	end
	endtask

	task dma_send_vector_file_repeat(
		input string fname,
		input integer repeat_count
	);
		integer fd;
		integer idx;
		reg [`DMA_DATA_WIDTH-1:0] vec;
	begin
		fd = $fopen(fname, "r");
		if (fd == 0) begin
			$fatal(1, "Cannot open DMA vector file: %0s", fname);
		end

		if ($fscanf(fd, "%h\n", vec) != 1) begin
			$fatal(1, "Bad DMA vector format in %0s", fname);
		end
		$fclose(fd);

		for (idx = 0; idx < repeat_count; idx = idx + 1) begin
			dma_send_vector(vec);
		end
	end
	endtask

	task dma_send_vector(
		input [`DMA_DATA_WIDTH-1:0] vec
	);
	begin
		wait (dma_ack === 1'b1);
		@(negedge sys_clk);
		dma_data  <= #1 vec;
		dma_valid <= #1 1'b1;

		@(posedge sys_clk);
		@(negedge sys_clk);
		dma_valid <= #1 1'b0;
		dma_data  <= #1 {`DMA_DATA_WIDTH{1'b0}};

		wait (dma_ack === 1'b0);
	end
	endtask

endmodule
