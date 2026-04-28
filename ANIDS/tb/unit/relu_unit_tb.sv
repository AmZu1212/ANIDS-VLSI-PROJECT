// ANIDS - ReLU Unit Testbench
`timescale 1ns/100ps
`include "anids_defines.vh"

module relu_unit_tb;

	localparam DATA_WIDTH = `RELU_WIDTH;

	reg  signed [DATA_WIDTH-1:0] in_data;
	reg                          resetN;
	reg                          ready;
	wire        [DATA_WIDTH-1:0] out_data;

	relu_unit #(
		.DATA_WIDTH(DATA_WIDTH)
	) dut (
		.in_data  (in_data),
		.resetN   (resetN),
		.ready    (ready),
		.out_data (out_data)
	);

	initial begin
		$dumpfile("relu_unit_tb.vcd");
		$dumpvars(0, relu_unit_tb);

		in_data = '0;
		resetN  = 1'b0;
		ready   = 1'b0;

		#1;
		check_output(8'sd25,  1'b0, 1'b1, 8'd0,   "reset clears output");
		check_output(8'sd25,  1'b1, 1'b0, 8'd0,   "ready low holds reset value");
		check_output(8'sd25,  1'b1, 1'b1, 8'd25,  "ready high captures positive input");
		check_output(-8'sd7,  1'b1, 1'b0, 8'd25,  "ready low holds previous positive result");
		check_output(8'sd0,   1'b1, 1'b1, 8'd0,   "ready high captures zero input");
		check_output(8'sd64,  1'b1, 1'b0, 8'd0,   "ready low holds zero result");
		check_output(-8'sd1,  1'b1, 1'b1, 8'd0,   "negative one clamps to zero");
		check_output(-8'sd64, 1'b1, 1'b1, 8'd0,   "negative value clamps to zero");
		check_output(8'sd127, 1'b1, 1'b1, 8'd127, "max positive passes through");
		check_output(8'sd1,   1'b1, 1'b0, 8'd127, "ready low holds max positive result");

		$display("RELU_UNIT TB PASSED");
		$finish;
	end

	task check_output(
		input signed [DATA_WIDTH-1:0] test_in,
		input                         test_resetN,
		input                         test_ready,
		input        [DATA_WIDTH-1:0] expected,
		input [255:0]                 test_name
	);
	begin
		in_data = test_in;
		resetN  = test_resetN;
		ready   = test_ready;
		#1;

		if (out_data !== expected) begin
			$error("FAIL: %0s | in=%0d resetN=%0b ready=%0b out=%0d expected=%0d",
				test_name, test_in, test_resetN, test_ready, out_data, expected);
			$finish;
		end
		else begin
			$display("PASS: %0s", test_name);
		end
	end
	endtask

endmodule
