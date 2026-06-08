// Purpose: verifies steady-state result-to-result timing by streaming two vectors through ANIDS.
// ANIDS - Two-Vector End-to-End Timing Testbench
`timescale 1ns/100ps
`include "anids_defines.vh"

module two_vector_test_tb;

	localparam [7:0] STATUS_NOT_ANOMALY = 8'd0;
	localparam [7:0] STATUS_ANOMALY     = 8'd1;
	localparam [7:0] STATUS_WAITING     = 8'd2;
	localparam [7:0] STATUS_IDLE        = 8'd3;
	localparam [`LUT_ADDR_WIDTH-1:0] ZERO_LUT_ADDR = (1 << (`LUT_ADDR_WIDTH - 1));
	localparam integer VECTOR_COUNT = 2;

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
	integer                       start_cycle;
	integer                       done_count;
	integer                       result_count;
	integer                       first_done_cycle;
	integer                       second_done_cycle;
	integer                       first_result_cycle;
	integer                       second_result_cycle;

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
			cycle_count <= 0;
		end
		else begin
			cycle_count <= cycle_count + 1;
		end
	end

	always @(posedge dut.core_inst.start_core) begin
		if (start_cycle < 0)
			start_cycle = cycle_count;
	end

	always @(posedge done) begin
		if (done_count == 0)
			first_done_cycle = cycle_count;
		else if (done_count == 1)
			second_done_cycle = cycle_count;
		done_count = done_count + 1;
	end

	always @(dut.regfile_inst.regfile[`RESULT_REG]) begin
		if (start_cycle >= 0 &&
		    (dut.regfile_inst.regfile[`RESULT_REG] == STATUS_NOT_ANOMALY ||
		     dut.regfile_inst.regfile[`RESULT_REG] == STATUS_ANOMALY)) begin
			if (result_count == 0)
				first_result_cycle = cycle_count;
			else if (result_count == 1)
				second_result_cycle = cycle_count;
			result_count = result_count + 1;
		end
	end

	initial begin
		$dumpfile("two_vector_test_tb.vcd");
		$dumpvars(0, two_vector_test_tb);

		init_signals;
		apply_reset;
		program_zero_order_model(8'd1, 8'h00);

		fork
			begin
				cpu_write_APB(`START_REG, 8'd1);
			end
			begin
				dma_send_vector_file_repeat("ANIDS/tb/data/zero_order/dma_all_zeros.data", VECTOR_COUNT);
			end
		join

		wait (result_count >= VECTOR_COUNT);
		repeat (2) @(posedge sys_clk);

		$display("TIMING2: start_core           @ cycle %0d", start_cycle);
		$display("TIMING2: first core_done      @ cycle %0d", first_done_cycle);
		$display("TIMING2: second core_done     @ cycle %0d", second_done_cycle);
		$display("TIMING2: first RESULT_REG     @ cycle %0d", first_result_cycle);
		$display("TIMING2: second RESULT_REG    @ cycle %0d", second_result_cycle);
		$display("TIMING2: start -> first done  = %0d cycles", first_done_cycle - start_cycle);
		$display("TIMING2: done gap             = %0d cycles", second_done_cycle - first_done_cycle);
		$display("TIMING2: start -> first result= %0d cycles", first_result_cycle - start_cycle);
		$display("TIMING2: result gap           = %0d cycles", second_result_cycle - first_result_cycle);

		cpu_write_APB(`START_REG, 8'd0);
		check_status_reg(STATUS_IDLE, "two-vector test returns to idle");

		$display("TWO_VECTOR_TEST TB PASSED");
		$finish;
	end

	task init_signals;
	begin
		sys_clk           = 1'b0;
		sys_reset_n       = 1'b0;
		paddr             = '0;
		pwdata            = '0;
		psel              = 1'b0;
		penable           = 1'b0;
		pwrite            = 1'b0;
		dma_valid         = 1'b0;
		dma_data          = '0;
		cycle_count       = 0;
		start_cycle       = -1;
		done_count        = 0;
		result_count      = 0;
		first_done_cycle  = -1;
		second_done_cycle = -1;
		first_result_cycle = -1;
		second_result_cycle = -1;
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

	task program_zero_order_model(
		input [`APB_DATA_WIDTH-1:0] threshold_value,
		input [`LUT_DATA_WIDTH-1:0] lut_zero_value
	);
	begin
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

	task dma_send_vector_file_repeat(
		input string fname,
		input integer repeat_count
	);
		integer fd;
		integer idx;
		reg [`DMA_DATA_WIDTH-1:0] vec;
	begin
		fd = $fopen(fname, "r");
		if (fd == 0)
			$fatal(1, "Cannot open DMA vector file: %0s", fname);

		if ($fscanf(fd, "%h\n", vec) != 1)
			$fatal(1, "Bad DMA vector format in %0s", fname);
		$fclose(fd);

		for (idx = 0; idx < repeat_count; idx = idx + 1)
			dma_send_vector(vec);
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
