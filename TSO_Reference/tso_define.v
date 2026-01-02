/* ident "@(#)tso_define.v:/dtv/i68/project/design/hdl/ifu/tso/SCCS/s.tso_define.v 1.14 04/06/03" */
/**************************************************************************/
/*                                                                        */
/*    Copyright (c) 1998 ZORAN Corporation, All Rights Reserved           */
/*    THIS IS UNPUBLISHED PROPRIETARY SOURCE CODE OF ZORAN CORPORATION    */
/*                                                                        */
/*
 *    File : SCCS/s.tso_define.v
 *    Type : Verilog File
 *    Module : tso_define.v
 *    Sccs Identification (SID) : 1.14
 *    Modification Time : 04/06/03 14:17:02
 *                                                                        */
/*                                                                        */
/**************************************************************************/

// tso Registers address.
`define TSO_Control   13'h0970
`define TSO_In_cfg    13'h0971
`define TSO_Out_cfg   13'h0972
`define TSO_Clk_cfg   13'h0973
`define TSO_Status    13'h0974
`define TSO_Pkt_len   13'h0975
`define TSO_Pkt_count 13'h0976


// Transport Clock Generator
`define TSCLK_PERIOD  12'd40


// TSO Packet Size.
`define PACKET_SIZE 8'd187

// TSO Buffer FIFO ram
`define TSO_RAM_SIZE 6'd48


// tso Synchronizing Byte.
// `define SYNC_BYTE   8'h47         //  moved to i88_define
