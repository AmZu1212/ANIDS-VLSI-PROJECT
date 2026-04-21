// ANIDS - LUT RAM Read/Write Testbench
`timescale 1ns/100ps
`include "anids_defines.vh"

module lut_ram_tb;

  localparam DATA_WIDTH = `LUT_DATA_WIDTH;
  localparam ADDR_WIDTH = `LUT_ADDR_WIDTH;
  localparam RAM_DEPTH  = 1 << ADDR_WIDTH;

  // DUT signals
  reg                       clk;
  reg                       resetN;
  reg                       cs_n;
  reg                       wr_n;
  reg  [ADDR_WIDTH-1:0]     rw_addr;
  reg  [DATA_WIDTH-1:0]     wr_data;
  wire [DATA_WIDTH-1:0]     rd_data;

  // Clock generation: 200 MHz (period 5ns)
  always #2.5 clk = ~clk;

  // DUT
  DW_ram_rw_s_dff #(
    .data_width (DATA_WIDTH),
    .depth      (RAM_DEPTH),
    .rst_mode   (0)
  ) dut (
    .clk      (clk),
    .rst_n    (resetN),
    .cs_n     (cs_n),
    .wr_n     (wr_n),
    .rw_addr  (rw_addr),
    .data_in  (wr_data),
    .data_out (rd_data)
  );

  integer idx;
  integer errors;

  initial begin
    $dumpfile("lut_ram_tb.vcd");
    $dumpvars(0, lut_ram_tb);

    // Reset and defaults
    clk     = 1'b0;
    resetN  = 1'b0;
    cs_n    = 1'b1;
    wr_n    = 1'b1;
    rw_addr = {ADDR_WIDTH{1'b0}};
    wr_data = {DATA_WIDTH{1'b0}};
    errors  = 0;

    // Release reset
    repeat (2) @(posedge clk);
    resetN = 1'b1;

    // Write phase: write each location with its address value
    for (idx = 0; idx < RAM_DEPTH; idx = idx + 1) begin
      cs_n    <= 1'b0;
      wr_n    <= 1'b0;
      rw_addr <= idx[ADDR_WIDTH-1:0];
      wr_data <= idx[DATA_WIDTH-1:0];
      @(posedge clk);
    end

    // Return the RAM to idle before the read phase.
    cs_n <= 1'b1;
    wr_n <= 1'b1;
    @(posedge clk);

    // Read/verify phase.
    for (idx = 0; idx < RAM_DEPTH; idx = idx + 1) begin
      cs_n    <= 1'b0;
      wr_n    <= 1'b1;
      rw_addr <= idx[ADDR_WIDTH-1:0];
      @(posedge clk);
      #1;
      if (rd_data !== idx[DATA_WIDTH-1:0]) begin
        $error("Mismatch at addr %0d: got %0h expected %0h",
               idx, rd_data, idx[DATA_WIDTH-1:0]);
        errors = errors + 1;
      end else begin
        $display("PASS addr %0d data %0h", idx, rd_data);
      end
    end

    if (errors == 0) begin
      $display("LUT_RAM TB PASSED (%0d entries)", RAM_DEPTH);
    end
    else begin
      $display("LUT_RAM TB FAILED with %0d errors", errors);
      $fatal(1);
    end

    $finish;
  end
endmodule
