// ANIDS ReLU Unit
`include "anids_defines.vh"

module relu_unit (
		in_data,
		resetN,
		ready,
		out_data
	);

	parameter DATA_WIDTH = `RELU_WIDTH;

	// ----------------------------------------------------------------------
	//                  		I/O Ports
	// ----------------------------------------------------------------------
	input  wire signed [DATA_WIDTH-1:0] in_data;
	input  wire                         resetN;
	input  wire                         ready;
	output reg        [DATA_WIDTH-1:0]  out_data;


	// ----------------------------------------------------------------------
	//                  		ReLU Logic
	// ----------------------------------------------------------------------
	always @(*) begin
		if (!resetN) begin
			out_data = {DATA_WIDTH{1'b0}};
		end
		else if (!ready) begin
			out_data = {DATA_WIDTH{1'b0}};
		end
		else if (in_data[DATA_WIDTH-1]) begin
			// if the number is negative (i.e sign bit is 1)
			out_data = {DATA_WIDTH{1'b0}};
		end
		else begin
			out_data = in_data;
		end
	end

endmodule
