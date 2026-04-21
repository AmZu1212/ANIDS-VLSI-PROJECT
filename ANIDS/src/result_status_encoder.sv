// ANIDS Result Status Encoder
`include "anids_defines.vh"

module result_status_encoder (
		clk,
		resetN,
		start,
		done,
		outlier_pulse,
		result_wr_en,
		result_wr_data
	);

	parameter STATUS_WIDTH = `APB_DATA_WIDTH;
	parameter RESULT_HOLD_CYCLES = 8;
	parameter HOLD_COUNT_WIDTH   = 4;
	localparam [STATUS_WIDTH-1:0] STATUS_NOT_ANOMALY = 8'd0;
	localparam [STATUS_WIDTH-1:0] STATUS_ANOMALY     = 8'd1;
	localparam [STATUS_WIDTH-1:0] STATUS_WAITING     = 8'd2;
	localparam [STATUS_WIDTH-1:0] STATUS_IDLE        = 8'd3;

	// ----------------------------------------------------------------------
	//                  		I/O Ports
	// ----------------------------------------------------------------------
	input  wire                         clk;
	input  wire                         resetN;
	input  wire                         start;
	input  wire                         done;
	input  wire                         outlier_pulse;
	output reg                          result_wr_en;
	output reg  [STATUS_WIDTH-1:0]      result_wr_data;

	// ----------------------------------------------------------------------
	//                  		Status Encoding
	// ----------------------------------------------------------------------
	reg                                initialized;
	reg [STATUS_WIDTH-1:0]             current_status;
	reg [STATUS_WIDTH-1:0]             next_status;
	reg [HOLD_COUNT_WIDTH-1:0]         hold_count;
	wire                               holding_result = (hold_count != {HOLD_COUNT_WIDTH{1'b0}});

	always @(*) begin
		if (!start) begin
			next_status = STATUS_IDLE;
		end
		else if (holding_result) begin
			next_status = current_status;
		end
		else if (done) begin
			next_status = outlier_pulse ? STATUS_ANOMALY
			                            : STATUS_NOT_ANOMALY;
		end
		else begin
			next_status = STATUS_WAITING;
		end
	end

	always @(posedge clk or negedge resetN) begin
		if (!resetN) begin
			initialized    <= #1 1'b0;
			current_status <= #1 STATUS_IDLE;
			result_wr_en   <= #1 1'b0;
			result_wr_data <= #1 STATUS_IDLE;
			hold_count     <= #1 {HOLD_COUNT_WIDTH{1'b0}};
		end
		else begin
			result_wr_en <= #1 1'b0;

			if (!start) begin
				hold_count <= #1 {HOLD_COUNT_WIDTH{1'b0}};
			end
			else if (holding_result) begin
				hold_count <= #1 hold_count - 1'b1;
			end

			if (!initialized || (next_status != current_status)) begin
				initialized    <= #1 1'b1;
				current_status <= #1 next_status;
				result_wr_en   <= #1 1'b1;
				result_wr_data <= #1 next_status;

				if (done) begin
					hold_count <= #1 RESULT_HOLD_CYCLES - 1'b1;
				end
				else begin
					hold_count <= #1 {HOLD_COUNT_WIDTH{1'b0}};
				end
			end
		end
	end

endmodule
