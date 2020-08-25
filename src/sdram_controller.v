`ifndef _SDRAM_CONTROLLER_V_
`define _SDRAM_CONTROLLER_V_

module sdram_controller #(
	parameter BW_BURST_LENGTH 	= 0,
	parameter BW_ADDR 			= 0,
	parameter BW_DATA_BLOCK 	= 0
)(
	// general ports
	input 							clock_i,
	input 							resetn_i,
	// request ports
	input 							request_i, 			// 0: no request, 1: request
	input 							command_i, 			// 0: read, 1: write
	input 	[BW_BURST_LENGTH-1:0]	length_i, 			// length of the request in 32-bit increments (4'b0000 is 1 txrx, 4'b1111 is 16 txrx) 
	input 	[BW_ADDR-1:0] 			address_i, 			// 
	input 	[BW_DATA_BLOCK-1:0] 	data_i,
	output 							ready_o, 			// 0: unable to service request, 1: ready for request
	// service ports
	output 	[BW_DATA_BLOCK-1:0]		data_o,
	output 							done_o,  			// 1: valid output, register data_o			 	
	// sdram hardware pin ports
	output 							DRAM_CLK,
									DRAM_CKE,			// clock enable
									DRAM_CS_N,			// chip select
									DRAM_RAS_N,			// row address strobe
									DRAM_CAS_N,			// column address strobe
									DRAM_WE_N,			// write enable
	output 	[1:0]					DRAM_BA,			// bank select
	output 	[12:0]					DRAM_ADDR,			// row/column address
	inout 	[15:0]					DRAM_DQ,			// data to/from SDRAM
	output 							DRAM_UDQM, 			// upper byte enable
									DRAM_LDQM			// lower byte enable
);

// SDRAM pin mappings
// ----------------------------------------------------------------------------------------------------
reg 			sdram_cke_reg;
reg 	[1:0]	sdram_bank_reg;
reg 	[12:0]	sdram_addr_reg;
reg 	[3:0]	sdram_command_reg;
reg 			sdram_data_dir_reg;
reg 			sdram_udqm_reg, 
				sdram_ldqm_reg;
reg 	[15:0]	sdram_data_reg; 				// transact HW at SDRAM interface

assign DRAM_CLK 	= clock_i;
assign DRAM_CKE 	= sdram_cke_reg;
assign DRAM_CS_N 	= sdram_command_reg[3];
assign DRAM_RAS_N 	= sdram_command_reg[2];
assign DRAM_CAS_N 	= sdram_command_reg[1];
assign DRAM_WE_N 	= sdram_command_reg[0];
assign DRAM_BA 		= sdram_bank_reg;
assign DRAM_ADDR 	= sdram_addr_reg;
assign DRAM_UDQM 	= sdram_udqm_reg;
assign DRAM_LDQM 	= sdram_ldqm_reg;
assign DRAM_DQ 		= (sdram_data_dir_reg == 1'b1) ? sdram_data_reg : 16'bz; 


// refresh controller
// ----------------------------------------------------------------------------------------------------
reg 		status_reg; 	 					// 1: initialized				
reg 		refresh_reg; 						// 1: decrement refresh counter
wire 		refresh_flag; 						// 1: refresh needed

sdram_refresh_controller #(
	.N_CYCLES 	(`SDRAM_REFRESH_COUNT	), 		// max number of cycles between refreshes issued
	.BW_CYCLES 	(`SDRAM_BW_REFRESH_COUNT), 		
	.BW_DEPTH 	(8						) 		// how many refreshes can accumulate (ideally should not be necessary)
) sdram_refresh_controller_inst (
	// general ports
	.clock_i 	(clock_i 				),
	.resetn_i	(resetn_i 				),
	.status_i 	(status_reg 			), 		// 0: sdram not initialized, 1: sdram initialized
	.execute_i 	(refresh_reg 			), 		// 1: refresh being executed 
	.refresh_o 	(refresh_flag 			) 		// 0: no refresh necessary, 1: refresh necessary
); 


// controller state machine
// ----------------------------------------------------------------------------------------------------
localparam SD_INIT 				= 5'b00000;
localparam SD_INIT_PRECHARGE 	= 5'b00001;
localparam SD_INIT_REFRESH0		= 5'b00010;
localparam SD_INIT_REFRESH1 	= 5'b00011;
localparam SD_INIT_LOAD 		= 5'b00100;
localparam SD_INIT_DONE 		= 5'b00101;
localparam SD_IDLE 				= 5'b00110;
localparam SD_ACTIVATE			= 5'b00111;
localparam SD_REFRESH0 			= 5'b01000;
localparam SD_REFRESH1 			= 5'b01001;
localparam SD_RW_COMMAND 		= 5'b01010;
localparam SD_READ 				= 5'b01011;
localparam SD_PRECHARGE 		= 5'b01100;
localparam SD_DONE 				= 5'b01101;
localparam SD_READ2 			= 5'b01110;
localparam SD_WRITE 			= 5'b01111;
localparam SD_READ2_BUFF 		= 5'b10000;
localparam SD_READ_PRE			= 5'b10001;

