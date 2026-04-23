`timescale 1ns/100ps
`include "anids_defines.vh"

module weighted_loss_compare_tb;

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
			"dense_weighted_case",
			"Verification/zero_order/generated/dense_weighted_case.prog",
			"Verification/zero_order/generated/dense_weighted_case.data"
		);

		run_case(
			"sparse_weighted_case",
			"Verification/zero_order/generated/sparse_weighted_case.prog",
			"Verification/zero_order/generated/sparse_weighted_case.data"
		);

		$display("RTL_WEIGHTED_COMPARE_DONE");
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
		input [255:0] case_name,
		input string program_file,
		input string vector_file
	);
	begin
		apply_reset;
		run_program_file(program_file);

		fork
			dma_send_vector_file_repeat(vector_file, 1);
			begin
				cpu_write_APB(`START_REG, 8'd1);
				@(posedge dut.core_done);
				#2;
				$display(
					"RTL_WEIGHTED_COMPARE case=%0s loss=%0d outlier=%0b",
					case_name,
					dut.core_loss_result,
					dut.core_outlier_pulse
				);
			end
		join

		cpu_write_APB(`START_REG, 8'd0);
	end
	endtask

	task run_program_file(input string fname);
		integer fd;
		integer rc;
		reg [`APB_ADDR_WIDTH-1:0] addr;
		reg [`APB_DATA_WIDTH-1:0] data;
	begin
		fd = $fopen(fname, "r");
		if (fd == 0) begin
			$fatal(1, "Cannot open program file: %0s", fname);
		end

		while (!$feof(fd)) begin
			rc = $fscanf(fd, "%h %h\n", addr, data);
			if (rc == 2)
				cpu_write_APB(addr, data);
		end

		$fclose(fd);
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
