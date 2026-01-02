// ANIDS - Test Bench
`define CPU_BUS_DATA		"model.apb"
`define DMA_DATA			"dma.data"
`define NUM_RESULTS			1
`timescale 1ns/100ps 		// period of 5ns (200MHz)


module anids_tb;
// -----------------------------------------------------------
//                  Registers & Wires
// -----------------------------------------------------------

// System clock & reset
reg sys_clk;
reg sys_reset;

// APB Interface
reg        					PCLK;
reg        					PRESETn;
reg  [`APB_DATA_WIDTH-1:0] 	PADDR;
reg  [`APB_DATA_WIDTH-1:0] 	PWDATA;
wire [`APB_DATA_WIDTH-1:0] 	PRDATA;
reg        					PSEL;
reg        					PENABLE;
reg        					PWRITE;
wire       					PREADY;
wire       					PSLVERR;
reg  [3:0]  				PSTRB;
reg  [2:0]  				PPROT;

// DMA Interface
reg 						dma_valid;
wire 						dma_ack;
reg [`DMA_DATA_WIDTH-1:0]	dma_data;

// Clocks
always #(`CLK_PERIOD/2) 	sys_clk = ~sys_clk;
always #(`CLK_PERIOD/2) 	PCLK    = ~PCLK;


// ----------------------------------------------------------------------
//                   Instantiations
// ----------------------------------------------------------------------
anids dut (
    // System signals
    .sys_clk   (sys_clk),
    .sys_reset (sys_reset),

    // APB Interface
    .pclk      (PCLK),
    .presetN   (PRESETn),
    .paddr     (PADDR),
    .pwdata    (PWDATA),
    .prdata    (PRDATA),
    .psel      (PSEL),
    .penable   (PENABLE),
    .pwrite    (PWRITE),
    .pready    (PREADY),
    .pslverr   (PSLVERR),
    .pstrb     (PSTRB),
    .pprot     (PPROT),

    // DMA Interface
    .dma_valid (dma_valid),
    .dma_ack   (dma_ack),
    .dma_data  (dma_data)
);


