// ANIDS LUT Module
module lut_mem (
	clk,
	resetN,
	rd_addr,
	wr_addr,
	wr_en,
	wr_data,
	rd_data
);

parameter DATA_WIDTH = `LUT_DATA_WIDTH;
parameter ADDR_WIDTH = `LUT_ADDR_WIDTH;
parameter RAM_DEPTH  = 1 << ADDR_WIDTH;

//--------------Input Ports-----------------------
input                  		clk;
input				   		resetN;
input 	[ADDR_WIDTH-1:0] 	rd_addr;
input 	[ADDR_WIDTH-1:0] 	wr_addr;
input                  		wr_en;
input 	[DATA_WIDTH-1:0] 	wr_data;

//--------------Output Ports-----------------------
output reg 	[DATA_WIDTH-1:0] 	rd_data;

//--------------Internal Memory----------------
reg [DATA_WIDTH-1:0] mem [0:RAM_DEPTH-1];
integer i;


// wrtie/read logic here:

endmodule
