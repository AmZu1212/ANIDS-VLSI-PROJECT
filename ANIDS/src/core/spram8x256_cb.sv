module spram8x256_cb (
	CE,		// clk signal. (CE is rising edge = start.)
	CSB,	// chip select (i.e always 0)
	WEB,	// Write enable (0 = write, 1 = read)
	A,		// address
	I, 		// write input
	O 		// read output
);

	localparam integer DATA_WIDTH = 8;
	localparam integer DEPTH      = 256;
	localparam integer ADDR_WIDTH = 8;

	input  wire                  CE;
	input  wire                  CSB;
	input  wire                  WEB;
	input  wire [ADDR_WIDTH-1:0] A;
	input  wire [DATA_WIDTH-1:0] I;
	output reg  [DATA_WIDTH-1:0] O;

	reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
	integer i;

	initial begin
		O = {DATA_WIDTH{1'b0}};
		for (i = 0; i < DEPTH; i = i + 1)
			mem[i] = {DATA_WIDTH{1'b0}};
	end

	always @(posedge CE) begin
		if (!CSB) begin
			if (!WEB) begin
				mem[A] <= I;
			end
			else begin
				O <= mem[A];
			end
		end
	end

endmodule
