// ANIDS Pipeline Manager
`include "anids_defines.vh"

module pipeline_manager (
		clk,
		resetN,
		start,
		N,
		mfu_features,
		mfu_updated,
		fetch,
		enable,
		output_enable,
		loss_enable,
		next_vector,
		validate_vector,
		counter
	);

	parameter VECTOR_WIDTH   = `PIPELINE_VECTOR_WIDTH;
	parameter COUNTER_WIDTH  = `PIPELINE_COUNTER_WIDTH;
	parameter FIFO_DEPTH     = 4;
	parameter FIFO_COUNT_W   = 3;
	parameter FIFO_PTR_W     = 2;
	parameter EPOCH_WIDTH    = 3;

	// ----------------------------------------------------------------------
	//                  		I/O Ports
	// ----------------------------------------------------------------------
	input  wire                         clk;
	input  wire                         resetN;
	input  wire                         start;
	input  wire [`APB_DATA_WIDTH-1:0]   N;
	input  wire [VECTOR_WIDTH-1:0]      mfu_features;
	input  wire                         mfu_updated;
	output reg                          fetch;
	output wire                         enable;
	output wire                         output_enable;
	output wire                         loss_enable;
	output wire [VECTOR_WIDTH-1:0]      next_vector;
	output wire [VECTOR_WIDTH-1:0]      validate_vector;
	output reg  [COUNTER_WIDTH-1:0]     counter;

	// ----------------------------------------------------------------------
	//                  		Vector Stage Registers
	// ----------------------------------------------------------------------
	reg [VECTOR_WIDTH-1:0] stage0_vector;
	reg [VECTOR_WIDTH-1:0] stage1_vector;
	reg [VECTOR_WIDTH-1:0] stage2_vector;
	reg                    stage0_valid;
	reg                    stage1_valid;
	reg                    stage2_valid;
	reg [EPOCH_WIDTH-1:0]  epoch_count;

	assign next_vector     = stage0_vector;
	assign validate_vector = stage2_vector;
	assign enable          = stage0_valid;
	assign output_enable   = stage1_valid;
	assign loss_enable     = stage2_valid;

	// ----------------------------------------------------------------------
	//                  		Streaming FIFO
	// ----------------------------------------------------------------------
	reg [VECTOR_WIDTH-1:0] fifo_mem [0:FIFO_DEPTH-1];
	reg [FIFO_PTR_W-1:0]   fifo_wr_ptr;
	reg [FIFO_PTR_W-1:0]   fifo_rd_ptr;
	reg [FIFO_COUNT_W-1:0] fifo_count;
	reg                    fetch_inflight;

	wire stage_active      = stage0_valid || stage1_valid || stage2_valid;
	wire [COUNTER_WIDTH-1:0] last_pair_index = ((N >> 1) - 1'b1);
	wire start_epoch       = !stage_active && (fifo_count != 0);
	wire boundary_shift    = stage_active && (counter == last_pair_index);
	wire inject_next_stage = (fifo_count != 0);
	wire pop_fifo          = start_epoch || (boundary_shift && inject_next_stage);

	// ----------------------------------------------------------------------
	//                  		Manager Logic
	// ----------------------------------------------------------------------
	always @(posedge clk or negedge resetN) begin
		if (!resetN) begin
			fetch          <= #1 1'b0;
			counter        <= #1 {COUNTER_WIDTH{1'b0}};
			stage0_vector  <= #1 {VECTOR_WIDTH{1'b0}};
			stage1_vector  <= #1 {VECTOR_WIDTH{1'b0}};
			stage2_vector  <= #1 {VECTOR_WIDTH{1'b0}};
			stage0_valid   <= #1 1'b0;
			stage1_valid   <= #1 1'b0;
			stage2_valid   <= #1 1'b0;
			epoch_count    <= #1 {EPOCH_WIDTH{1'b0}};
			fifo_wr_ptr    <= #1 {FIFO_PTR_W{1'b0}};
			fifo_rd_ptr    <= #1 {FIFO_PTR_W{1'b0}};
			fifo_count     <= #1 {FIFO_COUNT_W{1'b0}};
			fetch_inflight <= #1 1'b0;
		end
		else if (!start) begin
			fetch          <= #1 1'b0;
			counter        <= #1 {COUNTER_WIDTH{1'b0}};
			stage0_vector  <= #1 {VECTOR_WIDTH{1'b0}};
			stage1_vector  <= #1 {VECTOR_WIDTH{1'b0}};
			stage2_vector  <= #1 {VECTOR_WIDTH{1'b0}};
			stage0_valid   <= #1 1'b0;
			stage1_valid   <= #1 1'b0;
			stage2_valid   <= #1 1'b0;
			epoch_count    <= #1 {EPOCH_WIDTH{1'b0}};
			fifo_wr_ptr    <= #1 {FIFO_PTR_W{1'b0}};
			fifo_rd_ptr    <= #1 {FIFO_PTR_W{1'b0}};
			fifo_count     <= #1 {FIFO_COUNT_W{1'b0}};
			fetch_inflight <= #1 1'b0;
		end
		else begin
			fetch <= #1 1'b0;

			if (mfu_updated) begin
				fifo_mem[fifo_wr_ptr] <= #1 mfu_features;
				fifo_wr_ptr           <= #1 fifo_wr_ptr + 1'b1;
				fetch_inflight        <= #1 1'b0;
			end

			if (start_epoch) begin
				stage0_vector <= #1 fifo_mem[fifo_rd_ptr];
				stage1_vector <= #1 {VECTOR_WIDTH{1'b0}};
				stage2_vector <= #1 {VECTOR_WIDTH{1'b0}};
				stage0_valid  <= #1 1'b1;
				stage1_valid  <= #1 1'b0;
				stage2_valid  <= #1 1'b0;
				counter       <= #1 {COUNTER_WIDTH{1'b0}};
				epoch_count   <= #1 {{(EPOCH_WIDTH-1){1'b0}}, 1'b1};
			end
			else if (boundary_shift) begin
				stage2_vector <= #1 stage1_vector;
				stage1_vector <= #1 stage0_vector;
				stage0_vector <= #1 (inject_next_stage ? fifo_mem[fifo_rd_ptr] : {VECTOR_WIDTH{1'b0}});
				stage2_valid  <= #1 ((epoch_count >= 2) ? stage1_valid : 1'b0);
				stage1_valid  <= #1 ((epoch_count >= 1) ? stage0_valid : 1'b0);
				stage0_valid  <= #1 inject_next_stage;
				counter       <= #1 {COUNTER_WIDTH{1'b0}};
				if (epoch_count < ((1 << EPOCH_WIDTH) - 1))
					epoch_count <= #1 epoch_count + 1'b1;
			end
			else if (stage_active) begin
				counter <= #1 counter + 1'b1;
			end
			else begin
				counter <= #1 {COUNTER_WIDTH{1'b0}};
			end

			if (pop_fifo && mfu_updated) begin
				fifo_rd_ptr <= #1 fifo_rd_ptr + 1'b1;
				fifo_count  <= #1 fifo_count;
			end
			else if (pop_fifo) begin
				fifo_rd_ptr <= #1 fifo_rd_ptr + 1'b1;
				fifo_count  <= #1 fifo_count - 1'b1;
			end
			else if (mfu_updated) begin
				fifo_count <= #1 fifo_count + 1'b1;
			end

			if (!fetch_inflight && (fifo_count < FIFO_DEPTH)) begin
				fetch          <= #1 1'b1;
				fetch_inflight <= #1 1'b1;
			end
		end
	end

endmodule
