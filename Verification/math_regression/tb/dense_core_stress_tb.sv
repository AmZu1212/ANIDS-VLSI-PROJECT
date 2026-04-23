`timescale 1ns/100ps
`include "anids_defines.vh"

module dense_core_stress_tb;
	localparam string PROG_FILE = "verification/math_regression/generated/dense_core/dense_core_full.prog";
	localparam string VECTOR_FILE = "verification/math_regression/generated/dense_core/dense_core_full.vector";

	reg                        sys_clk;
	reg                        sys_reset_n;
	reg  [`APB_ADDR_WIDTH-1:0] paddr;
	reg  [`APB_DATA_WIDTH-1:0] pwdata;
	wire [`APB_DATA_WIDTH-1:0] prdata;
	reg                        psel;
	reg                        penable;
	reg                        pwrite;
	wire                       pready;
	wire                       done;
	reg                        dma_valid;
	wire                       dma_ack;
	reg  [`DMA_DATA_WIDTH-1:0] dma_data;
	integer                    cycle_count;

	always @(posedge sys_clk or negedge sys_reset_n) begin
		if (!sys_reset_n)
			cycle_count <= 0;
		else
			cycle_count <= cycle_count + 1;
	end

	always @(posedge sys_clk) begin
		if (cycle_count > 120000) begin
			$error("Dense core stress timed out waiting for completion at cycle %0d", cycle_count);
			$finish;
		end
	end

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
		apply_reset;
		run_program_file(PROG_FILE);
		fork
			dma_send_vector_file(VECTOR_FILE);
			begin
				cpu_write_APB(`START_REG, 8'd1);
				@(posedge dut.core_done);
				#2;
				$display(
					"RTL_DENSE_CORE loss=%0d outlier=%0b",
					dut.core_loss_result,
					dut.core_outlier_pulse
				);
			end
		join
		cpu_write_APB(`START_REG, 8'd0);
		$finish;
	end

	task init_signals;
	begin
		sys_clk = 1'b0;
		sys_reset_n = 1'b0;
		paddr = '0;
		pwdata = '0;
		psel = 1'b0;
		penable = 1'b0;
		pwrite = 1'b0;
		dma_valid = 1'b0;
		dma_data = '0;
		cycle_count = 0;
	end
	endtask

	task apply_reset;
	begin
		sys_reset_n = 1'b0;
		psel = 1'b0;
		penable = 1'b0;
		pwrite = 1'b0;
		dma_valid = 1'b0;
		dma_data = '0;
		repeat (4) @(posedge sys_clk);
		sys_reset_n = 1'b1;
		repeat (4) @(posedge sys_clk);
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
			$fatal(1, "Cannot open dense core program file: %0s", fname);
		while (!$feof(fd)) begin
			rc = $fscanf(fd, "%h %h\n", addr, data);
			if (rc == 2)
				cpu_write_APB(addr, data);
		end
		$fclose(fd);
	end
	endtask

	task cpu_write_APB(input [`APB_ADDR_WIDTH-1:0] addr, input [`APB_DATA_WIDTH-1:0] data);
	begin
		@(posedge sys_clk);
		paddr   <= #1 addr;
		pwdata  <= #1 data;
		psel    <= #1 1'b1;
		penable <= #1 1'b0;
		pwrite  <= #1 1'b1;
		@(posedge sys_clk);
		penable <= #1 1'b1;
		while (!pready) @(posedge sys_clk);
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
			$fatal(1, "Cannot open dense core vector file: %0s", fname);
		if ($fscanf(fd, "%h\n", vec) != 1)
			$fatal(1, "Bad dense core vector format: %0s", fname);
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
