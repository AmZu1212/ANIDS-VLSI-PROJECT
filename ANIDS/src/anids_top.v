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
output reg [`APB_DATA_WIDTH-1:0]	prdata;
input  wire                   		psel;
input  wire                   		penable;
input  wire                   		pwrite;
output reg                   		pready;


// DMA Interface
input  wire                    		dma_valid;
output wire                   		dma_ack;
input wire [`DMA_DATA_WIDTH-1:0]	dma_data;


// ----------------------------------------------------------------------
//                  		APB Register File
// ----------------------------------------------------------------------

// APB Modes
wire apb_w = psel && penable && pwrite;
wire apb_r = psel && penable && !pwrite;
wire [`APB_ADDR_WIDTH-1:0] target = paddr;


// Regfile
reg [`APB_DATA_WIDTH-1:0] regfile [0: `REG_COUNT-1];


// Regfile read/write logic
genvar i;
generate
	for (i = 0; i < `REG_COUNT; i++) begin
		always @(posedge pclk or negedge presetN) begin
			if (!presetN) begin
				regfile[i] <= {`APB_DATA_WIDTH{1'b0}};
				// pready <= 1'b0;
			end
			else if (apb_w && target == i) begin
				regfile[i] <= pwdata;
				// pready <= 1'b1;
			end
			else if(apb_r && target == i) begin
				prdata <= regfile[i];
				// pready <= 1'b1;
			end
			// else begin
			// 	pready <= 1'b0;
			// end
		end
	end
endgenerate


always @(posedge pclk or negedge presetN) begin
  if (!presetN) begin
    pready <= 1'b0;
    prdata <= '0;
  end else begin
    pready <= apb_w || apb_r;   // zero-wait slave
    if (apb_r)
      prdata <= regfile[target];
  end
end






// combinational read path
//assign prdata = (apb_r) ? regfile[target] : {`APB_DATA_WIDTH{1'b0}};



// ----------------------------------------------------------------------
//                  		Memory Fetch Unit
// ----------------------------------------------------------------------

// 	TBD:	memory fetch unit is responsible for push data to core + dma ack.


// ----------------------------------------------------------------------
//                  		Core
// ----------------------------------------------------------------------

// 	TBD:	core is responsible for math & result write + done.






endmodule