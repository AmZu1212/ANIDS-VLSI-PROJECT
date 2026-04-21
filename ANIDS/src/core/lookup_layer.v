// ANIDS Lookup Layer
`include "anids_defines.vh"

module lookup_layer (
		clk,
		resetN,
		lookup_enable,
		loss_enable,
		N,
		counter,
		lut_wr_addr,
		lut_wr_data,
		lut_wr_en,
		result_0,
		result_1,
		function_0,
		function_1,
		lookup_ready
	);

	parameter RESULT_IN_WIDTH  = `LF_RESULT_IN_WIDTH;
	parameter RESULT_OUT_WIDTH = `LUT_DATA_WIDTH;
	parameter LUT_ADDR_WIDTH   = `LUT_ADDR_WIDTH;
	parameter COUNTER_WIDTH    = `PIPELINE_COUNTER_WIDTH;
	parameter PAIR_COUNT       = (1 << (`PIPELINE_STAGE_COUNT_W));
	parameter RAM_DEPTH        = (1 << LUT_ADDR_WIDTH);

	input  wire                              clk;
	input  wire                              resetN;
	input  wire                              lookup_enable;
	input  wire                              loss_enable;
	input  wire [`APB_DATA_WIDTH-1:0]        N;
	input  wire [COUNTER_WIDTH-1:0]          counter;
	input  wire [LUT_ADDR_WIDTH-1:0]         lut_wr_addr;
	input  wire [RESULT_OUT_WIDTH-1:0]       lut_wr_data;
	input  wire                              lut_wr_en;
	input  wire signed [RESULT_IN_WIDTH-1:0] result_0;
	input  wire signed [RESULT_IN_WIDTH-1:0] result_1;
	output reg  signed [RESULT_OUT_WIDTH-1:0] function_0;
	output reg  signed [RESULT_OUT_WIDTH-1:0] function_1;
	output reg                               lookup_ready;

	reg  [RESULT_OUT_WIDTH*2-1:0] pair_bank_0 [0:PAIR_COUNT-1];
	reg  [RESULT_OUT_WIDTH*2-1:0] pair_bank_1 [0:PAIR_COUNT-1];
	reg                           write_bank_sel;
	reg                           read_bank_sel;
	reg                           read_bank_valid;
	reg                           pending_lookup_valid;
	reg                           pending_last_pair;
	reg  [COUNTER_WIDTH-1:0]      pending_pair_index;
	integer                       i;

	wire [LUT_ADDR_WIDTH-1:0] mapped_addr_0;
	wire [LUT_ADDR_WIDTH-1:0] mapped_addr_1;
	wire [LUT_ADDR_WIDTH-1:0] ram_addr_0 = lut_wr_en ? lut_wr_addr : mapped_addr_0;
	wire [LUT_ADDR_WIDTH-1:0] ram_addr_1 = lut_wr_en ? lut_wr_addr : mapped_addr_1;
	wire [RESULT_OUT_WIDTH-1:0] lut_data_0;
	wire [RESULT_OUT_WIDTH-1:0] lut_data_1;
	wire [COUNTER_WIDTH-1:0] last_pair_index = ((N >> 1) - 1'b1);
	wire                        read_data_valid = read_bank_valid || (pending_lookup_valid && pending_last_pair);
	wire                        active_read_bank_sel = (pending_lookup_valid && pending_last_pair) ? write_bank_sel : read_bank_sel;

	memory_mapper mapper_0 (
		.in_value (result_0),
		.lut_addr (mapped_addr_0)
	);

	memory_mapper mapper_1 (
		.in_value (result_1),
		.lut_addr (mapped_addr_1)
	);

	DW_ram_rw_s_dff #(
		.data_width (RESULT_OUT_WIDTH),
		.depth      (RAM_DEPTH),
		.rst_mode   (0)
	) function_lut_0 (
		.clk      (clk),
		.rst_n    (resetN),
		.cs_n     (~(lookup_enable || lut_wr_en)),
		.wr_n     (~lut_wr_en),
		.rw_addr  (ram_addr_0),
		.data_in  (lut_wr_data),
		.data_out (lut_data_0)
	);

	DW_ram_rw_s_dff #(
		.data_width (RESULT_OUT_WIDTH),
		.depth      (RAM_DEPTH),
		.rst_mode   (0)
	) function_lut_1 (
		.clk      (clk),
		.rst_n    (resetN),
		.cs_n     (~(lookup_enable || lut_wr_en)),
		.wr_n     (~lut_wr_en),
		.rw_addr  (ram_addr_1),
		.data_in  (lut_wr_data),
		.data_out (lut_data_1)
	);

	always @(*) begin
		if (loss_enable && read_data_valid) begin
			if (!active_read_bank_sel) begin
				function_0 = pair_bank_0[counter][RESULT_OUT_WIDTH-1:0];
				function_1 = pair_bank_0[counter][(2*RESULT_OUT_WIDTH)-1:RESULT_OUT_WIDTH];
			end
			else begin
				function_0 = pair_bank_1[counter][RESULT_OUT_WIDTH-1:0];
				function_1 = pair_bank_1[counter][(2*RESULT_OUT_WIDTH)-1:RESULT_OUT_WIDTH];
			end
		end
		else begin
			function_0 = {RESULT_OUT_WIDTH{1'b0}};
			function_1 = {RESULT_OUT_WIDTH{1'b0}};
		end
	end

	always @(posedge clk or negedge resetN) begin
		if (!resetN) begin
			write_bank_sel      <= #1 1'b0;
			read_bank_sel       <= #1 1'b0;
			read_bank_valid     <= #1 1'b0;
			pending_lookup_valid <= #1 1'b0;
			pending_last_pair   <= #1 1'b0;
			pending_pair_index  <= #1 {COUNTER_WIDTH{1'b0}};
			lookup_ready        <= #1 1'b0;
			/// *** check later if this is synthesizeable!
			for (i = 0; i < PAIR_COUNT; i = i + 1) begin
				pair_bank_0[i] <= #1 {(2*RESULT_OUT_WIDTH){1'b0}};
				pair_bank_1[i] <= #1 {(2*RESULT_OUT_WIDTH){1'b0}};
			end
		end
		else begin
			lookup_ready <= #1 1'b0;

			// Capture the pair returned by the synchronous LUTs for the address
			// issued on the previous cycle.
			if (pending_lookup_valid) begin
				if (!write_bank_sel)
					pair_bank_0[pending_pair_index] <= #1 {lut_data_1, lut_data_0};
				else
					pair_bank_1[pending_pair_index] <= #1 {lut_data_1, lut_data_0};

				if (pending_last_pair) begin
					read_bank_sel   <= #1 write_bank_sel;
					read_bank_valid <= #1 1'b1;
					write_bank_sel  <= #1 ~write_bank_sel;
					lookup_ready    <= #1 1'b1;
				end
			end

			// Issue the next pair lookup. The returned values will be captured
			// on the next clock edge into the current write bank.
			if (lookup_enable) begin
				pending_lookup_valid <= #1 1'b1;
				pending_last_pair    <= #1 (counter == last_pair_index);
				pending_pair_index   <= #1 counter;
			end
			else begin
				pending_lookup_valid <= #1 1'b0;
				pending_last_pair    <= #1 1'b0;
			end
		end
	end

endmodule
