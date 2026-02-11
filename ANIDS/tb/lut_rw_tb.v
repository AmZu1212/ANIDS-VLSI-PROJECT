// ANIDS - LUT Memory Read/Write Testbench
`timescale 1ns/100ps
`include "anids_defines.vh"

module lut_rw_tb;

  localparam DATA_WIDTH = `LUT_DATA_WIDTH;
  localparam ADDR_WIDTH = `LUT_ADDR_WIDTH;
  localparam RAM_DEPTH  = 1 << ADDR_WIDTH;

  // DUT signals
  reg                       clk;
  reg                       resetN;
  reg  [ADDR_WIDTH-1:0]     rd_addr;
  reg  [ADDR_WIDTH-1:0]     wr_addr;
  reg  [DATA_WIDTH-1:0]     wr_data;
  reg                       wr_en;
  wire [DATA_WIDTH-1:0]     rd_data;

  // Clock generation: 200 MHz (period 5ns)
  always #2.5 clk = ~clk;

  // DUT
  lut_mem dut (
    .clk     (clk),
    .resetN  (resetN),
    .rd_addr (rd_addr),
    .wr_addr (wr_addr),
    .wr_en   (wr_en),
    .wr_data (wr_data),
    .rd_data (rd_data)
  );

  integer idx;
  integer errors;

  initial begin
    $dumpfile("lut_rw_tb.vcd");
    $dumpvars(0, lut_rw_tb);

    // Reset and defaults
    clk     = 1'b0;
    resetN  = 1'b0;
    rd_addr = {ADDR_WIDTH{1'b0}};
    wr_addr = {ADDR_WIDTH{1'b0}};
    wr_data = {DATA_WIDTH{1'b0}};
    wr_en   = 1'b0;
    errors  = 0;

    // Release reset
    repeat (2) @(posedge clk);
    resetN = 1'b1;

    // Write phase: write each location with its address value
    for (idx = 0; idx < RAM_DEPTH; idx = idx + 1) begin
      wr_en   <= 1'b1;
      wr_addr <= idx[ADDR_WIDTH-1:0];
      wr_data <= idx[DATA_WIDTH-1:0];
      @(posedge clk);
      wr_en   <= 1'b0;
    end

    // Allow last write to settle
    @(posedge clk);

    // Read/verify phase (synchronous read requires one-cycle latency)
    // Prime first read
    rd_addr <= {ADDR_WIDTH{1'b0}};
    @(posedge clk);
    #1;
    if (rd_data !== {DATA_WIDTH{1'b0}}) begin
      $error("Mismatch at addr 0: got %0h expected %0h", rd_data, {DATA_WIDTH{1'b0}});
      errors = errors + 1;
    end else begin
      $display("PASS addr 0 data %0h", rd_data);
    end

    // Subsequent reads: rd_data corresponds to rd_addr from previous cycle
    for (idx = 1; idx < RAM_DEPTH; idx = idx + 1) begin
      rd_addr <= idx[ADDR_WIDTH-1:0];
      @(posedge clk);
      #1;
      if (rd_data !== (idx-1)) begin
        $error("Mismatch at addr %0d: got %0h expected %0h",
               idx-1, rd_data, (idx-1));
        errors = errors + 1;
      end else begin
        $display("PASS addr %0d data %0h", idx-1, rd_data);
      end
    end

    // Capture last address (RAM_DEPTH-1)
    @(posedge clk);
    #1;
    if (rd_data !== (RAM_DEPTH-1)) begin
      $error("Mismatch at addr %0d: got %0h expected %0h",
             RAM_DEPTH-1, rd_data, (RAM_DEPTH-1));
      errors = errors + 1;
    end else begin
      $display("PASS addr %0d data %0h", RAM_DEPTH-1, rd_data);
    end

    if (errors == 0)
      $display("LUT_MEM TB PASSED (%0d entries)", RAM_DEPTH);
    else
      $display("LUT_MEM TB FAILED with %0d errors", errors);

    $finish;
  end
endmodule
