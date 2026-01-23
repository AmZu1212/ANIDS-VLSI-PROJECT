// ANIDS Top Level Module
module anids_top(
		// System signals
		sys_clk,
		sys_reset_n,

		// APB Interface
		pclk,
		presetN,
		paddr,
		pwdata,
		prdata,
		psel,
		penable,
		pwrite,
		pready,
		done,

		// DMA Interface
		dma_valid,
		dma_ack,
		dma_data
	);


	// ----------------------------------------------------------------------
	//                  		I/O Ports
	// ----------------------------------------------------------------------

	// System signals
	input  wire                  		sys_clk;
	input  wire                  		sys_reset_n;


	// done interrupt
	output wire                  		done;


	// APB Interface
	input  wire                   		pclk;
	input  wire                   		presetN;
	input  wire [`APB_ADDR_WIDTH-1:0]	paddr;
	input  wire [`APB_DATA_WIDTH-1:0] 	pwdata;
	output reg 	[`APB_DATA_WIDTH-1:0]	prdata;
	input  wire                   		psel;
	input  wire                   		penable;
	input  wire                   		pwrite;
	output reg                   		pready;


	// DMA Interface
	input  wire                    		dma_valid;
	output wire                   		dma_ack;
	input  wire [`DMA_DATA_WIDTH-1:0]	dma_data;


	// ----------------------------------------------------------------------
	//                  		APB Register File
	// ----------------------------------------------------------------------

	regfile regfile_inst (
		// APB Interface
		.pclk       (pclk),
		.presetN    (presetN),
		.paddr      (paddr),
		.pwdata     (pwdata),
		.prdata     (prdata),
		.psel       (psel),
		.penable    (penable),
		.pwrite     (pwrite),
		.pready     (pready)
	);



	// ----------------------------------------------------------------------
	//                  		Memory Fetch Unit
	// ----------------------------------------------------------------------

	// 	TBD:	memory fetch unit is responsible for push data to core + dma ack.


	// ----------------------------------------------------------------------
	//                  		Core
	// ----------------------------------------------------------------------

	// 	TBD:	core is responsible for math & result write + done.
endmodule