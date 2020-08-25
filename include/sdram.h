`ifndef _SDRAM_H_
`define _SDRAM_H_

// custom frontend configurations
`define SDRAM_MAX_BURST_LENGTH 		16 				// number of blocks 				
`define SDRAM_BW_BURST_LENGTH 		5
`define SDRAM_BW_DATA_WORD 			32
`define SDRAM_N_WORDS_PER_BLOCK 	16
`define SDRAM_BW_DATA_BLOCK 		`SDRAM_BW_DATA_WORD*`SDRAM_N_WORDS_PER_BLOCK


// ISSI SDRAM configurations
`define SDRAM_BW_DELAY_REG 			10
`define SDRAM_INIT_DELAY 			10'h3FF 		// @20MHz -> init delay is ~50,000 ns
`define SDRAM_REFRESH_COUNT 		200 			// cell refresh rate - need to check chip spec sheet if changing from 20MHZ clock
`define SDRAM_BW_REFRESH_COUNT 		4 				// refresh controller can accumulate up to 16 refreshes before error
`define SDRAM_MODE_ONE_BURST		13'h0021 		// mode configuration - burst length of 2 (transmit 2 packets per txrx)
`define SDRAM_BW_ADDR 				25 				// 64MB of 16-bit addressible memory				


// ISSI SDRAM command codes
`define SDRAM_CMD_ACTIVATE 			4'b0011
`define SDRAM_CMD_PRECHARGE 		4'b0010
`define SDRAM_CMD_WRITE 			4'b0100
`define SDRAM_CMD_READ				4'b0101
`define SDRAM_CMD_MODE 				4'b0000
`define SDRAM_CMD_NOP 				4'b0111
`define SDRAM_CMD_REFRESH 			4'b0001


// source files
`include "../src/sdram.v"
`include "../src/sdram_controller.v"
`include "../src/sdram_refresh_controller.v"
`include "../src/sdram_protocol_interface.v"

`endif