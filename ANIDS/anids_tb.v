/* ident "@(#)tso_tb.v:/dtv/i88/project/design/ifu/tso/tso_tb.v 1.17 06/25/07" */
/**************************************************************************/
/*                                                                        */
/*    Copyright (c) 1998 ZORAN Corporation, All Rights Reserved           */
/*    THIS IS UNPUBLISHED PROPRIETARY SOURCE CODE OF ZORAN CORPORATION    */
/*                                                                        */
/*
 *    File : tso_tb.v
 *    Type : Verilog File
 *    Module : tso_tb.v
 *    Modification Time : 06/25/07 15:28:09
 *                                                                        */
/*                                                                        */
/**************************************************************************/



/*************************************************************************************

  TSO Test-Bench

*************************************************************************************/

// The TB tests the TSO interface with the CPU, IO, tso and MCU.



`define TSI_TSO_DATA       "tsi_tso_data.tso"
`define MCU_TSO_DATA       "mcu_tso_data.tso"
`define CPU_CBUS_DATA      "cpu_cbus_data.tso"
`define NUM_OF_WORDS       60

`timescale 1ns/100ps

module tso_tb;


// -----------------------------------------------------------
//                  Registers & Wires
// -----------------------------------------------------------

   wire [7:0]   tsi1_data_in ;
   wire         tsi1_wr;
   wire 	tsi1_start;

   wire [31:0]  tso_cpu_obus;
   wire		tso_cpu_rdy;
   reg		cpu_tso_wr;
   reg 		cpu_tso_rd;
   reg [12:0] 	cpu_tso_address;
   reg [31:0] 	cpu_tso_bus_in;

   reg 		misc_tso_clk;
   reg 		misc_tso_rst;
   reg 		misc_tso_scan_act;

   wire 	mcu_tso_wr;
   wire [7:0] 	tso_mcu_avail;
   wire [31:0]  mcu_tso_data;

   wire 	tso_ram_cs;
   wire 	tso_ram_rd;
   wire [5:0] 	tso_ram_addr;
   wire [31:0]	tso_ram_d_in;
   wire [31:0]  ram_tso_d_out;

   reg          flag_clk;

   integer      i;

   reg [12:0]   tmp_cpu_address;
   reg [31:0]   tmp_cpu_data;
   reg [7:0]    tmp_tsi1_data_in;

   reg [44:0]   cpu_trans_reg [27:0];

   reg          mcu_start;
   reg          tsi_start;

   wire			tso_clk_int;
   wire	        tso_start;
   wire	        tso_valid;
   wire	[7:0]   tso_data;
   wire	        tso_serial;
   wire	        tso_pclk;



// ----------------------------------------------------------------------
//                   Instantiation
// ----------------------------------------------------------------------

tso tso(   .clk			(misc_tso_clk),
           .`A_RESET		(misc_tso_rst),
           .scan_act		(misc_tso_scan_act),

           .c_tso_obus		(tso_cpu_obus[31:0]),
           .c_tso_rdy		(tso_cpu_rdy),
           .cpu_wr		(cpu_tso_wr),
           .cpu_rd		(cpu_tso_rd),
           .c_add		(cpu_tso_address[12:0]),
           .c_bus_in		(cpu_tso_bus_in[31:0]),

           .tso_mcu_avail	(tso_mcu_avail[7:0]),
           .mcu_wr		(mcu_tso_wr),
           .mcu_d_bus_in	(mcu_tso_data[31:0]),

           .tso_clk_int		(tso_clk_int),
           .tso_start   	(tso_start),
           .tso_valid    	(tso_valid),
           .tso_data     	(tso_data[7:0]),
	   .tso_serial          (tso_serial),
	   .tso_pclk            (tso_pclk),

           .tso_ram_cs	        (tso_ram_cs),
           .tso_ram_rd	        (tso_ram_rd),
           .tso_ram_addr	(tso_ram_addr[5:0]),
           .tso_ram_d_in	(tso_ram_d_in[31:0]),
           .tso_ram_d_out	(ram_tso_d_out[31:0]),

           .tsi1_data_in	(tsi1_data_in[7:0]),
           .tsi1_wr		(tsi1_wr),
           .tsi1_start		(tsi1_start),
           .tsi1_err		(tsi1_err),

           .tsi2_data_in	(8'b0),
           .tsi2_wr		(1'b0),
           .tsi2_start		(1'b0),
           .tsi2_err		(1'b0),

           .fe_data_in          (8'b0),
           .fe_start            (1'b0),
           .fe_wr               (1'b0),
           .fe_valid            (1'b0),
           .fe_fail             (1'b0)
	  );


// New Storage-RAM (buffer) - with a retention shell
ram48x32_w ram(   .nreset	(misc_tso_rst),
                  .clk		(misc_tso_clk),
                  .csn		(tso_ram_cs),
                  .wen		(tso_ram_rd),
                  .a		(tso_ram_addr[5:0]),
                  .i		(tso_ram_d_in[31:0]),
                  .o		(ram_tso_d_out[31:0]),
                  .scan_shift	(misc_tso_scan_act),
                  .bist_mode	(1'b0),
                  .bist_in	(60'b0),
                  .bist_out	(),
                  .retention	(1'b1),
                  .scan_ram_bypass  (1'b0),
                  .amp_adjust	(3'b011)
                 );


mcu_stub mcu(  .mcu_clk           (misc_tso_clk),
               .mcu_out_wr        (mcu_tso_wr),
               .mcu_out_data      (mcu_tso_data[31:0]),
               .mcu_avail         (tso_mcu_avail[7:0]),
               .start	          (mcu_start)
	       );


tsi1_stub tsi1(  .tsi1_clk       (misc_tso_clk),
                 .tsi1_data      (tsi1_data_in[7:0]),
                 .tsi1_wr        (tsi1_wr),
                 .tsi1_start     (tsi1_start),
		 .tsi1_err       (tsi1_err),
                 .start	         (tsi_start)
	       );


// ----------------------------------------------------------------------
//                   Test Pattern
// ----------------------------------------------------------------------


initial begin
   initiate_all;                                 // Initiates all input signals to '0' and open necessary files

   #100
   @(posedge misc_tso_clk);
   cpu_write_TSI;                                // CPU WRITE configurations (TSI master)
   #100
   @(posedge misc_tso_clk);
   cpu_read_TSI;                                 // CPU READ transaction
   @(posedge misc_tso_clk);
   mcu_start = 1'b0;
   tsi_start = 1'b1;


   #500000                                       /* Turn-Over (TO) */
   @(posedge misc_tso_clk);
   flush_mem ;                                   // clear the buffer by software.


   @(posedge misc_tso_clk);
   cpu_write_MCU;                                // CPU WRITE configurations (MCU master)
   #100
   @(posedge misc_tso_clk);
   cpu_read_MCU;                                 // CPU READ transaction
   @(posedge misc_tso_clk);
   tsi_start = 1'b0;
   mcu_start = 1'b1;


//   #100000  $finish;

end




// ----------------------------------------------------------------------
//                   Clock generator  (Duty cycle 5ns)
// ----------------------------------------------------------------------


  always
    #2.5 misc_tso_clk = ~misc_tso_clk;


// ----------------------------------------------------------------------
//                   Tasks
// ----------------------------------------------------------------------


 task initiate_all;        // sets all tso inputs to '0'.
      begin
	 misc_tso_clk = 1'b0;
	 misc_tso_rst = 1'b0;
	 misc_tso_scan_act = 1'b0;

	 cpu_tso_wr = 1'b0;
	 cpu_tso_rd = 1'b0;
	 cpu_tso_address = 13'b0;
	 cpu_tso_bus_in = 32'b0;

	 mcu_start = 1'b0;
	 tsi_start = 1'b0;

	 flag_clk = 0;

         #2 misc_tso_rst = 1'b1;     // Disable Reset signal.

         $readmemh(`CPU_CBUS_DATA, cpu_trans_reg);      // opens the cpu configuration file.
      end
 endtask


 task cpu_write_TSI();
   for (i=0; i<7; i=i+1) begin
   cpu_trans_reg[i][44:0] = cpu_trans_reg[i];
     if (cpu_trans_reg[i][44] == 1) begin

         tmp_cpu_address = cpu_trans_reg[i][43:32];
         tmp_cpu_data    = cpu_trans_reg[i][31:0];
         @(posedge misc_tso_clk);
	 cpu_tso_wr       = 1'b1;
	 cpu_tso_rd       = 1'b0;
	 cpu_tso_address  = tmp_cpu_address;
 	 cpu_tso_bus_in   = tmp_cpu_data;
	 @(posedge misc_tso_clk);
	 #1 cpu_tso_wr    = 1'b0;
	 cpu_tso_rd       = 1'b0;
	 cpu_tso_address  = 13'h0;
 	 cpu_tso_bus_in   = 31'h0;
        end
     else $display("Error reading data from input file !\n\n");
   end
 endtask


 task cpu_read_TSI;
   for (i=0; i<7; i=i+1) begin
     if (cpu_trans_reg[i+7][44] == 0) begin
        tmp_cpu_address = cpu_trans_reg[i+7][43:32];
        @(posedge misc_tso_clk);
	cpu_tso_wr    = 1'b0;
	cpu_tso_rd     = 1'b1;
	cpu_tso_address  = tmp_cpu_address;
	@(posedge misc_tso_clk);
	#1 cpu_tso_wr    = 1'b0;
	cpu_tso_rd     = 1'b0;
	cpu_tso_address  = 13'h0;
       end
     else $display("Error reading data from input file !\n\n");
   end
 endtask

  task cpu_write_MCU();
   for (i=14; i<21; i=i+1) begin
   cpu_trans_reg[i][44:0] = cpu_trans_reg[i];
     if (cpu_trans_reg[i][44] == 1) begin

         tmp_cpu_address = cpu_trans_reg[i][43:32];
         tmp_cpu_data    = cpu_trans_reg[i][31:0];
         @(posedge misc_tso_clk);
	 cpu_tso_wr       = 1'b1;
	 cpu_tso_rd       = 1'b0;
	 cpu_tso_address  = tmp_cpu_address;
 	 cpu_tso_bus_in   = tmp_cpu_data;
	 @(posedge misc_tso_clk);
	 #1 cpu_tso_wr    = 1'b0;
	 cpu_tso_rd       = 1'b0;
	 cpu_tso_address  = 13'h0;
 	 cpu_tso_bus_in   = 31'h0;
        end
     else $display("Error reading data from input file !\n\n");
   end
 endtask


 task cpu_read_MCU;
   for (i=14; i<21; i=i+1) begin
     if (cpu_trans_reg[i+7][44] == 0) begin
        tmp_cpu_address = cpu_trans_reg[i+7][43:32];
        @(posedge misc_tso_clk);
	cpu_tso_wr    = 1'b0;
	cpu_tso_rd     = 1'b1;
	cpu_tso_address  = tmp_cpu_address;
	@(posedge misc_tso_clk);
	#1 cpu_tso_wr    = 1'b0;
	cpu_tso_rd     = 1'b0;
	cpu_tso_address  = 13'h0;
       end
     else $display("Error reading data from input file !\n\n");
   end
 endtask


 task flush_mem;
 begin
   cpu_tso_wr       = 1'b1;
   cpu_tso_rd       = 1'b0;
   cpu_tso_address  = `TSO_In_cfg;
   if (mcu_start)
      cpu_tso_bus_in   = 32'h00000006;              // FFClear = 1
   else
      cpu_tso_bus_in   = 32'h00000004;
   @(posedge misc_tso_clk);
   #1 cpu_tso_wr    = 1'b0;
   cpu_tso_rd       = 1'b0;
   cpu_tso_address  = 13'h0;
   cpu_tso_bus_in   = 31'h0;
 end
 endtask


endmodule   // tso_tb



// ----------------------------------------------------------------------
//                   MCU Stub
// ----------------------------------------------------------------------


module mcu_stub(mcu_out_wr, mcu_out_data, mcu_avail, mcu_clk, start);

 output 	 mcu_out_wr;
 output [31:0]	 mcu_out_data;
 input  [7:0]    mcu_avail;
 input           mcu_clk;
 input           start;

 reg             mcu_out_wr;
 reg    [31:0]   mcu_out_data;
 reg    [31:0]   mcu_dout;
 reg    [31:0]   mcu_trans_reg [4*(`NUM_OF_WORDS)-1:0];

 integer         i;


initial begin
  i = 0;
  mcu_out_wr = 1'b0;
  mcu_out_data = 32'b0;
  $readmemh(`MCU_TSO_DATA, mcu_trans_reg);                                           // opens the MCU data file
end


 always @(posedge mcu_clk)
   if (start && (i < 4*`NUM_OF_WORDS) && (mcu_avail > 8'b0))
     begin
       mcu_dout = mcu_trans_reg[i][31:0];
       i = i+1;
     end

 always @(posedge mcu_clk)
   if (start && (mcu_avail > 8'b0))   mcu_write(mcu_dout);


 task mcu_write;
   input  [31:0]    mcu_tso_data;
      begin
           mcu_out_wr = 1'b1;
        #1 mcu_out_data = mcu_tso_data;
      end
 endtask

endmodule  // mcu_stub


// ----------------------------------------------------------------------
//                   TSI1 Stub
// ----------------------------------------------------------------------


module tsi1_stub(tsi1_clk, tsi1_wr, tsi1_data, tsi1_start, tsi1_err, start);

 output 	 	 tsi1_wr;
 output [7:0]	 tsi1_data;
 output          tsi1_start;
 output          tsi1_err;
 input           tsi1_clk;
 input           start;

 reg 	         tsi1_wr;
 reg    [7:0]	 tsi1_data;
 reg             tsi1_start;
 reg             tsi1_err;
 reg             init_start;

 reg    [7:0]    tsi_trans_reg [4*(`NUM_OF_WORDS)-1:0];

 integer 	 	 i;
 integer         pack_len_count;


 initial begin
   i = 0;
   pack_len_count = 0;
   init_start = 1'b0;
   tsi1_wr = 1'b0;
   tsi1_start = 1'b0;
   $readmemh(`TSI_TSO_DATA, tsi_trans_reg);                                          // opens the TSI data file
 end


 always @(posedge tsi1_clk)
   if (tsi1_start)	init_start <= #1 1'b1;                                       // waking up after Reset.

 always @(posedge tsi1_clk)
   if (start)            tsi_write(tsi1_data);

 always @(posedge tsi1_clk)
   if (start && (tsi1_data==`SYNC_BYTE)) begin
      tsi1_wr  =  1'b1;
      tsi1_start = init_start ? (pack_len_count==187) : 1'b1;
      @(posedge tsi1_clk);
      tsi1_start = 1'b0;
      end

 always @(posedge tsi1_clk)
   if (start && (i < 4*`NUM_OF_WORDS))  begin
      tsi1_data = tsi_trans_reg[i][7:0];
      i = i+1;
      end

 always @(posedge tsi1_clk)
      pack_len_count = tsi1_start ? 0 : pack_len_count + 1;


 task tsi_write;
   input [7:0]     tsw_data;
      begin
         tsi1_data = tsw_data;
         tsi1_err = 1'b0;
      end
 endtask

endmodule  // tsi1_stub


