// ANIDS Memory Fetch Unit
`include "anids_defines.vh"

module mem_fetch_unit (
		clk,
		resetN,
		fetch,
		valid,
		mem_data,
		ready,
		features_out,
		updated
	);

	parameter DATA_WIDTH    = `MFU_DATA_WIDTH;
	parameter FEATURE_WIDTH = `MFU_FEATURE_WIDTH;

	// ----------------------------------------------------------------------
	//                  		I/O Ports
	// ----------------------------------------------------------------------
	input  wire							clk;
	input  wire							resetN;
	input  wire							fetch;
	input  wire							valid;
	input  wire [DATA_WIDTH-1:0] 		mem_data;
	output reg 							ready;
	output reg  [FEATURE_WIDTH-1:0] 	features_out;
	output reg 							updated;

	// ----------------------------------------------------------------------
	//                  		State Machine
	// ----------------------------------------------------------------------
	localparam STATE_IDLE    = 1'b0;
	localparam STATE_PENDING = 1'b1;

	reg state;

	always @(posedge clk or negedge resetN) begin
		if (!resetN) begin
			state        <= #1 STATE_IDLE;
			ready        <= #1 1'b0;
			features_out <= #1 {FEATURE_WIDTH{1'b0}};
			updated      <= #1 1'b0;
		end
		else begin
			case (state)
				STATE_IDLE: begin
					ready   <= #1 1'b0;
					updated <= #1 1'b0;

					if (fetch) begin
						state <= #1 STATE_PENDING;
						ready <= #1 1'b1;
					end
				end

				STATE_PENDING: begin
					ready   <= #1 1'b1;
					updated <= #1 1'b0;

					if (valid) begin
						features_out <= #1 mem_data[FEATURE_WIDTH-1:0];
						state        <= #1 STATE_IDLE;
						ready        <= #1 1'b0;
						updated      <= #1 1'b1;
					end
				end

				// *** remove later? this is redundant for safety
				default: begin
					state   <= #1 STATE_IDLE;
					ready   <= #1 1'b0;
					updated <= #1 1'b0;
				end
			endcase
		end
	end

endmodule
