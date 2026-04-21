// ANIDS Outlier Detector
`include "anids_defines.vh"

module outlier_detector (
		clk,
		resetN,
		ready,
		data_in,
		threshold,
		outlier_pulse,
		output_ready
	);

	parameter DATA_WIDTH 	= `LF_OUT_WIDTH;
	parameter THRESH_WIDTH	= `APB_DATA_WIDTH;

	// ----------------------------------------------------------------------
	//                  		I/O Ports
	// ----------------------------------------------------------------------
	input  wire                    clk;
	input  wire                    resetN;
	input  wire                    ready;
	input  wire signed [DATA_WIDTH-1:0]   data_in;
	input  wire signed [THRESH_WIDTH-1:0] threshold;
	output reg                     outlier_pulse;
	output reg                     output_ready;


	// ----------------------------------------------------------------------
	//                  		Outlier Detection
	// ----------------------------------------------------------------------
	always @(posedge clk or negedge resetN) begin
		if (!resetN) begin
			outlier_pulse <= #1 1'b0;
			output_ready  <= #1 1'b0;
		end
		else if (ready) begin
			outlier_pulse <= #1 (data_in > threshold);
			output_ready  <= #1 1'b1;
		end
		else begin
			outlier_pulse <= #1 1'b0;
			output_ready  <= #1 1'b0;
		end
	end

endmodule
