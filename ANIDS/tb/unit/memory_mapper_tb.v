// ANIDS - Memory Mapper Testbench
`timescale 1ns/100ps
`include "anids_defines.vh"

module memory_mapper_tb;

	localparam IN_WIDTH   = `MMAP_IN_WIDTH;
	localparam ADDR_WIDTH = `MMAP_ADDR_WIDTH;

	reg  signed [IN_WIDTH-1:0] in_value;
	wire        [ADDR_WIDTH-1:0] lut_addr;

	memory_mapper #(
		.IN_WIDTH   (IN_WIDTH),
		.ADDR_WIDTH (ADDR_WIDTH)
	) dut (
		.in_value (in_value),
		.lut_addr (lut_addr)
	);

initial begin
		$dumpfile("memory_mapper_tb.vcd");
		$dumpvars(0, memory_mapper_tb);

		run_full_sweep;

		$display("MEMORY_MAPPER TB PASSED");
		$finish;
	end

	task run_full_sweep;
		integer raw_val;
		reg signed [IN_WIDTH-1:0] test_in;
		reg [ADDR_WIDTH-1:0] expected_addr;
	begin
		for (raw_val = -128; raw_val <= 127; raw_val = raw_val + 1) begin
			test_in = raw_val;
			if (ADDR_WIDTH == IN_WIDTH) begin
				expected_addr = {~test_in[IN_WIDTH-1], test_in[IN_WIDTH-2:0]};
			end
			else begin
				expected_addr = {~test_in[IN_WIDTH-1], test_in[IN_WIDTH-2:1]};
			end
			check_map(test_in, expected_addr, "full sweep");
		end
	end
	endtask

	task check_map(
		input signed [IN_WIDTH-1:0]      test_in,
		input        [ADDR_WIDTH-1:0]    expected_addr,
		input [255:0]                    test_name
	);
	begin
		in_value = test_in;
		#1;

		if (lut_addr !== expected_addr) begin
			$error("FAIL: %0s | in=%0d addr=%0d expected_addr=%0d",
				test_name, test_in, lut_addr, expected_addr);
			$finish;
		end
		else begin
			$display("PASS: %0s", test_name);
		end
	end
	endtask

endmodule