// sequencing signals
reg 	[4:0] 						state_reg;
reg 	[`SDRAM_BW_DELAY_REG-1:0] 	delay_counter_reg;
reg 	[BW_BURST_LENGTH-1:0]  		n_counter_reg;

// port assignments
reg 	[BW_DATA_BLOCK-1:0] 		data_o_reg;
reg 								done_reg;
reg 								ready_reg;

assign done_o 	= done_reg;
assign ready_o 	= ready_reg;
assign data_o 	= data_o_reg;

// buffer signals
reg 						buffer_request_reg;
reg 						buffer_command_reg;
reg [BW_BURST_LENGTH-1:0] 	buffer_length_reg;
reg [BW_ADDR-1:0] 			buffer_address_reg;
reg [BW_DATA_BLOCK-1:0] 	buffer_data_reg;
reg 						word_flag_reg;

// controller logic
always @(posedge clock_i) begin

	// reset state
	// ------------------------------------------------------------------
	if (!resetn_i) begin

		// SDRAM pin signals
		sdram_cke_reg 		<= 1'b1;
		sdram_command_reg 	<= `SDRAM_CMD_NOP;
		sdram_bank_reg 		<= 'b00;
		sdram_addr_reg 		<= 'b0;	
		sdram_udqm_reg 		<= 1'b0;
		sdram_ldqm_reg 		<= 1'b0;
		sdram_data_dir_reg 	<= 1'b0;

		// sequencing signals
		state_reg 			<= SD_INIT;
		status_reg 			<= 1'b0;
		refresh_reg 		<= 1'b0;
		delay_counter_reg 	<= 'b0;
		word_flag_reg 		<= 1'b0;
		n_counter_reg 		<= 'b0;

		// buffer signals
		buffer_request_reg 	<= 1'b0;
		buffer_command_reg 	<= 1'b0;
		buffer_length_reg 	<= 'b0;
		buffer_address_reg 	<= 'b0;
		buffer_data_reg 	<= 'b0;

		// request/service signals
		ready_reg 			<= 1'b0;
		done_reg 			<= 1'b0;
		data_o_reg 			<= 'b0;
		
	end
	// active sequencing states
	// ------------------------------------------------------------------
	else begin

		// command/data buffer incase the controller is completing a refresh when the request is made
		// adds a cycle of latency
		if (request_i & ready_reg) begin
			ready_reg 			<= 1'b0;
			buffer_request_reg 	<= 1'b1;
			buffer_command_reg 	<= command_i;
			buffer_length_reg 	<= length_i;
			buffer_address_reg 	<= address_i;
			buffer_data_reg 	<= data_i;
		end

		// default signals
		sdram_command_reg 		<= `SDRAM_CMD_NOP;
		refresh_reg  			<= 1'b0;
		done_reg 				<= 1'b0;

		// sequencing
		if (delay_counter_reg) delay_counter_reg <= delay_counter_reg - 1'b1;
		else begin
			case(state_reg)

				// initialization states
				// -------------------------------------------------------
				SD_INIT: begin
					state_reg 				<= SD_INIT_PRECHARGE;
					sdram_command_reg 		<= `SDRAM_CMD_NOP;
					delay_counter_reg 		<= `SDRAM_INIT_DELAY;
				end
				SD_INIT_PRECHARGE: begin
					state_reg 				<= SD_INIT_REFRESH0;
					sdram_command_reg 		<= `SDRAM_CMD_PRECHARGE;
					sdram_addr_reg[10] 		<= 1'b1;
					sdram_bank_reg 			<= 2'b00;
					delay_counter_reg 		<= 1'b1;
				end
				SD_INIT_REFRESH0: begin
					state_reg 				<= SD_INIT_REFRESH1;
					sdram_command_reg 		<= `SDRAM_CMD_REFRESH;
					delay_counter_reg 		<= 3'b111;
				end
				SD_INIT_REFRESH1: begin
					state_reg 				<= SD_INIT_LOAD;
					sdram_command_reg 		<= `SDRAM_CMD_REFRESH;
					delay_counter_reg 		<= 3'b111;
				end
				SD_INIT_LOAD: begin
					state_reg 				<= SD_INIT_DONE;
					sdram_command_reg 		<= `SDRAM_CMD_MODE;
					sdram_addr_reg 			<= `SDRAM_MODE_ONE_BURST;
					sdram_bank_reg 			<= 2'b00;
				end
				SD_INIT_DONE: begin
					state_reg 				<= SD_IDLE;
					sdram_command_reg 		<= `SDRAM_CMD_NOP;
					status_reg 				<= 1'b1;
					ready_reg 				<= 1'b1;
				end

				// request-service states
				// -------------------------------------------------------
				SD_IDLE: begin
					// refresh needs to be executed
					if (refresh_flag) begin
						refresh_reg 		<= 1'b1;
						state_reg 			<= SD_REFRESH0;
						sdram_command_reg 	<= `SDRAM_CMD_PRECHARGE;
						sdram_bank_reg 		<= 2'b00;
						sdram_addr_reg[10] 	<= 1'b1;
						delay_counter_reg 	<= 1'b1;
					end
					// no refresh so service any buffered request
					else begin
						if (buffer_request_reg) begin
							buffer_request_reg 	<= 1'b0;
							state_reg 			<= SD_RW_COMMAND;
							sdram_command_reg 	<= `SDRAM_CMD_ACTIVATE;
							sdram_bank_reg 		<= buffer_address_reg[24:23];
							sdram_addr_reg 		<= buffer_address_reg[22:10];
							sdram_data_dir_reg 	<= buffer_command_reg;
							n_counter_reg 		<= 'b0;
						end
					end
				end
				SD_REFRESH0: begin
					state_reg 			<= SD_REFRESH1;
					sdram_command_reg 	<= `SDRAM_CMD_REFRESH;
					delay_counter_reg 	<= 3'b111;
				end
				SD_REFRESH1: begin
					state_reg 			<= SD_IDLE;
					sdram_command_reg 	<= `SDRAM_CMD_REFRESH;
					delay_counter_reg 	<= 3'b111;
				end
				SD_RW_COMMAND: begin
					// read 
					if (!buffer_command_reg) begin
						state_reg 			<= SD_READ_PRE;
						sdram_command_reg 	<= `SDRAM_CMD_READ;
						sdram_bank_reg 		<= buffer_address_reg[24:23];
						sdram_addr_reg 		<= {3'b000, buffer_address_reg[9:0]};
						delay_counter_reg 	<= 1'b1;
					end
					// write
					else begin
						state_reg 			<= SD_WRITE;
						sdram_command_reg 	<= `SDRAM_CMD_WRITE;
						sdram_bank_reg 		<= buffer_address_reg[24:23];
						sdram_addr_reg 		<= {3'b000, buffer_address_reg[9:0]};
						sdram_data_reg 		<= buffer_data_reg[15:0]; 				// static assignment
						word_flag_reg 		<= 1'b1;
					end
				end

				SD_WRITE: begin
					case(word_flag_reg)
						// write first half of the word
						1'b0: begin
							sdram_command_reg 	<= `SDRAM_CMD_WRITE;
							sdram_bank_reg 		<= buffer_address_reg[24:23];
							sdram_addr_reg 		<= {3'b000, buffer_address_reg[9:0]};
							sdram_data_reg 		<= buffer_data_reg[(16*n_counter_reg)+:16];
							word_flag_reg 		<= 1'b1;
						end
						// write second half of the word
						1'b1: begin
							word_flag_reg 		<= 1'b0;
							sdram_data_reg 		<= buffer_data_reg[(16*(n_counter_reg+1))+:16];
							n_counter_reg 		<= n_counter_reg + 1'b1;
							// if done with all transactions then stop burst
 							if (!buffer_length_reg) begin
 								state_reg 			<= SD_PRECHARGE;
 								sdram_command_reg 	<= `SDRAM_CMD_NOP;
 								delay_counter_reg 	<= 1'b1;
 							end
 							// if not done request the next word
 							else begin
 								buffer_length_reg 	<= buffer_length_reg - 1'b1;
 								buffer_address_reg 	<= buffer_address_reg + 2'b10;
 							end
						end
					endcase
				end
				SD_READ_PRE: begin
					if (buffer_length_reg) begin
						sdram_command_reg 	<= `SDRAM_CMD_READ; 	
 						sdram_addr_reg 		<= sdram_addr_reg + 2'b10;
					end
					state_reg 	<= SD_READ;
				end
				SD_READ: begin
					case(word_flag_reg)
						// read first half of word
						1'b0: begin
							data_o_reg[(16*n_counter_reg)+:16] 			<= DRAM_DQ;
							word_flag_reg 								<= 1'b1;
						end
						// read second half of word
						1'b1: begin
							data_o_reg[(16*(n_counter_reg+1))+:16] 		<= DRAM_DQ;
							n_counter_reg 								<= n_counter_reg + 1'b1;
							word_flag_reg 								<= 1'b0;

							// if done with all transactions then stop burst
 							if (!buffer_length_reg) begin
 								state_reg 			<= SD_PRECHARGE;
 								sdram_command_reg 	<= `SDRAM_CMD_NOP;
 								delay_counter_reg 	<= 1'b1;
 							end
 							// if not done request the next word
 							else begin
 								buffer_length_reg 	<= buffer_length_reg - 1'b1;
 								sdram_command_reg 	<= `SDRAM_CMD_READ; 	
 								sdram_addr_reg 		<= sdram_addr_reg + 2'b10;
 							end
						end
					endcase
				end
				SD_PRECHARGE: begin
					sdram_data_dir_reg 	<= 1'b0;
					state_reg 			<= SD_DONE;
					sdram_command_reg 	<= `SDRAM_CMD_PRECHARGE;
					sdram_addr_reg[10]	<= 1'b1; 		
				end
				SD_DONE: begin
					done_reg 			<= 1'b1;
					ready_reg 			<= 1'b1;
					sdram_command_reg 	<= `SDRAM_CMD_NOP;
					state_reg 			<= SD_IDLE;
				end
			endcase
		end // if (delay_counter_reg)
	end
end

endmodule

`endif // _SDRAM_CONTROLLER_V_