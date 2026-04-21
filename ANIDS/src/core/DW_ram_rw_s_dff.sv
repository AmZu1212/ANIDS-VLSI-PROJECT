module DW_ram_rw_s_dff #(
	parameter integer data_width = 8,
	parameter integer depth      = 8,
	parameter integer rst_mode   = 0
) (
	clk,	// CE
	rst_n,	// ????
	cs_n,	// CSB
	wr_n,	// WEB
	rw_addr,// A
	data_in,// I
	data_out// O
);

	localparam integer ADDR_WIDTH = (depth <= 2) ? 1 : $clog2(depth);

	input  wire                       clk;
	input  wire                       rst_n;
	input  wire                       cs_n;
	input  wire                       wr_n;
	input  wire [ADDR_WIDTH-1:0]      rw_addr;
	input  wire [data_width-1:0]      data_in;
	output reg  [data_width-1:0]      data_out;

	reg [data_width-1:0] mem [0:depth-1];
	integer i;

	task reset_storage;
	begin
		for (i = 0; i < depth; i = i + 1)
			mem[i] <= {data_width{1'b0}};
		data_out <= {data_width{1'b0}};
	end
	endtask

	generate
		if (rst_mode == 0) begin : gen_async_reset
			always @(posedge clk or negedge rst_n) begin
				if (!rst_n) begin
					reset_storage;
				end
				else if (!cs_n) begin
					if (!wr_n) begin
						if (rw_addr < depth)
							mem[rw_addr] <= data_in;
					end
					else begin
						if (rw_addr < depth)
							data_out <= mem[rw_addr];
						else
							data_out <= {data_width{1'b0}};
					end
				end
			end
		end
		else begin : gen_sync_reset
			always @(posedge clk) begin
				if (!rst_n) begin
					reset_storage;
				end
				else if (!cs_n) begin
					if (!wr_n) begin
						if (rw_addr < depth)
							mem[rw_addr] <= data_in;
					end
					else begin
						if (rw_addr < depth)
							data_out <= mem[rw_addr];
						else
							data_out <= {data_width{1'b0}};
					end
				end
			end
		end
	endgenerate

endmodule
