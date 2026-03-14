// ANIDS - Result Status Encoder Testbench
`timescale 1ns/100ps
`include "anids_defines.vh"

module result_status_encoder_tb;

	localparam [7:0] STATUS_NOT_ANOMALY = 8'd0;
	localparam [7:0] STATUS_ANOMALY     = 8'd1;
	localparam [7:0] STATUS_WAITING     = 8'd2;
	localparam [7:0] STATUS_IDLE        = 8'd3;
	localparam integer RESULT_HOLD_CYCLES = 8;

	reg                         clk;
	reg                         resetN;
	reg                         start;
	reg                         done;
	reg                         outlier_pulse;
	wire                        result_wr_en;
	wire [`APB_DATA_WIDTH-1:0]  result_wr_data;

	result_status_encoder dut (
		.clk           (clk),
		.resetN        (resetN),
		.start         (start),
		.done          (done),
		.outlier_pulse (outlier_pulse),
		.result_wr_en  (result_wr_en),
		.result_wr_data(result_wr_data)
	);

	always #2.5 clk = ~clk;

	initial begin
		$dumpfile("result_status_encoder_tb.vcd");
		$dumpvars(0, result_status_encoder_tb);

		clk           = 1'b0;
		resetN        = 1'b0;
		start         = 1'b0;
		done          = 1'b0;
		outlier_pulse = 1'b0;

		@(posedge clk);
		#2;
		check_outputs(1'b0, STATUS_IDLE, "reset keeps write disabled");

		resetN = 1'b1;
		@(posedge clk);
		#2;
		check_outputs(1'b1, STATUS_IDLE, "first active cycle writes idle status");

		@(posedge clk);
		#2;
		check_outputs(1'b0, STATUS_IDLE, "idle status write is a one-cycle pulse");

		start = 1'b1;
		@(posedge clk);
		#2;
		check_outputs(1'b1, STATUS_WAITING, "start drives status to waiting");

		@(posedge clk);
		#2;
		check_outputs(1'b0, STATUS_WAITING, "waiting write is a one-cycle pulse");

		done          = 1'b1;
		outlier_pulse = 1'b1;
		@(posedge clk);
		#2;
		check_outputs(1'b1, STATUS_ANOMALY, "anomaly result is encoded on done");

		done          = 1'b0;
		outlier_pulse = 1'b0;
		repeat (RESULT_HOLD_CYCLES - 1) begin
			@(posedge clk);
			#2;
			check_outputs(1'b0, STATUS_ANOMALY, "anomaly status is held for polling");
		end
		@(posedge clk);
		#2;
		check_outputs(1'b1, STATUS_WAITING, "status returns to waiting after anomaly hold");

		done = 1'b1;
		@(posedge clk);
		#2;
		check_outputs(1'b1, STATUS_NOT_ANOMALY, "non-anomaly result is encoded on done");

		done = 1'b0;
		repeat (RESULT_HOLD_CYCLES - 1) begin
			@(posedge clk);
			#2;
			check_outputs(1'b0, STATUS_NOT_ANOMALY, "non-anomaly status is held for polling");
		end
		@(posedge clk);
		#2;
		check_outputs(1'b1, STATUS_WAITING, "status returns to waiting after non-anomaly hold");

		start = 1'b0;
		@(posedge clk);
		#2;
		check_outputs(1'b1, STATUS_IDLE, "dropping start returns to idle");

		@(posedge clk);
		#2;
		check_outputs(1'b0, STATUS_IDLE, "idle transition is a one-cycle pulse");

		$display("RESULT_STATUS_ENCODER TB PASSED");
		$finish;
	end

	task check_outputs(
		input                          expected_wr_en,
		input [`APB_DATA_WIDTH-1:0]    expected_wr_data,
		input [255:0]                  test_name
	);
	begin
		if (result_wr_en !== expected_wr_en || result_wr_data !== expected_wr_data) begin
			$error("FAIL: %0s | wr_en=%0b expected_wr_en=%0b wr_data=%0d expected_wr_data=%0d",
				test_name, result_wr_en, expected_wr_en, result_wr_data, expected_wr_data);
			$finish;
		end
		else begin
			$display("PASS: %0s", test_name);
		end
	end
	endtask

endmodule
