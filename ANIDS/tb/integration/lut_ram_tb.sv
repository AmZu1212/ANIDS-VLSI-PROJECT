// ANIDS - LUT RAM Read/Write Testbench
`timescale 1ns/100ps
`include "anids_defines.vh"

module lut_ram_tb;

  localparam DATA_WIDTH = `LUT_DATA_WIDTH;
  localparam ADDR_WIDTH = `LUT_ADDR_WIDTH;
  localparam RAM_DEPTH  = 1 << ADDR_WIDTH;

  // DUT signals
  reg                       CE;
  reg                       resetN;
  reg                       CSB;
  reg                       WEB;
  reg  [ADDR_WIDTH-1:0]     A;
  reg  [DATA_WIDTH-1:0]     I;
  wire [DATA_WIDTH-1:0]     O;

  // Clock generation: 200 MHz (period 5ns)
  always #2.5 CE = ~CE;

  // DUT
  DW_ram_rw_s_dff #(
    .data_width (DATA_WIDTH),
    .depth      (RAM_DEPTH),
    .rst_mode   (0)
  ) dut (
    .CE       (CE),
    .resetN   (resetN),
    .CSB      (CSB),
    .WEB      (WEB),
    .A        (A),
    .I        (I),
    .O        (O)
  );

  integer idx;
  integer errors;

  initial begin
    $dumpfile("lut_ram_tb.vcd");
    $dumpvars(0, lut_ram_tb);

    // Reset and defaults
    CE      = 1'b0;
    resetN  = 1'b0;
    CSB     = 1'b1;
    WEB     = 1'b1;
    A       = {ADDR_WIDTH{1'b0}};
    I       = {DATA_WIDTH{1'b0}};
    errors  = 0;

    // Release reset
    repeat (2) @(posedge CE);
    resetN = 1'b1;

    // Write phase: write each location with its address value
    for (idx = 0; idx < RAM_DEPTH; idx = idx + 1) begin
      CSB <= 1'b0;
      WEB <= 1'b0;
      A   <= idx[ADDR_WIDTH-1:0];
      I   <= idx[DATA_WIDTH-1:0];
      @(posedge CE);
    end

    // Return the RAM to idle before the read phase.
    CSB <= 1'b1;
    WEB <= 1'b1;
    @(posedge CE);

    // Read/verify phase.
    for (idx = 0; idx < RAM_DEPTH; idx = idx + 1) begin
      CSB <= 1'b0;
      WEB <= 1'b1;
      A   <= idx[ADDR_WIDTH-1:0];
      @(posedge CE);
      #1;
      if (O !== idx[DATA_WIDTH-1:0]) begin
        $error("Mismatch at addr %0d: got %0h expected %0h",
               idx, O, idx[DATA_WIDTH-1:0]);
        errors = errors + 1;
      end else begin
        $display("PASS addr %0d data %0h", idx, O);
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
