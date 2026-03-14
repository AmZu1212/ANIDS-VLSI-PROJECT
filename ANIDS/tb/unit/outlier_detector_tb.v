// ANIDS - Outlier Detector Testbench
`timescale 1ns/100ps
`include "anids_defines.vh"

module outlier_detector_tb;

	localparam DATA_WIDTH = `RELU_WIDTH;

	reg                    clk;
	reg                    resetN;
	reg                    ready;
	reg  [DATA_WIDTH-1:0]  data_in;
	reg  [DATA_WIDTH-1:0]  threshold;
	wire                   outlier_pulse;
	wire                   output_ready;

	always #2.5 clk = ~clk;

	outlier_detector #(
		.DATA_WIDTH(DATA_WIDTH)
	) dut (
		.clk           (clk),
		.resetN        (resetN),
		.ready         (ready),
		.data_in       (data_in),
		.threshold     (threshold),
		.outlier_pulse (outlier_pulse),
		.output_ready  (output_ready)
	);

	initial begin
		$dumpfile("outlier_detector_tb.vcd");
		$dumpvars(0, outlier_detector_tb);

		clk       = 1'b0;
		resetN    = 1'b0;
		ready     = 1'b0;
		data_in   = '0;
		threshold = '0;

		check_cycle(1'b0, 1'b0, 8'd25, 8'd10, 1'b0, 1'b0, "reset clears outputs");

		check_cycle(1'b1, 1'b0, 8'd25, 8'd10, 1'b0, 1'b0, "ready low blocks evaluation");
		check_cycle(1'b1, 1'b1, 8'd9,  8'd10, 1'b0, 1'b1, "below threshold is not outlier");
		check_cycle(1'b1, 1'b1, 8'd10, 8'd10, 1'b0, 1'b1, "equal threshold is not outlier");
		check_cycle(1'b1, 1'b1, 8'd11, 8'd10, 1'b1, 1'b1, "above threshold is outlier");
		check_cycle(1'b1, 1'b0, 8'd11, 8'd10, 1'b0, 1'b0, "pulses drop after ready goes low");
		check_cycle(1'b1, 1'b1, 8'd100,8'd50, 1'b1, 1'b1, "larger above-threshold value pulses");
		check_cycle(1'b1, 1'b1, -8'sd5,-8'sd10,1'b1, 1'b1, "signed negative comparison works");
		check_cycle(1'b1, 1'b1, -8'sd12,-8'sd10,1'b0, 1'b1, "more negative value is not outlier");
		check_cycle(1'b1, 1'b0, 8'd100,8'd50, 1'b0, 1'b0, "single-cycle pulse behavior");

		$display("OUTLIER_DETECTOR TB PASSED");
		$finish;
	end

	task check_cycle(
		input                      test_resetN,
		input                      test_ready,
		input [DATA_WIDTH-1:0]     test_data_in,
		input [DATA_WIDTH-1:0]     test_threshold,
		input                      expected_outlier,
		input                      expected_output_ready,
		input [255:0]              test_name
	);
	begin
		resetN    <= test_resetN;
		ready     <= test_ready;
		data_in   <= test_data_in;
		threshold <= test_threshold;

		@(posedge clk);
		#2;

		if (outlier_pulse !== expected_outlier || output_ready !== expected_output_ready) begin
			$error("FAIL: %0s | resetN=%0b ready=%0b data_in=%0d threshold=%0d outlier=%0b expected_outlier=%0b output_ready=%0b expected_output_ready=%0b",
				test_name, test_resetN, test_ready, test_data_in, test_threshold,
				outlier_pulse, expected_outlier, output_ready, expected_output_ready);
			$finish;
		end
		else begin
			$display("PASS: %0s", test_name);
		end
	end
	endtask

endmodule
