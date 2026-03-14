// ANIDS Sigmoid LUT Memory Mapper
`include "anids_defines.vh"

module memory_mapper (
		in_value,
		lut_addr
	);

	parameter IN_WIDTH   = `MMAP_IN_WIDTH;
	parameter ADDR_WIDTH = `MMAP_ADDR_WIDTH;

	// ----------------------------------------------------------------------
	//                  		I/O Ports
	// ----------------------------------------------------------------------
	input  wire signed [IN_WIDTH-1:0]   in_value;
	output reg        [ADDR_WIDTH-1:0]  lut_addr;

	// ----------------------------------------------------------------------
	//                  		Address Mapping
	// ----------------------------------------------------------------------
	// Map signed Q0.7 values into an ascending LUT index:
	// most negative -> 0, zero -> middle, most positive -> last entry.
	// For a 256-entry LUT (8-bit address), this is a one-to-one mapping that
	// only flips the sign bit. For a 128-entry LUT, the LSB is dropped so that
	// adjacent signed codes share one LUT entry.
	always @(*) begin
		if (ADDR_WIDTH == IN_WIDTH) begin
			lut_addr = {~in_value[IN_WIDTH-1], in_value[IN_WIDTH-2:0]};
		end
		else begin
			lut_addr = {~in_value[IN_WIDTH-1], in_value[IN_WIDTH-2:1]};
		end
	end

endmodule
