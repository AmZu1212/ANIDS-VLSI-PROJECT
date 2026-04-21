// ANIDS - Memory Fetch Unit Testbench
`timescale 1ns/100ps
`include "anids_defines.vh"

module mem_fetch_unit_tb;

	localparam DATA_WIDTH    = `MFU_DATA_WIDTH;
	localparam FEATURE_WIDTH = `MFU_FEATURE_WIDTH;

	reg                     clk;
	reg                     resetN;
	reg                     fetch;
	reg                     valid;
	reg  [DATA_WIDTH-1:0]   mem_data;
	wire                    ready;
	wire                    updated;
	wire [FEATURE_WIDTH-1:0] features_out;

	always #2.5 clk = ~clk;

	mem_fetch_unit #(
		.DATA_WIDTH(DATA_WIDTH),
		.FEATURE_WIDTH(FEATURE_WIDTH)
	) dut (
		.clk          (clk),
		.resetN       (resetN),
		.fetch        (fetch),
		.valid        (valid),
		.mem_data     (mem_data),
		.ready        (ready),
		.features_out (features_out),
		.updated      (updated)
	);

	initial begin
		$dumpfile("mem_fetch_unit_tb.vcd");
		$dumpvars(0, mem_fetch_unit_tb);

		clk      = 1'b0;
		resetN   = 1'b0;
		fetch    = 1'b0;
		valid    = 1'b0;
		mem_data = {DATA_WIDTH{1'b0}};

		check_cycle(1'b0, 1'b0, 1'b0, 128'h00000000000000000000000000000000,
			1'b0, 1'b0, 128'h00000000000000000000000000000000, "reset clears state");

		check_cycle(1'b1, 1'b0, 1'b0, 128'h11112222333344445555666677778888,
			1'b0, 1'b0, 128'h00000000000000000000000000000000, "idle ignores valid without fetch");

		check_cycle(1'b1, 1'b1, 1'b0, 128'h11112222333344445555666677778888,
			1'b1, 1'b0, 128'h00000000000000000000000000000000, "fetch moves unit to pending");

		check_cycle(1'b1, 1'b0, 1'b0, 128'h9999AAAABBBBCCCCDDDDEEEEFFFF0000,
			1'b1, 1'b0, 128'h00000000000000000000000000000000, "pending waits for valid and holds features");

		check_cycle(1'b1, 1'b0, 1'b1, 128'h0123456789ABCDEFFEDCBA9876543210,
			1'b0, 1'b1, 128'h0123456789ABCDEFFEDCBA9876543210, "valid latches feature vector and returns idle");

		check_cycle(1'b1, 1'b0, 1'b1, 128'hAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA,
			1'b0, 1'b0, 128'h0123456789ABCDEFFEDCBA9876543210, "idle holds previous features without fetch");

		check_cycle(1'b1, 1'b1, 1'b0, 128'h13579BDF2468ACE013579BDF2468ACE0,
			1'b1, 1'b0, 128'h0123456789ABCDEFFEDCBA9876543210, "second fetch starts new pending transaction");

		check_cycle(1'b1, 1'b0, 1'b1, 128'h13579BDF2468ACE013579BDF2468ACE0,
			1'b0, 1'b1, 128'h13579BDF2468ACE013579BDF2468ACE0, "next valid updates features on next fetch");

		$display("MEM_FETCH_UNIT TB PASSED");
		$finish;
	end

	task check_cycle(
		input                      test_resetN,
		input                      test_fetch,
		input                      test_valid,
		input [DATA_WIDTH-1:0]     test_mem_data,
		input                      expected_ready,
		input                      expected_updated,
		input [FEATURE_WIDTH-1:0]  expected_features,
		input [255:0]              test_name
	);
	begin
		resetN   <= test_resetN;
		fetch    <= test_fetch;
		valid    <= test_valid;
		mem_data <= test_mem_data;

		@(posedge clk);
		#2;

		if (ready !== expected_ready || updated !== expected_updated || features_out !== expected_features) begin
			$error("FAIL: %0s | resetN=%0b fetch=%0b valid=%0b ready=%0b expected_ready=%0b updated=%0b expected_updated=%0b features=%032h expected_features=%032h",
				test_name, test_resetN, test_fetch, test_valid,
				ready, expected_ready, updated, expected_updated, features_out, expected_features);
			$finish;
		end
		else begin
			$display("PASS: %0s", test_name);
		end
	end
	endtask

endmodule