// ----------------------------------------------------------------------
//                   Test Pattern
// ----------------------------------------------------------------------
byte result;
reg [`APB_DATA_WIDTH-1:0] rdata;

initial begin
	// Initiates all input signals
	initiate_all;
	#10*`CLK_PERIOD;

	// Load the model to ANIDS
	load_model(`CPU_BUS_DATA);
	//#`CLK_PERIOD * apb write delay * number of writes (not sure if needed...)


	/// TODO: check with shahar that this is correct behaviour
	// Start DMA data stream from file (async)
	fork
		dma_stream_from_file("dma.data");
	join_none
	#4*`CLK_PERIOD;


	// Start ANIDS processing by writing to START_REG
	cpu_write_APB(`START_REG, `APB_DATA_WIDTH'h1);
	$display("ANIDS processing started.");

	// first read is always slowest due to pipeline fill
	#`FILL_CYCLES * `CLK_PERIOD;

	/// TODO: verify syntax & logic for this loop
	// Poll RESULT_REG until done
	integer k;
	for (k = 0; k < `NUM_RESULTS; k++)
	begin
		cpu_read_APB(`RESULT_REG, rdata);
		result = rdata[`APB_DATA_WIDTH-1:0];
		$display("Result[%0d] = 0x%02h at t=%0t", k, result, $time);

		// spacing between results (adjust accordingly)
		#(`LATENCY_IN_CYCLES * `CLK_PERIOD);
	end

	// Stop ANIDS & end TB
	cpu_write_APB(`START_REG, `APB_DATA_WIDTH'h0);
	$display("ANIDS processing stopped.");
	$display("Test Bench completed.");
	$finish; // also kills the forked process
end

// TASKS
/*
 * 	APB RULE OF THUMB:
 *	| WRITE: CPU configures, loads or starts the DUT.
 *	|  READ:  CPU checks status or reads results.
 */


/// TODO: maybe add streaming
// currently doesnt support (strb? i.e data stream)
task cpu_write_APB(
	input [`APB_DATA_WIDTH-1:0] addr,
	input [`APB_DATA_WIDTH-1:0] data
	);
	begin
		// SETUP phase
		@(posedge PCLK);
		PSEL   <= 1'b1;
		PENABLE<= 1'b0;
		PWRITE <= 1'b1;
		PADDR  <= addr;
		PWDATA <= data;

		// ACCESS phase
		@(posedge PCLK);
		PENABLE <= 1'b1;

		// Wait for slave ready
		while (!PREADY)
			@(posedge PCLK);

		// End transfer
		@(posedge PCLK);
		PSEL    <= 1'b0;
		PENABLE <= 1'b0;
		PWRITE  <= 1'b0;
	end
endtask

task cpu_read_APB(
	input  [`APB_DATA_WIDTH-1:0] addr,
	output [`APB_DATA_WIDTH-1:0] data
	);
	begin
		// SETUP phase
		@(posedge PCLK);
		PSEL    <= 1'b1;
		PENABLE <= 1'b0;
		PWRITE  <= 1'b0;
		PADDR   <= addr;

		// ACCESS phase
		@(posedge PCLK);
		PENABLE <= 1'b1;

		// Wait for slave ready
		while (!PREADY)
			@(posedge PCLK);

		// Capture read data
		data = PRDATA;

		// End transfer
		@(posedge PCLK);
		PSEL    <= 1'b0;
		PENABLE <= 1'b0;
	end
endtask

/// TODO: verify this is the actual values that are supposed to be here
task initiate_all;
	begin
		// Initialize all input signals
		sys_clk    = 1'b0;
		sys_reset  = 1'b1;

		PCLK       = 1'b0;
		PRESETn    = 1'b0;
		PADDR      = `APB_DATA_WIDTH'b0;
		PWDATA     = `APB_DATA_WIDTH'b0;
		PSEL       = 1'b0;
		PENABLE    = 1'b0;
		PWRITE     = 1'b0;
		PSTRB      = 4'b1111; // all byte lanes active
		PPROT      = 3'b000;  // data access, privileged, secure

		dma_valid  = 1'b0;
		dma_data   = `DMA_DATA_WIDTH'b0;

		// Release reset after some time
		#20;
		sys_reset  = 1'b0;
		PRESETn    = 1'b1;
	end
endtask

// task for loading the model values from a file
task automatic load_model(input string fname);
	integer fd;
	string line;
	int unsigned addr;
	int unsigned val;

	fd = $fopen(fname, "r");
	if (fd == 0) $fatal(1, "Cannot open %s", fname);

	while (!$feof(fd)) begin
		line = "";
		void'($fgets(line, fd));

		// skip comment/blank
		if (line.len() == 0) continue;
		if (line.len() >= 2 && line.substr(0,1) == "//") continue;

		// strip inline comment
		int cpos = line.find("//");
		if (cpos != -1) line = line.substr(0, cpos - 1);

		// parse: 0xADDR 0xVAL
		if ($sscanf(line, "0x%x 0x%x", addr, val) == 2) begin
		cpu_write_APB(addr, val[`APB_DATA_WIDTH-1:0]);
		end
	end

	$fclose(fd);
endtask

/// Async DMA loading task
task automatic dma_stream_from_file(input string fname);
	integer fd;
	reg [`DMA_DATA_WIDTH-1:0] vec;

	// idle defaults
	dma_valid <= 1'b0;
	dma_data  <= {`DMA_DATA_WIDTH{1'b0}};

	fd = $fopen(fname, "r");
	if (fd == 0)
	$fatal(1, "Cannot open DMA file: %s", fname);

	// wait until out of reset
	wait (PRESETn == 1'b1);
	wait (sys_reset == 1'b0);

	forever
		begin
			// if EOF, rewind and continue
			if ($feof(fd)) begin
				$rewind(fd);
			end

			// read one vector
			if ($fscanf(fd, "%h\n", vec) != 1)
				$fatal(1, "Bad DMA data format");

			// present data
			@(posedge sys_clk);
			dma_data  <= vec;
			dma_valid <= 1'b1;

			// wait for ack
			while (dma_ack != 1'b1)
				@(posedge sys_clk);

			// drop valid after ack
			@(posedge sys_clk);
			dma_valid <= 1'b0;
		end
	end
endtask
endmodule   // anids_tb

