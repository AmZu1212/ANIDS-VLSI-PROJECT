// ANIDS regfile Module
`include "anids_defines.vh"

module regfile(
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
		hw_wr_en,
		hw_wr_addr,
		hw_wr_data,
		regfile
	);


	// ----------------------------------------------------------------------
	//                  		I/O Ports
	// ----------------------------------------------------------------------

	// APB Interface
	input  wire                   		pclk;
	input  wire                   		presetN;
	input  wire                   		psel;
	input  wire                   		pwrite;
	input  wire                   		penable;
	input  wire [`APB_ADDR_WIDTH-1:0]	paddr;
	input  wire [`APB_DATA_WIDTH-1:0] 	pwdata;
	output reg 	[`APB_DATA_WIDTH-1:0]	prdata;
	output reg                   		pready;
	input  wire                   		hw_wr_en;
	input  wire [`APB_ADDR_WIDTH-1:0]	hw_wr_addr;
	input  wire [`APB_DATA_WIDTH-1:0] 	hw_wr_data;


	// ----------------------------------------------------------------------
	//                  		APB Register File
	// ----------------------------------------------------------------------

	// APB Modes
	wire apb_w = psel && penable && pwrite;
	wire apb_r = psel && penable && !pwrite;
	wire [`APB_ADDR_WIDTH-1:0] target = paddr;


	// Regfile
	output reg [`APB_DATA_WIDTH-1:0] regfile [0: `REG_COUNT-1];


	// Regfile read/write logic
	genvar i;
	generate
		for (i = 0; i < `REG_COUNT; i++) begin
			always @(posedge pclk or negedge presetN) begin
				if (!presetN) begin
					regfile[i] <= #1 {`APB_DATA_WIDTH{1'b0}};
					// pready <= 1'b0;
				end
				else if (hw_wr_en && hw_wr_addr == i) begin
					regfile[i] <= #1 hw_wr_data;
				end
				else if (apb_w && target == i) begin
					regfile[i] <= #1 pwdata;
					// pready <= 1'b1;
				end
				else if(apb_r && target == i) begin
					prdata <= #1 regfile[i];
					// pready <= 1'b1;
				end
			end
		end
	endgenerate

	// pready logic, instant ready.
	always @(posedge pclk or negedge presetN) begin
		if (!presetN) begin
			pready <= #1 1'b0;
			prdata <= #1 '0;
		end else begin
			pready <= #1 apb_w || apb_r;   // zero-wait slave
		end
	end
endmodule
