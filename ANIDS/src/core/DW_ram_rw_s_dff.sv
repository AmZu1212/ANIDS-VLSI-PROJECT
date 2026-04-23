module DW_ram_rw_s_dff #(
	parameter integer data_width = 8,
	parameter integer depth      = 8,
	parameter integer rst_mode   = 0
) (
	CE,		// clk signal. (CE is rising edge = start.)
	resetN,	// reset - active low (will be removed)
	CSB,	// chip select (i.e always 0)
	WEB,	// Write enable (0 = write, 1 = read)
	A,		// address
	I, 		// write input
	O 		// read output
);

	localparam integer ADDR_WIDTH = (depth <= 2) ? 1 : $clog2(depth);

	input  wire                       CE;
	input  wire                       resetN;
	input  wire                       CSB;
	input  wire                       WEB;
	input  wire [ADDR_WIDTH-1:0]      A;
	input  wire [data_width-1:0]      I;
	output reg  [data_width-1:0]      O;

	reg [data_width-1:0] mem [0:depth-1];
	integer i;

	task reset_storage;
	begin
		for (i = 0; i < depth; i = i + 1)
			mem[i] <= {data_width{1'b0}};
		O <= {data_width{1'b0}};
	end
	endtask

	generate
		if (rst_mode == 0) begin : gen_async_reset
			always @(posedge CE or negedge resetN) begin
				if (!resetN) begin
					reset_storage;
				end
				else if (!CSB) begin
					if (!WEB) begin
						if (A < depth)
							mem[A] <= I;
					end
					else begin
						if (A < depth)
							O <= mem[A];
						else
							O <= {data_width{1'b0}};
					end
				end
			end
		end
		else begin : gen_sync_reset
			always @(posedge CE) begin
				if (!resetN) begin
					reset_storage;
				end
				else if (!CSB) begin
					if (!WEB) begin
						if (A < depth)
							mem[A] <= I;
					end
					else begin
						if (A < depth)
							O <= mem[A];
						else
							O <= {data_width{1'b0}};
					end
				end
			end
		end
	endgenerate

endmodule
