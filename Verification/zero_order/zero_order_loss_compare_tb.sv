`timescale 1ns/100ps
`include "anids_defines.vh"

module zero_order_loss_compare_tb;

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

	initial begin
		init_signals;

		run_case(
			"zero_case",
			"verification/zero_order/data/dma_all_zeros.data",
			8'd1,
			8'h00
		);

		run_case(
			"ones_case",
			"verification/zero_order/data/dma_all_ones.data",
			8'd0,
			8'hFF
		);

		$display("RTL_LOSS_COMPARE_DONE");
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

	task run_case(
		input [127:0] case_name,
		input string vector_file,
		input [`APB_DATA_WIDTH-1:0] threshold_value,
		input [`LUT_DATA_WIDTH-1:0] lut_zero_value
	);
	begin
		apply_reset;
		program_zero_order_model(threshold_value, lut_zero_value);

		fork
			dma_send_vector_file_repeat(vector_file, 1);
			begin
				cpu_write_APB(`START_REG, 8'd1);
				@(posedge dut.core_done);
				#2;
				$display(
					"RTL_COMPARE case=%0s loss=%0d outlier=%0b status=%0d",
					case_name,
					dut.core_loss_result,
					dut.core_outlier_pulse,
					dut.regfile_bus[`RESULT_REG]
				);
			end
		join

		cpu_write_APB(`START_REG, 8'd0);
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
