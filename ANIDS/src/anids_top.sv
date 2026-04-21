// ANIDS Top Level Module
`include "anids_defines.vh"

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
	output wire [`APB_DATA_WIDTH-1:0]	prdata;
	input  wire                   		psel;
	input  wire                   		penable;
	input  wire                   		pwrite;
	output wire                   		pready;


	// DMA Interface
	input  wire                    		dma_valid;
	output wire                   		dma_ack;
	input  wire [`DMA_DATA_WIDTH-1:0]	dma_data;


	// ----------------------------------------------------------------------
	//                  		APB Register File
	// ----------------------------------------------------------------------
	wire [`APB_DATA_WIDTH-1:0]              regfile_prdata;
	wire                                    regfile_pready;
	wire signed [`APB_DATA_WIDTH-1:0]       regfile_bus [0:`REG_COUNT-1];
	wire                                    regfile_hw_wr_en;
	wire [`APB_ADDR_WIDTH-1:0]              regfile_hw_wr_addr;
	wire [`APB_DATA_WIDTH-1:0]              regfile_hw_wr_data;

	regfile regfile_inst (
		// APB Interface
		.pclk       (pclk),
		.presetN    (presetN),
		.paddr      (paddr),
		.pwdata     (pwdata),
		.prdata     (regfile_prdata),
		.psel       (psel),
		.penable    (penable),
		.pwrite     (pwrite),
		.pready     (regfile_pready),
		.hw_wr_en   (regfile_hw_wr_en),
		.hw_wr_addr (regfile_hw_wr_addr),
		.hw_wr_data (regfile_hw_wr_data),
		.regfile    (regfile_bus)
	);
	assign prdata = regfile_prdata;
	assign pready = regfile_pready;


	// ----------------------------------------------------------------------
	//                  		Memory Fetch Unit
	// ----------------------------------------------------------------------
	wire                         core_fetch;
	wire                         mfu_ready;
	wire [`DMA_DATA_WIDTH-1:0]   mfu_features;
	wire                         mfu_updated;

	mem_fetch_unit mfu_inst (
		.clk          (sys_clk),
		.resetN       (sys_reset_n),
		.fetch        (core_fetch),
		.valid        (dma_valid),
		.mem_data     (dma_data),
		.ready        (mfu_ready),
		.features_out (mfu_features),
		.updated      (mfu_updated)
	);

	assign dma_ack = mfu_ready;


	// ----------------------------------------------------------------------
	//                  		Core
	// ----------------------------------------------------------------------
	wire                                core_done;
	wire                                core_outlier_pulse;
	wire signed [`LF_OUT_WIDTH-1:0]     core_loss_result;
	wire                                status_wr_en;
	wire [`APB_DATA_WIDTH-1:0]          status_wr_data;

	anids_core core_inst (
		.clk               (sys_clk),
		.resetN            (sys_reset_n),
		.regfile           (regfile_bus),
		.mfu_features      (mfu_features),
		.mfu_updated       (mfu_updated),
		.fetch_next_vector (core_fetch),
		.done              (core_done),
		.outlier_pulse     (core_outlier_pulse),
		.loss_result       (core_loss_result)
	);

	result_status_encoder result_status_encoder_inst (
		.clk            (sys_clk),
		.resetN         (sys_reset_n),
		.start          (regfile_bus[`START_REG][0]),
		.done           (core_done),
		.outlier_pulse  (core_outlier_pulse),
		.result_wr_en   (status_wr_en),
		.result_wr_data (status_wr_data)
	);

	assign regfile_hw_wr_en   = status_wr_en;
	assign regfile_hw_wr_addr = `RESULT_REG;
	assign regfile_hw_wr_data = status_wr_data;

	assign done = core_done;
endmodule
