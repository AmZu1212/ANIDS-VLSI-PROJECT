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

	//			=== Parameters ===
	parameter DATA_WIDTH = `LUT_DATA_WIDTH;
	parameter ADDR_WIDTH = `LUT_ADDR_WIDTH;
	parameter RAM_DEPTH  = 1 << ADDR_WIDTH;


	//			=== System Signals ===
	input                  			clk;
	input				   			resetN;


	//			=== Read Signals ===
	input 		[ADDR_WIDTH-1:0] 	rd_addr;
	output reg 	[DATA_WIDTH-1:0] 	rd_data;


	//			=== Write Signals ===
	input 		[ADDR_WIDTH-1:0] 	wr_addr;
	input 		[DATA_WIDTH-1:0] 	wr_data;
	input                  			wr_en;


	//			=== Memory ===
	reg [DATA_WIDTH-1:0] memory [0:RAM_DEPTH-1];


	//			=== Write logic ===
	genvar i;
	generate
		for (i = 0; i < RAM_DEPTH; i++) begin
			always @(posedge clk or negedge resetN) begin
				if (!resetN) begin
					memory[i] <= #1 {DATA_WIDTH{1'b0}};
				end
				else if (wr_en && wr_addr == i) begin
					memory[i] <= #1 wr_data;
				end
			end
		end
	endgenerate


	//			=== Read logic ===
	always @(posedge clk or negedge resetN) begin
		if (!resetN) begin
			rd_data <= #1 {DATA_WIDTH{1'b0}};
		end
		else begin
			rd_data <= #1 memory[rd_addr];
		end
	end

endmodule
