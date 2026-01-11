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
	done
	// DMA Interface
	dma_valid,
	dma_ack,
	dma_data
);


// mark inputs outputs ***
	// System signals
	input  wire                  		sys_clk;
	input  wire                  		sys_reset_n;

	// APB Interface
	input  wire                   		pclk;
	input  wire                   		presetN;
	input  wire [`APB_ADDR_WIDTH-1:0]	paddr;
	input  wire [`APB_DATA_WIDTH-1:0] 	pwdata;
	output wire [`APB_DATA_WIDTH-1:0]	prdata;
	input  wire                   		psel;
	input  wire                   		penable;
	input  wire                   		pwrite;
	output wire                   		pready;
	// done interrupt
	output wire                  		done;

	// DMA Interface
	input  wire                    		dma_valid;
	output wire                   		dma_ack;
	output wire [`DMA_DATA_WIDTH-1:0]	dma_data;


// instansiate regfile
anids_regfile regfile (
	// APB Interface
	.PCLK      	(pclk),
	.PRESETn   	(presetN),
	.PSEL      	(psel),
	.PENABLE   	(penable),
	.PWRITE    	(pwrite),
	.PADDR     	(paddr),
	.PWDATA    	(pwdata),
	.PRDATA    	(prdata),
	.PREADY    	(pready),
);

// instansiate regfile
anids_core core (
	// System signals
	.sys_clk    	(sys_clk),
	.sys_reset_n 	(sys_reset_n),

	// Control registers from regfile
	// ...

	// DMA Interface
	.dma_valid (dma_valid),
	.dma_ack   (dma_ack),
	.dma_data  (dma_data)
);


