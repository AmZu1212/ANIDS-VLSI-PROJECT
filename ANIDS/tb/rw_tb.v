// ANIDS - Test Bench
`timescale 1ns/100ps
`include "anids_defines.vh"


module rw_tb;

// ----------------------------------------------------------------------
//                  Registers & Wires
// ----------------------------------------------------------------------

// System clk & reset
reg sys_clk;
reg sys_reset_n;

// APB Interface
reg  [`APB_ADDR_WIDTH-1:0] 	PADDR;
reg  [`APB_DATA_WIDTH-1:0] 	PWDATA;
wire [`APB_DATA_WIDTH-1:0] 	PRDATA;
reg							PSEL;
reg							PENABLE;
reg							PWRITE;
wire						PREADY;

// Result Interrupt
wire        				done;

// DMA Interface
reg 						dma_valid;
wire 						dma_ack;
reg [`DMA_DATA_WIDTH-1:0]	dma_data;

// Clocks
always #2.5 	sys_clk = ~sys_clk;


// ----------------------------------------------------------------------
//                   Instantiations
// ----------------------------------------------------------------------
anids_top dut (
    // System signals
    .sys_clk   		(sys_clk),
    .sys_reset_n 	(sys_reset_n),

    // APB Interface
	.pclk	  	(sys_clk),
	.presetN  	(sys_reset_n),
    .paddr     	(PADDR),
    .pwdata    	(PWDATA),
    .prdata    	(PRDATA),
    .psel      	(PSEL),
    .penable   	(PENABLE),
    .pwrite    	(PWRITE),
    .pready    	(PREADY),
	.done 		(done),

    // DMA Interface
    .dma_valid (dma_valid),
    .dma_ack   (dma_ack),
    .dma_data  (dma_data)
	);


integer idx;
integer testRange = `REG_COUNT;
// ----------------------------------------------------------------------
//                   Test Pattern - Simple APB Read/Write
// ----------------------------------------------------------------------
reg [`APB_DATA_WIDTH-1:0] result_data;

initial begin
	$dumpfile("wave.vcd");
  	$dumpvars(0, rw_tb);

	$display("Starting ANIDS APB Read/Write Test Bench...");

	// Init DUT & TB
	initiate_all;


	/// WRITE PHASE
	for (idx = 0; idx < testRange; idx = idx + 1) begin
		cpu_write_APB(idx, idx[`APB_DATA_WIDTH-1:0]);
		$display("Wrote reg[%0d] = %0d", idx, idx);
	end

	$display("Write done. Starting readback and verification...");


	/// READ + CHECK PHASE
	for (idx = 0; idx < testRange; idx = idx + 1) begin
		cpu_read_APB(idx, result_data);

		if (result_data !== idx[`APB_DATA_WIDTH-1:0]) begin
			$error("FAIL: reg[%0d] read %0d, expected %0d", idx, result_data, idx);
			$finish;
		end else begin
			$display("PASS: reg[%0d] = %0d", idx, result_data);
		end
	end

	// TB Done.
	$display("Test Bench completed.");
	$finish;
end


/// initializes all inputs
task initiate_all;
	begin
		// Initialize all input signals
		sys_clk    		<= #1 1'b0;
		sys_reset_n  	<= #1 1'b0;
		result_data 	<= #1 `APB_DATA_WIDTH'b0;

		// APB Interface
		PADDR      <= #1 `APB_DATA_WIDTH'b0;
		PWDATA     <= #1 `APB_DATA_WIDTH'b0;
		PSEL       <= #1 1'b0;
		PENABLE    <= #1 1'b0;
		PWRITE     <= #1 1'b0;

		// DMA Interface
		dma_valid  <= #1 1'b0;
		dma_data   <= #1 `DMA_DATA_WIDTH'b0;


		// finish reset
		#1;
		sys_reset_n  <= #1 1'b1;
	end
endtask


// writes to one APB register (with address 'addr') the data 'data'
task cpu_write_APB(
	input [`APB_ADDR_WIDTH-1:0] addr,
	input [`APB_DATA_WIDTH-1:0] data
	);
	begin
		// SETUP phase
		@(posedge sys_clk);
		PSEL   <= #1 1'b1;
		PENABLE<= #1 1'b0;
		PWRITE <= #1 1'b1;
		PADDR  <= #1 addr;
		PWDATA <= #1 data;

		// ACCESS phase
		@(posedge sys_clk);
		PENABLE <= #1 1'b1;

		// Wait for slave ready
		while (!PREADY)
			@(posedge sys_clk);

		// End transfer
		@(posedge sys_clk);
		PSEL    <= #1 1'b0;
		PENABLE <= #1 1'b0;
		PWRITE  <= #1 1'b0;
	end
endtask


// reads one APB register, with adderss addr, returns data
task cpu_read_APB(
	input  [`APB_ADDR_WIDTH-1:0] addr,
	output [`APB_DATA_WIDTH-1:0] data
	);
	begin
		// SETUP phase
		@(posedge sys_clk);
		PSEL    <= #1 1'b1;
		PENABLE <= #1 1'b0;
		PWRITE  <= #1 1'b0;
		PADDR   <= #1 addr;

		// ACCESS phase
		@(posedge sys_clk);
		PENABLE <= #1 1'b1;

		// Wait for slave ready
		while (!PREADY)
			@(posedge sys_clk);

		// Capture read data
		data <= #1 PRDATA;

		// End transfer
		@(posedge sys_clk);
		PSEL    <= #1 1'b0;
		PENABLE <= #1 1'b0;
	end
endtask
endmodule   // anids_tb
