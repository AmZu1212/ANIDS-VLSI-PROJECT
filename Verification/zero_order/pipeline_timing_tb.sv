// ANIDS - End-to-End Pipeline Timing Probe
`timescale 1ns/100ps
`include "anids_defines.vh"

module pipeline_timing_tb;

	localparam [7:0] STATUS_NOT_ANOMALY = 8'd0;
	localparam [7:0] STATUS_ANOMALY     = 8'd1;
	localparam [7:0] STATUS_WAITING     = 8'd2;
	localparam [7:0] STATUS_IDLE        = 8'd3;
	localparam [`LUT_ADDR_WIDTH-1:0] ZERO_LUT_ADDR = (1 << (`LUT_ADDR_WIDTH - 1));

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
	reg                           timing_armed;

	integer start_cycle;
	integer fetch_cycle;
	integer mfu_cycle;
	integer hidden_cycle;
	integer output_cycle;
	integer lookup_cycle;
	integer loss_cycle;
	integer loss_ready_cycle;
	integer done_cycle;
	integer status_wr_cycle;
	integer result_reg_cycle;

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
			timing_armed <= 1'b0;
		end
		else begin
			cycle_count <= cycle_count + 1;
			if (!timing_armed && dut.core_inst.start_core)
				timing_armed <= 1'b1;
		end
	end

	always @(posedge dut.core_inst.start_core)
		if (start_cycle < 0) start_cycle = cycle_count;

	always @(posedge dut.core_inst.fetch_next_vector)
		if (timing_armed && fetch_cycle < 0) fetch_cycle = cycle_count;

	always @(posedge dut.mfu_updated)
		if (timing_armed && mfu_cycle < 0) mfu_cycle = cycle_count;

	always @(posedge dut.core_inst.hidden_layer_enable)
		if (timing_armed && hidden_cycle < 0) hidden_cycle = cycle_count;

	always @(posedge dut.core_inst.output_layer_enable)
		if (timing_armed && output_cycle < 0) output_cycle = cycle_count;

	always @(posedge dut.core_inst.lookup_layer_enable)
		if (timing_armed && lookup_cycle < 0) lookup_cycle = cycle_count;

	always @(posedge dut.core_inst.loss_layer_enable)
		if (timing_armed && loss_cycle < 0) loss_cycle = cycle_count;

	always @(posedge dut.core_inst.loss_ready)
		if (timing_armed && loss_ready_cycle < 0) loss_ready_cycle = cycle_count;

	always @(posedge dut.core_done)
		if (timing_armed && done_cycle < 0) done_cycle = cycle_count;

	always @(posedge dut.status_wr_en)
		if (timing_armed &&
		    status_wr_cycle < 0 &&
		    (dut.status_wr_data == STATUS_NOT_ANOMALY || dut.status_wr_data == STATUS_ANOMALY))
			status_wr_cycle = cycle_count;

	always @(dut.regfile_inst.regfile[`RESULT_REG]) begin
		if (timing_armed &&
		    (dut.regfile_inst.regfile[`RESULT_REG] == STATUS_NOT_ANOMALY ||
		     dut.regfile_inst.regfile[`RESULT_REG] == STATUS_ANOMALY) &&
		    result_reg_cycle < 0)
			result_reg_cycle = cycle_count;
	end

	initial begin
		$dumpfile("pipeline_timing_tb.vcd");
		$dumpvars(0, pipeline_timing_tb);

		init_signals;
		apply_reset;
		program_zero_order_model(8'd1, 8'h00);

		fork
			begin
				cpu_write_APB(`START_REG, 8'd1);
			end
			begin
				dma_send_vector_file("verification/zero_order/data/dma_all_zeros.data");
			end
		join

		wait (result_reg_cycle >= 0);
		repeat (2) @(posedge sys_clk);

		$display("TIMING: start_core         @ cycle %0d", start_cycle);
		$display("TIMING: fetch_next_vector  @ cycle %0d", fetch_cycle);
		$display("TIMING: mfu_updated        @ cycle %0d", mfu_cycle);
		$display("TIMING: hidden_enable      @ cycle %0d", hidden_cycle);
		$display("TIMING: output_enable      @ cycle %0d", output_cycle);
		$display("TIMING: lookup_enable      @ cycle %0d", lookup_cycle);
		$display("TIMING: loss_enable        @ cycle %0d", loss_cycle);
		$display("TIMING: loss_ready         @ cycle %0d", loss_ready_cycle);
		$display("TIMING: core_done          @ cycle %0d", done_cycle);
		$display("TIMING: status_wr_en       @ cycle %0d", status_wr_cycle);
		$display("TIMING: RESULT_REG update  @ cycle %0d", result_reg_cycle);

		$display("TIMING: start -> fetch       = %0d cycles", fetch_cycle - start_cycle);
		$display("TIMING: fetch -> mfu_updated = %0d cycles", mfu_cycle - fetch_cycle);
		$display("TIMING: mfu -> hidden        = %0d cycles", hidden_cycle - mfu_cycle);
		$display("TIMING: hidden -> output     = %0d cycles", output_cycle - hidden_cycle);
		$display("TIMING: output -> lookup     = %0d cycles", lookup_cycle - output_cycle);
		$display("TIMING: lookup -> loss       = %0d cycles", loss_cycle - lookup_cycle);
		$display("TIMING: loss -> loss_ready   = %0d cycles", loss_ready_cycle - loss_cycle);
		$display("TIMING: loss_ready -> done   = %0d cycles", done_cycle - loss_ready_cycle);
		$display("TIMING: done -> status_wr    = %0d cycles", status_wr_cycle - done_cycle);
		$display("TIMING: status -> RESULT_REG = %0d cycles", result_reg_cycle - status_wr_cycle);
		$display("TIMING: start -> RESULT_REG  = %0d cycles", result_reg_cycle - start_cycle);

		if (dut.regfile_inst.regfile[`RESULT_REG] !== STATUS_NOT_ANOMALY) begin
			$error("FAIL: expected RESULT_REG=%0d got %0d", STATUS_NOT_ANOMALY, dut.regfile_inst.regfile[`RESULT_REG]);
			$finish;
		end

		$display("PIPELINE_TIMING TB PASSED");
		$finish;
	end

	task init_signals;
	begin
		sys_clk         = 1'b0;
		sys_reset_n     = 1'b0;
		paddr           = '0;
		pwdata          = '0;
		psel            = 1'b0;
		penable         = 1'b0;
		pwrite          = 1'b0;
		dma_valid       = 1'b0;
		dma_data        = '0;
		cycle_count     = 0;
		timing_armed    = 1'b0;
		start_cycle     = -1;
		fetch_cycle     = -1;
		mfu_cycle       = -1;
		hidden_cycle    = -1;
		output_cycle    = -1;
		lookup_cycle    = -1;
		loss_cycle      = -1;
		loss_ready_cycle = -1;
		done_cycle      = -1;
		status_wr_cycle = -1;
		result_reg_cycle = -1;
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

	task dma_send_vector_file(input string fname);
		integer fd;
		reg [`DMA_DATA_WIDTH-1:0] vec;
	begin
		fd = $fopen(fname, "r");
		if (fd == 0)
			$fatal(1, "Cannot open DMA vector file: %0s", fname);
		if ($fscanf(fd, "%h\n", vec) != 1)
			$fatal(1, "Bad DMA vector format in %0s", fname);
		$fclose(fd);
		dma_send_vector(vec);
	end
	endtask

	task dma_send_vector(input [`DMA_DATA_WIDTH-1:0] vec);
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
