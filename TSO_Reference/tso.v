/* ident "@(#)tsd_cai.v:/i58/project/design/tsd/hdl/tsd/SCCS/s.tsd_cai.v 1.25 07/22/01" */
/**************************************************************************/
/*                                                                        */
/*    Copyright (c) 1998 ZORAN Corporation, All Rights Reserved           */
/*    THIS IS UNPUBLISHED PROPRIETARY SOURCE CODE OF ZORAN CORPORATION    */
/*                                                                        */
/*
 *    File : SCCS/tso.v
 *    Type : Verilog File
 *    Module : tso.v
 *    Sccs Identification (SID) : 1.25
 *    Modification Time : 11/12/07 15:41:27
 *                                                                        */
/*                                                                        */
/**************************************************************************/
/*
   TSO - Transport Stream Output Interface (I88), based on TSD-CA Interface Unit (I58).
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   The i88 can output Transport Stream data when required, usually for output to a Conditional Access Module (CAM).
   The source of the transport stream data may be from system memory (MCU) or from either from the TSI units.
   Data from the memory may be PID filtered, data from the TSI units is unfiltered.
   
   For further information see the micro-architecture specifications at: //DTV/i88/HW/doc/A&A/IFU/TSO/I88_TSO.doc.
*/


 module tso(cpu_wr, cpu_rd, c_add, c_bus_in, c_tso_obus, c_tso_rdy,
            tso_mcu_avail, mcu_wr, mcu_d_bus_in,
            tso_clk_int, tso_start, tso_valid, tso_data, tso_serial, tso_pclk, 
            tso_ram_cs, tso_ram_rd, tso_ram_addr, tso_ram_d_in, tso_ram_d_out,
            clk, `A_RESET, scan_act, tsi1_data_in, tsi1_wr, tsi1_start, tsi1_err, 
	    tsi2_data_in, tsi2_wr, tsi2_start, tsi2_err, fe_data_in, fe_start, fe_valid, fe_wr, fe_fail);  


// -----------------------------------------------------------       
//                  C_Bus Interface 
// -----------------------------------------------------------  

  output [31:0]  c_tso_obus;
  output 	 c_tso_rdy;

  input	         cpu_wr; 
  input	         cpu_rd; 
  input  [12:0]  c_add;
  input  [31:0]  c_bus_in;

// -----------------------------------------------------------       
//        Buffer Ram Handling Logic Interface                                        // <=> MCU Interface
// -----------------------------------------------------------  

  output [7:0]   tso_mcu_avail;

  input	         mcu_wr;                                                              // <=> mcu_tso_wr
  input [31:0]   mcu_d_bus_in;                                                        // <=> mcu_tso_data_in

// -----------------------------------------------------------       
//              Formatter Interface
// -----------------------------------------------------------  

  output         tso_clk_int;                                                        // clock polarity support (see below).
  output   	 tso_start;                                                     
  output   	 tso_valid;
  output [7:0]   tso_data;
  output         tso_serial;
  output         tso_pclk;


// -----------------------------------------------------------       
//              Buffer RAM Interface
// -----------------------------------------------------------  

  output	 tso_ram_cs;
  output	 tso_ram_rd;
  output [5:0]	 tso_ram_addr;                                                       // Extended to from 4-bit to 6-bit width.
  output [31:0]	 tso_ram_d_in;
  input  [31:0]	 tso_ram_d_out;


// -----------------------------------------------------------       
//                  Misc.
// -----------------------------------------------------------       

  input 	 clk;
  input 	 `A_RESET;
  input 	 scan_act;
  
  
// -----------------------------------------------------------                       
//                  TSI interface						     // new interface (acts as a data source).
// -----------------------------------------------------------       

  input [7:0] 	 tsi1_data_in;
  input 	 tsi1_wr;
  input 	 tsi1_start;
  input 	 tsi1_err;

  input [7:0]	 tsi2_data_in;  
  input 	 tsi2_wr;
  input 	 tsi2_start;
  input 	 tsi2_err;  


// -----------------------------------------------------------                       
//                  FE interface						     // new interface (acts as a data source).
// -----------------------------------------------------------       

  input [7:0]    fe_data_in;
  input          fe_wr;
  input          fe_start; 
  input          fe_valid;
  input          fe_fail;

// -----------------------------------------------------------       
//                  Registers & Wires
// -----------------------------------------------------------  

  reg    [3:0]   cai_config;   
  reg    [2:0]   tso_control;
  reg    [1:0]   tso_out_cfg;
  reg            cai_enable_sample;
  reg    [11:0]  tsclk_period;   

  reg    [6:0]   c_bus_sel_sample;   
  reg 	         c_tso_rdy;

  reg    [5:0]   tso_ram_wr_addr;                                                // Extended to from 4-bit to 6-bit width.
  reg    [5:0]   tso_ram_rd_addr;
  reg    [5:0]   tso_fullness; 
  reg		 tso_ram_rd_sample;

  reg    	 tsd_tsclkout;   
  reg   	 tso_start;

  reg    [11:0]  tsclkout_counter;                                                   // Extended to from 5-bit to 12-bit width.
  reg    	 tsd_tsclkout_sample;   
  reg            tso_pclk_sample;
  reg		 tsdataout32_valid;
  wire   [31:0]  tso_ram_d_in;

  reg    [1:0]   tsdataout_select;
  reg    	 tso_valid;
  reg    	 tso_valid_d;
  reg    [7:0]   tso_data;
  reg    [7:0]   tso_data_d;

  reg    [6:0]   c_bus_sel;   
  reg    [31:0]  c_tso_obus;
  reg           request_start;
  
  reg           tso_serial;
  reg           tso_serial_d1;  
  reg           tso_serial_d2;  
  reg           tso_serial_d3;  
  reg           tso_serial_d4;  
  reg           tso_serial_d5;  
  reg           tso_serial_d6;            
  reg           tso_serial_d7;              
  reg    [2:0]  serial_sel;

  wire          cai_enable_rise;

  wire	        tso_ram_wr;

  wire   [5:0]  pre_tso_ram_addr;
  wire   [5:0]  tso_ram_addr_inc;
  wire   [5:0]  tso_fullness_incdec;

  wire   [11:0] tsclkout_counter_dec;   
  wire		tsclkout_counter_eq_one;
  wire   	tso_clk_fall;
  wire          tso_pclk_fall;

  wire	        cai_enable;
  wire   	cai_select;  
  wire [1:0]    tso_mode;
  wire 		mcu_master;
  wire 		tsi_master;
  wire 		fe_master;
  wire          ts_sync;    
  wire [7:0]    ts_data_in;  
  wire 		ffclear;
  wire          tso_in_ena;
  wire 		tsout_ena;
  wire 		tsclk_ena;
  wire 		tsclk_act;
  wire 		endian_out;
  wire          endian_in;
  wire          tsi_start_1;
  wire          tsi_start_2;
  wire          fe_start_1;
  wire          ts_start;
  wire 		tso_ena;
  wire          serial_sel_eq7;
  
  reg 		pkt_err;
  reg [8:0]	pkt_len;
  reg [25:0]	pkt_count;  
  reg [31:0]	ts_packed_data;
  reg [1:0]	pack_counter;
  reg [7:0]     tsbyte_count;
  reg           init_tso_start;  
  reg           init_tsi_start;  
     

// -----------------------------------------------------------       
//            CPU I/F - C_Bus Parameters 
// -----------------------------------------------------------  
	                                                                            		                                     						                                     
  always @(posedge clk `PS_RESET)
   if (!`A_RESET)         
            tso_control<= #1 3'b0;                                                   // TSO disabled (default).
   else if (cpu_wr && (c_add == `TSO_Control))                                       // Transport output clock disabled (default).
            tso_control   <= #1 c_bus_in[2:0];                                       // Transport data output disabled (default). 
  assign {tsout_ena,tsclk_ena,tso_ena} = tso_control; 


  always @(posedge clk `PS_RESET)                                                    // cai_config = xxx00  ==>  TSI_1 is input source.
   if (!`A_RESET) 	                                                             // cai_config = xxx01  ==>  TSI_2 is input source.
            cai_config <= #1 5'b0;                                                   // cai_config = xxx10  ==>  MCU   is input source
   else if (cpu_wr && (c_add == `TSO_In_cfg))	                                     // cai_config = xxx11  ==>  FE    is input source.
            cai_config <= #1 c_bus_in[4:0];                                          // cai_config = 1xxxx  ==>  No Input allowed.
  assign {tso_in_ena,endian_in,ffclear,cai_enable,cai_select} = cai_config;          
  assign tso_mode[1:0] = {cai_enable,cai_select};                                    // ffclear = 0  ==> Clear TSO & counters whenever any
  assign tsi_master = (tso_mode == 2'b00 || tso_mode == 2'b01);                      //                  change is made to input source.
  assign mcu_master = (tso_mode == 2'b10);                                           // Endian = 0  ==>  Big-endian packing.  
  assign fe_master  = (tso_mode == 2'b11);
										     
  always @(posedge clk `PS_RESET)
   if (!`A_RESET) 	 	cai_enable_sample <= #1 1'b0;
   else 			cai_enable_sample <= #1 cai_enable;
  assign cai_enable_rise = cai_enable && !cai_enable_sample;
    

  always @(posedge clk `PS_RESET)
   if (!`A_RESET) 	      
            tso_out_cfg  <= #1 2'b0;                                                 // Rising edge active (default).                                                            	      
   else if (cpu_wr && (c_add == `TSO_Out_cfg))	                                     // Big-endian unpacking (default).                             
            tso_out_cfg  <= #1 c_bus_in[1:0];  
  assign {endian_out,tsclk_act} = tso_out_cfg; 
  

  always @(posedge clk `PS_RESET)
   if (!`A_RESET) 	
    	    tsclk_period <= #1 `TSCLK_PERIOD;                                        // The TSO clock period is counted in sysclk periods.
   else if (cpu_wr && (c_add == `TSO_Clk_cfg))	                                     // The default value provides for a 5MHz clock with
            tsclk_period <= #1 c_bus_in[11:0];                                       // the nominal 200MHz sysclk.
						      
				
  always @(posedge clk `PS_RESET)
   if (!`A_RESET) 	pkt_err <= #1 1'b0;                                          // pkt_err asserts if a packet framing error has been
   else if (cpu_wr && (c_add == `TSO_Status))	                                     // detected (i.e. more than 188 bytes per packet).
			pkt_err <= #1 c_bus_in[0];                                   // Default - No packet framing error detected.
   else if ((tsbyte_count == `PACKET_SIZE) && !(tso_data == `SYNC_BYTE))
                        pkt_err <= #1 1'b1;
   else if ((tsbyte_count > `PACKET_SIZE)  && (tso_data == `SYNC_BYTE))
                        pkt_err <= #1 1'b0;
				                                               
  always @(posedge clk `PS_RESET)
   if (!`A_RESET) 	 	pkt_len <= #1 9'b0;
   else if (cpu_wr && (c_add == `TSO_Pkt_len))	                                     // pkt_len contains the packet-length detected for
				pkt_len <= #1 c_bus_in[8:0];                         // the last mis-framed packet (max=511).
   else if (pkt_err && tso_start && (tso_data == `SYNC_BYTE))
                                pkt_len <= #1 (tsbyte_count < 9'd511) ? tsbyte_count : 9'd511;
				
  always @(posedge clk `PS_RESET)
   if (!`A_RESET) 	        pkt_count <= #1 26'b0;                               
   else if (cpu_wr && (c_add == `TSO_Pkt_count))   
                                pkt_count <= #1 c_bus_in[25:0];                      // Packets before mis-frame. 
   else if (!pkt_err && tso_start && tso_pclk_fall) 
                                pkt_count <= #1 pkt_count + 1'b1;
				


 // C_Bus Read.                                                                      // Old I58 CAI-TSD interface has been disabled
  always @(c_add)
   casez(c_add)	// synopsys parallel_case       
    `TSO_Control        : c_bus_sel = 7'b0000001;                                    // c_bus_sel extended from 2-bit to 7-bit.
    `TSO_In_cfg         : c_bus_sel = 7'b0000010;        
    `TSO_Out_cfg        : c_bus_sel = 7'b0000100;        
    `TSO_Clk_cfg        : c_bus_sel = 7'b0001000;        
    `TSO_Status         : c_bus_sel = 7'b0010000;        
    `TSO_Pkt_len        : c_bus_sel = 7'b0100000;        
    `TSO_Pkt_count      : c_bus_sel = 7'b1000000;        
    default   	     : c_bus_sel = 7'b0000000;
   endcase

  always @(posedge clk `PS_RESET)
   if (!`A_RESET) 	c_bus_sel_sample <= #1 7'b0;
   else if (cpu_rd)	c_bus_sel_sample <= #1 c_bus_sel;

  always @(tso_control or tso_out_cfg or pkt_err or pkt_len or
           pkt_count or c_bus_sel_sample or cai_config or tsclk_period) 
   casez(1'b1)		// synopsys parallel_case
    c_bus_sel_sample[0] : c_tso_obus = {28'b0, tso_control[2:0]};                     // Case statement was extended to 7 cases.
    c_bus_sel_sample[1] : c_tso_obus = {20'b0, cai_config[3:0]};
    c_bus_sel_sample[2] : c_tso_obus = {29'b0, tso_out_cfg[1:0]};
    c_bus_sel_sample[3] : c_tso_obus = {30'b0, tsclk_period[11:0]};
    c_bus_sel_sample[4] : c_tso_obus = {31'b0, pkt_err};
    c_bus_sel_sample[5] : c_tso_obus = {23'b0, pkt_len[8:0]};
    c_bus_sel_sample[6] : c_tso_obus = {6'b0, pkt_count[25:0]};
    default  		: c_tso_obus = 32'b0;
   endcase

  always @(posedge clk `PS_RESET)
   if (!`A_RESET) 	c_tso_rdy <= #1 1'b0;
   else 		c_tso_rdy <= #1 cpu_rd && (|c_bus_sel);
   

// -----------------------------------------------------------       
//                Buffer Ram Handling Logic
// -----------------------------------------------------------  

// tso_ram_rd
  always @(posedge clk `PS_RESET)
   if (!`A_RESET)               	            init_tsi_start <= #1 1'b0;
   else if (tsi1_start || tsi2_start || fe_start)   init_tsi_start <= #1 1'b1;             // waking up after Reset.
   
  assign tso_ram_wr = ((mcu_master && mcu_wr)  ||
                       (!mcu_master && pack_counter==2'b11 && init_tsi_start)) &&
		       !(tso_mcu_avail == 6'd0);

  always @(posedge clk `PS_RESET)
   if (!`A_RESET)               tsdataout32_valid <= #1 1'b0;  
   else if (tso_ram_rd_sample)	tsdataout32_valid <= #1 1'b1;
   else if (tso_pclk_fall && (tsdataout_select == 2'b11))	
				tsdataout32_valid <= #1 1'b0;
					
  always @(posedge clk `PS_RESET)
   if (!`A_RESET) 	        tso_ram_rd_sample <= #1 1'b0;
   else 		        tso_ram_rd_sample <= #1 tso_ram_rd;
   
  assign tso_ram_rd = !tso_ram_wr &&                                                 
		      !(tso_fullness == 6'b0) &&                                     
		      !tsdataout32_valid && 
		      !tso_ram_rd_sample;
                                                                                        

// tso_ram addr
  always @(posedge clk `PS_RESET)
   if (!`A_RESET) 	 tso_ram_wr_addr <= #1 6'b0;                      
   else if (ffclear || (tso_ram_wr_addr == `TSO_RAM_SIZE))
                      	 tso_ram_wr_addr <= #1 6'b0;
   else if (tso_ram_wr)	 tso_ram_wr_addr <= #1 tso_ram_addr_inc; 

  always @(posedge clk `PS_RESET)
   if (!`A_RESET) 	 tso_ram_rd_addr <= #1 6'b0;                      
   else if (ffclear || (tso_ram_rd_addr == `TSO_RAM_SIZE))
                    	 tso_ram_rd_addr <= #1 6'b0;
   else if (tso_ram_rd)  tso_ram_rd_addr <= #1 tso_ram_addr_inc;	

  assign pre_tso_ram_addr = tso_ram_wr ? tso_ram_wr_addr : tso_ram_rd_addr;
  assign tso_ram_addr_inc = pre_tso_ram_addr + 1'b1;		            
  assign tso_ram_addr = pre_tso_ram_addr; 
  

// tso_mcu_avail - Availaility status to MCU
  always @(posedge clk `PS_RESET)
   if (!`A_RESET) 	  	tso_fullness <= #1 6'b0;
   else if (ffclear)            tso_fullness <= #1 6'b0;
   else if ((tso_fullness < `TSO_RAM_SIZE) && (tso_ram_wr || tso_ram_rd)) 
				tso_fullness <= #1 tso_fullness_incdec;
  assign tso_fullness_incdec = tso_ram_wr ? tso_fullness + 1'b1 : tso_fullness - 1'b1;
  assign tso_mcu_avail = {2'b0,(`TSO_RAM_SIZE-6'd1)-tso_fullness[5:0]};                // Available space left in buffer ram (8-bit required).


// tso_ram_cs
  assign tso_ram_cs   = !(!tso_in_ena && (tso_ram_rd || tso_ram_wr));


// tso_ram_d_in   
  assign tso_ram_d_in = mcu_master ? mcu_d_bus_in : ts_packed_data;                    // MCU/TSI mux 2:1 for buffer ram data-in source.


// -----------------------------------------------------------       
//                Byte Packing Logic
// -----------------------------------------------------------  
// TS data is chosen over TSI1, TSI2 or FE and packed from 8-bit to 32-bit size.

 assign fe_err      = !fe_valid || fe_fail;
 
 assign tsi_start_1 = tsi1_wr && tsi1_start && !tsi1_err;
 assign tsi_start_2 = tsi2_wr && tsi2_start && !tsi2_err;
 assign fe_start_1  = fe_wr   && fe_start   && !fe_err ;

 assign ts_data_in  = tsi_master ? (tso_mode[0] ? tsi2_data_in : tsi1_data_in)
                                 :  fe_data_in;
				 
 assign ts_start  = tsi_master ? (tso_mode[0] ? tsi_start_2 : tsi_start_1)
                                 :  fe_start_1;				 

 assign ts_sync = ts_start && (ts_data_in==`SYNC_BYTE); 

 always @(posedge clk `PS_RESET)
   if (!`A_RESET) 	        ts_packed_data <= #1 32'b0;
   else if (!mcu_master && (tsi1_wr || tsi2_wr || fe_wr)) 
                                ts_packed_data <= #1 endian_in ? {ts_data_in[7:0],ts_packed_data[31:8]}  // Little-endian pack
				                               : {ts_packed_data[23:0],ts_data_in[7:0]};  // Big-endian pack

 always @(posedge clk `PS_RESET)
   if (!`A_RESET) 		   pack_counter <= #1 2'b0;
   else if  (pack_counter==2'b11 || ts_sync)  
                                   pack_counter <= #1 2'b0;
   else if (tsi_master && ((tso_mode[0] && tsi2_wr) || (!tso_mode[0] && tsi1_wr)) || (fe_master && fe_wr))
                                   pack_counter <= #1 pack_counter + 2'b01;
	   

//--------------------------------------------------------------------------------
//                  Transport Clock Generator
//--------------------------------------------------------------------------------

  always @(posedge clk `PS_RESET)
   if (!`A_RESET) 	tsclkout_counter <= #1 {1'b0,`TSCLK_PERIOD/2};
   else if (tsclkout_counter_eq_one)	
			tsclkout_counter <= #1 {1'b0,tsclk_period[11:1]};
   else 		tsclkout_counter <= #1 tsclkout_counter_dec;

  assign tsclkout_counter_dec = tsclkout_counter - 1'b1;

  assign tsclkout_counter_eq_one = (tsclkout_counter == 12'b1);

  always @(posedge clk `PS_RESET)        					     
   if (!`A_RESET) 	tsd_tsclkout <= #1 1'b1;
   else if (tsclkout_counter_eq_one && tsclk_ena && tso_ena)
			tsd_tsclkout <= #1 !tsd_tsclkout;                            
                                                                                     // New clock polarity support.
  assign tso_clk_int = tsclk_act ? !tsd_tsclkout : tsd_tsclkout;

// -----------------------------------------------------------
//                  Formatter
// -----------------------------------------------------------  

// TSO_START 
// the TSOSTART signal should be asserted with the same timing as TSODATA [7:0], 
// at the first byte of each packet when sync-byte is output (every 188 valid output bytes).

  always @(posedge clk `PS_RESET)
   if (!`A_RESET) 	init_tso_start <= #1 1'b0;
   else if (ffclear)    init_tso_start <= #1 1'b0;
   else if (tso_start)	init_tso_start <= #1 1'b1;                                       // waking up after Reset or Turn-Over.

  always @(posedge clk `PS_RESET)
   if (!`A_RESET) 	tsd_tsclkout_sample <= #1 1'b0;
   else 		tsd_tsclkout_sample <= #1 tsd_tsclkout;
  assign tso_clk_fall = !tsd_tsclkout && tsd_tsclkout_sample;

  always @(posedge clk `PS_RESET)
   if (!`A_RESET) 	request_start <= #1 1'b0;
   else if (ffclear || (tso_mcu_avail > 8'd1))   
                        request_start <= #1 1'b1;
   else if (tso_valid)  request_start <= #1 1'b0;

  always @(posedge clk `PS_RESET)
   if      (!`A_RESET) 	tsbyte_count <= #1 8'b0;                                     // New counter.
   else if (!tso_ena || (tso_pclk_fall && tso_valid && tso_start))
   			tsbyte_count <= #1 8'b0;
   else if (tso_pclk_fall && tso_valid)
                        tsbyte_count <= #1 tsbyte_count + 8'b1;
                             
  always @(posedge clk `PS_RESET)
   if (!`A_RESET) 	      tso_start <= #1 1'b0;
   else if (tso_pclk_fall)    tso_start <= #1 (tso_valid_d &&             // tso_valid_d &&  <==>  request_start && tsdataout32_valid &&					       
				              ( (tso_data_d==`SYNC_BYTE) && 
					      (!init_tso_start || (tsbyte_count >= `PACKET_SIZE-1)) ));      // New condition
		     						     
												
// TSO_VALID. 
// Valid for 4 tsd_tsclkout cycles after rising of tsdataout32_valid.                
// TSOVALID should be set to '0' upon reset, TSO disable, FIFO clear or while TSO data output is disabled.
// TSOVALID should be set to '1' while the FIFO isn't empty (and output is sent out).								                    

  always @(posedge clk `PS_RESET)                                                    
   if (!`A_RESET)            tso_valid_d <= #1 1'b0;                           
   else if (tso_pclk_fall)   tso_valid_d <= #1 tsdataout32_valid;
   
  always @(posedge clk `PS_RESET)                                                    
   if (!`A_RESET)            tso_valid <= #1 1'b0;                           
   else if (tso_pclk_fall)   tso_valid <= #1 tso_valid_d;
   
 

// TSO_DATA 
// Select 8-bit from tso_ram_d_in according to tsdataout_select,
// changed only @negedge of tsd_tsclkout.

  // TSO_PARALLEL
  always @(posedge clk `PS_RESET)
   if (!`A_RESET) 		tsdataout_select <= #1 2'b0;
   else if (tso_pclk_fall && tsdataout32_valid)  
				tsdataout_select <= #1 tsdataout_select + 1'b1;

  always @(posedge clk `PS_RESET)
   if (!`A_RESET)		tso_data_d <= #1 8'b0;            
   else if (tso_ena && tsout_ena && tso_pclk_fall)	                             // Reset conditions added.
    casez(endian_out ? ~(tsdataout_select) : tsdataout_select)                       // Big/Little endian support added.
    2'b00 : 			tso_data_d <= #1 tso_ram_d_out[31:24];
    2'b01 : 			tso_data_d <= #1 tso_ram_d_out[23:16];              
    2'b10 : 			tso_data_d <= #1 tso_ram_d_out[15:8];
    2'b11 : 			tso_data_d <= #1 tso_ram_d_out[7:0];
   endcase
   
  always @(posedge clk `PS_RESET)                                                    
   if (!`A_RESET)           tso_data <= #1 1'b0;                           
   else if (tso_pclk_fall)  tso_data <= #1 tso_data_d; 

  assign tso_pclk = serial_sel[2];                                                   // Parallel clock.

  always @(posedge clk `PS_RESET)
   if (!`A_RESET) 	tso_pclk_sample <= #1 1'b0;
   else 		tso_pclk_sample <= #1 tso_pclk;
  assign tso_pclk_fall = !tso_pclk && tso_pclk_sample;  
   

  // TSO_SERIAL
  always @(posedge clk `PS_RESET)                                                    
   if (!`A_RESET)              serial_sel <= #1 3'b0;                           
   else if (serial_sel_eq7 && tso_clk_fall)    
                               serial_sel <= #1 3'b0; 
   else if (tso_ena && tsout_ena && tso_clk_fall)
                               serial_sel <= #1 serial_sel + 3'b001; 
  
  assign serial_sel_eq7 = (serial_sel == 3'b111);
        
  always @(posedge clk `PS_RESET)
   if (!`A_RESET)		tso_serial_d1 <= #1 8'b0;            
   else if (tso_ena && tsout_ena && tso_clk_fall)	        	             // Reset conditions added.
    casez(endian_out ? ~(serial_sel) : serial_sel)                                   // Big/Little endian support added.
    3'b000 : 			tso_serial_d1 <= #1 tso_data_d[7];
    3'b001 : 			tso_serial_d1 <= #1 tso_data_d[6];              
    3'b010 : 			tso_serial_d1 <= #1 tso_data_d[5];
    3'b011 : 			tso_serial_d1 <= #1 tso_data_d[4];
    3'b100 : 			tso_serial_d1 <= #1 tso_data_d[3];
    3'b101 : 			tso_serial_d1 <= #1 tso_data_d[2];              
    3'b110 : 			tso_serial_d1 <= #1 tso_data_d[1];
    3'b111 : 			tso_serial_d1 <= #1 tso_data_d[0];    
   endcase   

  always @(posedge clk `PS_RESET)  	        	                            // Required for synchronization.                                                  
   if (!`A_RESET)           tso_serial_d2 <= #1 1'b0;                           
   else if (tso_clk_fall)   tso_serial_d2 <= #1 tso_serial_d1; 
  always @(posedge clk `PS_RESET)                                                    
   if (!`A_RESET)           tso_serial_d3 <= #1 1'b0;                           
   else if (tso_clk_fall)   tso_serial_d3 <= #1 tso_serial_d2; 
  always @(posedge clk `PS_RESET)                                                    
   if (!`A_RESET)           tso_serial_d4 <= #1 1'b0;                           
   else if (tso_clk_fall)   tso_serial_d4 <= #1 tso_serial_d3; 
  always @(posedge clk `PS_RESET)                                                    
   if (!`A_RESET)           tso_serial_d5 <= #1 1'b0;                           
   else if (tso_clk_fall)   tso_serial_d5 <= #1 tso_serial_d4; 
  always @(posedge clk `PS_RESET)                                                    
   if (!`A_RESET)           tso_serial_d6 <= #1 1'b0;                           
   else if (tso_clk_fall)   tso_serial_d6 <= #1 tso_serial_d5;             
  always @(posedge clk `PS_RESET)                                                    
   if (!`A_RESET)           tso_serial_d7 <= #1 1'b0;                           
   else if (tso_clk_fall)   tso_serial_d7 <= #1 tso_serial_d6;             
  always @(posedge clk `PS_RESET)                                                    
   if (!`A_RESET)           tso_serial <= #1 1'b0;                           
   else if (tso_clk_fall)   tso_serial <= #1 tso_serial_d7; 
 
   
 endmodule
