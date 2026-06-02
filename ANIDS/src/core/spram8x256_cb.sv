
// this is a dummy module so we can actually compile the project.
// the real project uses the lab memory file (which is under NDA).
module spram8x256_cb (
	CEB,	// clock input used by the real macro wrapper
	CSB,	// chip select, active low
	WEB,	// write enable, active low
	OEB,	// output enable, active low
	A,		// address
	I, 		// write input
	O 		// read output
);

	localparam integer DATA_WIDTH = 8;
	localparam integer DEPTH      = 256;
	localparam integer ADDR_WIDTH = 8;

	input  wire                  CEB;
	input  wire                  CSB;
	input  wire                  WEB;
	input  wire                  OEB;
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

	always @(posedge CEB) begin
		if (!CSB) begin
			if (!WEB) begin
				mem[A] <= I;
			end
			else if (!OEB) begin
				O <= mem[A];
			end
		end
	end

endmodule
