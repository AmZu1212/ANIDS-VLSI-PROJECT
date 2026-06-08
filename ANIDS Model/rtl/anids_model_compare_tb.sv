`timescale 1ns/100ps
`include "anids_defines.vh"

module anids_model_compare_tb;

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

	string program_file;
	string inputs_file;
	integer input_count;
	reg [`DMA_DATA_WIDTH-1:0] input_vectors [0:1023];

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
		if (!$value$plusargs("PROGRAM=%s", program_file))
			$fatal(1, "Missing +PROGRAM=<program.prog>");
		if (!$value$plusargs("INPUTS=%s", inputs_file))
			$fatal(1, "Missing +INPUTS=<inputs.txt>");

		init_signals;
		apply_reset;
		run_program_file(program_file);
		load_input_vectors(inputs_file);
		run_streaming_vectors;
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

	task run_program_file(input string fname);
		integer fd;
		integer rc;
		reg [`APB_ADDR_WIDTH-1:0] addr;
		reg [`APB_DATA_WIDTH-1:0] data;
		reg [`LUT_ADDR_WIDTH-1:0] lut_addr_shadow;
		reg [`LUT_DATA_WIDTH-1:0] lut_data_shadow;
	begin
		fd = $fopen(fname, "r");
		if (fd == 0)
			$fatal(1, "Cannot open program file: %0s", fname);

		lut_addr_shadow = '0;
		lut_data_shadow = '0;

		while (!$feof(fd)) begin
			rc = $fscanf(fd, "%h %h\n", addr, data);
			if (rc == 2)
				backdoor_program_write(addr, data, lut_addr_shadow, lut_data_shadow);
		end

		$fclose(fd);
		@(posedge sys_clk);
	end
	endtask

	task backdoor_program_write(
		input [`APB_ADDR_WIDTH-1:0] addr,
		input [`APB_DATA_WIDTH-1:0] data,
		inout [`LUT_ADDR_WIDTH-1:0] lut_addr_shadow,
		inout [`LUT_DATA_WIDTH-1:0] lut_data_shadow
	);
	begin
		if (addr < `REG_COUNT)
			dut.regfile_inst.regfile[addr] = data;

		if (addr == `LUT_ADDR) begin
			lut_addr_shadow = data[`LUT_ADDR_WIDTH-1:0];
		end
		else if (addr == `LUT_DATA) begin
			lut_data_shadow = data[`LUT_DATA_WIDTH-1:0];
		end
		else if ((addr == `LUT_CTRL) && data[0]) begin
			dut.core_inst.lookup_layer_inst.function_lut_0.mem[lut_addr_shadow] = lut_data_shadow;
			dut.core_inst.lookup_layer_inst.function_lut_1.mem[lut_addr_shadow] = lut_data_shadow;
		end
	end
	endtask

	task load_input_vectors(input string fname);
		integer fd;
		integer rc;
		reg [`DMA_DATA_WIDTH-1:0] vec;
	begin
		fd = $fopen(fname, "r");
		if (fd == 0)
			$fatal(1, "Cannot open inputs file: %0s", fname);

		input_count = 0;
		while (!$feof(fd)) begin
			rc = $fscanf(fd, "%h\n", vec);
			if (rc == 1) begin
				input_vectors[input_count] = vec;
				input_count = input_count + 1;
			end
		end

		$fclose(fd);
		if (input_count == 0)
			$fatal(1, "No input vectors found in %0s", fname);
	end
	endtask

	task run_streaming_vectors;
	begin
		cpu_write_APB(`START_REG, 8'd1);

		fork
			dma_send_loaded_vectors;
			collect_results(input_count);
		join

		cpu_write_APB(`START_REG, 8'd0);
		repeat (4) @(posedge sys_clk);
	end
	endtask

	task dma_send_loaded_vectors;
		integer idx;
	begin
		for (idx = 0; idx < input_count; idx = idx + 1)
			dma_send_vector(input_vectors[idx]);
	end
	endtask

	task collect_results(input integer expected_count);
		integer idx;
	begin
		for (idx = 0; idx < expected_count; idx = idx + 1) begin
			@(posedge dut.core_done);
			#2;
			$display(
				"RESULT vector=%0d loss=%0d anomaly=%0d",
				idx,
				dut.core_loss_result,
				dut.core_outlier_pulse
			);
		end
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
