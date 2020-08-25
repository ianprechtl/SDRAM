`ifndef _SDRAM_V_
`define _SDRAM_V_

module sdram #(
	parameter UI_BW_ADDR 			= 0, 				// addr bus size from system to sdram module (in case conversion is needed)
	parameter UI_BW_DATA_BUS 		= 0, 				// data bus size from system to sdram module (in case conversion is needed)
	parameter SDRAM_BW_ADDR 		= 0,
	parameter SDRAM_BW_DATA_BUS 	= 0, 
	parameter SDRAM_BW_BURST_LENGTH = 0
)(
	// general ports
	input 							clock_i,
	input 							resetn_i, 
	// user-interface/system ports
	input 							req_i,
	input 							req_block_i,
	input 							rw_i,
	input 		[UI_BW_ADDR-1:0] 	addr_i, 			// hword addressible (external memory controller handles this)
	input 		[UI_BW_DATA_BUS-1:0]data_i,
	input 							clear_i,
	output 		 					done_o, 
	output 	 						ready_o, 
	output 	 						valid_o,
	output 	 	[UI_BW_DATA_BUS-1:0]data_o,
	// SDRAM pins
	output 							DRAM_CLK,
									DRAM_CKE,			// clock enable
									DRAM_CS_N,			// chip select
									DRAM_RAS_N,			// row address strobe
									DRAM_CAS_N,			// column address strobe
									DRAM_WE_N,			// write enable
	output 		[1:0]				DRAM_BA,			// bank select
	output 		[12:0]				DRAM_ADDR,			// row/column address
	inout 		[15:0]				DRAM_DQ,			// data to/from SDRAM
	output 							DRAM_UDQM, 			// upper byte enable
									DRAM_LDQM			// lower byte enable
);

// buffers/protocol converters
// --------------------------------------------------------------------------------
wire 								sdram_request_i_flag;
wire 								sdram_command_i_flag;
wire [SDRAM_BW_BURST_LENGTH-1:0] 	sdram_length_i_bus;
wire [SDRAM_BW_ADDR-1:0] 			sdram_address_i_bus;
wire [SDRAM_BW_DATA_BUS-1:0] 		sdram_data_i_bus;

wire 								sdram_ready_o_flag;
wire 								sdram_done_o_flag;
wire [SDRAM_BW_DATA_BUS-1:0] 		sdram_data_o_bus;

sdram_protocol_interface #(
	.UI_BW_ADDR 		(UI_BW_ADDR 			),
	.UI_BW_DATA_BUS 	(UI_BW_DATA_BUS 		),
	.BW_BURST_LENGTH 	(SDRAM_BW_BURST_LENGTH 	),
	.BW_ADDR 			(SDRAM_BW_ADDR 			),
	.BW_DATA_BLOCK 		(SDRAM_BW_DATA_BUS 		)
) sdram_protocol_interface (
	// general
	.clock_i 			(clock_i 				),
	.resetn_i 			(resetn_i 				),
	// custom
	.req_i				(req_i 					),
	.req_block_i		(req_block_i 			),
	.rw_i				(rw_i 					),
	.addr_i				(addr_i 				),
	.data_i				(data_i 				),
	.clear_i			(clear_i 				),
	.done_o				(done_o 				),
	.ready_o			(ready_o 				),
	.valid_o			(valid_o 				),
	.data_o				(data_o 				),
	// sdram 
	.sdram_request_o	(sdram_request_i_flag 	),
	.sdram_command_o	(sdram_command_i_flag 	),
	.sdram_length_o		(sdram_length_i_bus 	),
	.sdram_address_o	(sdram_address_i_bus 	),
	.sdram_data_o		(sdram_data_i_bus 		),
	.sdram_ready_i		(sdram_ready_o_flag 	),
	.sdram_done_i		(sdram_done_o_flag 		),
	.sdram_data_i		(sdram_data_o_bus 		)
);


// sdram controller
// --------------------------------------------------------------------------------

sdram_controller #(
	.BW_BURST_LENGTH 	(SDRAM_BW_BURST_LENGTH 	),
	.BW_ADDR 			(SDRAM_BW_ADDR 			),
	.BW_DATA_BLOCK 		(SDRAM_BW_DATA_BUS 		)
) sdram_controller_inst (
	// general ports
	.clock_i			(clock_i				),
	.resetn_i			(resetn_i				),
	// request ports
	.request_i			(sdram_request_i_flag 	), 			// 0: no request, 1: request
	.command_i			(sdram_command_i_flag 	), 			// 0: read, 1: write
	.length_i			(sdram_length_i_bus 	), 			// length of the request in 32-bit increments (4'b0000 is 1 txrx, 4'b1111 is 16 txrx) 
	.address_i			(sdram_address_i_bus 	), 			// 
	.data_i				(sdram_data_i_bus 		),
	.ready_o			(sdram_ready_o_flag 	), 			// 0: unable to service request, 1: ready for request
	// service ports		 	
	.done_o				(sdram_done_o_flag 		),
	.data_o				(sdram_data_o_bus 		),

	// sdram hardware pin ports
	.DRAM_CLK			(DRAM_CLK				),
	.DRAM_CKE			(DRAM_CKE				),			// clock enable
	.DRAM_CS_N			(DRAM_CS_N				),			// chip select
	.DRAM_RAS_N			(DRAM_RAS_N				),			// row address strobe
	.DRAM_CAS_N			(DRAM_CAS_N				),			// column address strobe
	.DRAM_WE_N			(DRAM_WE_N				),			// write enable
	.DRAM_BA			(DRAM_BA				),			// bank select
	.DRAM_ADDR			(DRAM_ADDR				),			// row/column address
	.DRAM_DQ			(DRAM_DQ				),			// data to/from SDRAM
	.DRAM_UDQM			(DRAM_UDQM				), 			// upper byte enable
	.DRAM_LDQM			(DRAM_LDQM				)			// lower byte enable
);

endmodule

`endif