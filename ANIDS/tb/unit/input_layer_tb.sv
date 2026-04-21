// ANIDS - Input Layer Testbench
`timescale 1ns/100ps
`include "anids_defines.vh"

module input_layer_tb;

	localparam FEATURE_WIDTH = `INPUT_LAYER_FEATURE_WIDTH;
	localparam COUNTER_WIDTH = `PIPELINE_COUNTER_WIDTH;
	localparam PAIR_WIDTH    = `INPUT_LAYER_PAIR_WIDTH;

	reg                         clk;
	reg                         resetN;
	reg                         enable;
	reg  [FEATURE_WIDTH-1:0]    features;
	reg  [COUNTER_WIDTH-1:0]    counter;
	wire [PAIR_WIDTH-1:0]       current_features;

	input_layer #(
		.FEATURE_WIDTH(FEATURE_WIDTH),
		.COUNTER_WIDTH(COUNTER_WIDTH),
		.PAIR_WIDTH   (PAIR_WIDTH)
	) dut (
		.clk              (clk),
		.resetN           (resetN),
		.enable           (enable),
		.features         (features),
		.counter          (counter),
		.current_features (current_features)
	);

	always #2.5 clk = ~clk;

	initial begin
		$dumpfile("input_layer_tb.vcd");
		$dumpvars(0, input_layer_tb);

		clk      = 1'b0;
		resetN   = 1'b0;
		enable   = 1'b0;
		features = 128'hFEDCBA98765432100123456789ABCDEF;
		counter  = {COUNTER_WIDTH{1'b0}};

		#2;
		check_output(2'b00, "reset clears output");

		resetN <= 1'b1;
		@(posedge clk);
		#2;
		check_output(2'b00, "enable low outputs zeros");

		enable  <= 1'b1;
		counter <= 7'd0;
		@(posedge clk);
		#2;
		check_output(2'b11, "counter 0 selects bits 1:0");

		counter <= 7'd1;
		@(posedge clk);
		#2;
		check_output(2'b11, "counter 1 selects bits 3:2");

		counter <= 7'd2;
		@(posedge clk);
		#2;
		check_output(2'b10, "counter 2 selects bits 5:4");

		counter <= 7'd63;
		@(posedge clk);
		#2;
		check_output(2'b11, "counter 63 selects bits 127:126");

		enable <= 1'b0;
		@(posedge clk);
		#2;
		check_output(2'b00, "enable low clears output after activity");

		$display("INPUT_LAYER TB PASSED");
		$finish;
	end

	task check_output(
		input [PAIR_WIDTH-1:0] expected,
		input [255:0]          test_name
	);
	begin
		if (current_features !== expected) begin
			$error("FAIL: %0s | got=%0b expected=%0b counter=%0d enable=%0b",
				test_name, current_features, expected, counter, enable);
			$finish;
		end
		else begin
			$display("PASS: %0s", test_name);
		end
	end
	endtask

endmodule
