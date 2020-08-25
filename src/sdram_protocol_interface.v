`ifndef _SDRAM_PROTOCOL_INTERFACE_V_
`define _SDRAM_PROTOCOL_INTERFACE_V_

module sdram_protocol_interface #(
	parameter UI_BW_ADDR 		= 0,
	parameter UI_BW_DATA_BUS 	= 0,
	parameter BW_BURST_LENGTH 	= 0,
	parameter BW_ADDR 			= 0,
	parameter BW_DATA_BLOCK 	= 0
)(
	// general
	input 							clock_i,
	input 							resetn_i, 
	// custom
	input 							req_i,
	input 							req_block_i,
	input 							rw_i,
	input 	[UI_BW_ADDR-1:0]		addr_i,
	input 	[UI_BW_DATA_BUS-1:0]	data_i,
	input 							clear_i,
	output 		 					done_o, 
	output 	 						ready_o, 
	output 	 						valid_o,
	output 	 [UI_BW_DATA_BUS-1:0] 	data_o,
	// sdram
	output 							sdram_request_o, 		// 0: no request, 1: request
	output 							sdram_command_o, 		// 0: read, 1: write
	output 	[BW_BURST_LENGTH-1:0]	sdram_length_o, 		// length of the request in 32-bit increments (4'b0000 is 1 txrx, 4'b1111 is 16 txrx) 
	output 	[BW_ADDR-1:0] 			sdram_address_o, 		// 
	output 	[BW_DATA_BLOCK-1:0] 	sdram_data_o,
	input 							sdram_ready_i, 			// 0: unable to service request, 1: ready for request
	// service ports
	input 							sdram_done_i,
	input 	[BW_DATA_BLOCK-1:0]		sdram_data_i  			// 1: valid output, register data_o	
);

// only considering word read/writes
reg 						done_o_reg;
reg 						ready_o_reg;
reg 						valid_o_reg;
reg [UI_BW_DATA_BUS-1:0] 	data_o_reg;

reg 						sdram_request_o_reg;
reg 						sdram_command_o_reg;
reg [BW_BURST_LENGTH-1:0] 	sdram_length_o_reg;
reg [BW_ADDR-1:0] 			sdram_address_o_reg;
reg [BW_DATA_BLOCK-1:0] 	sdram_data_o_reg;

reg [2:0]	state_reg;

reg delay_counter_reg;

localparam ST_IDLE 	= 3'b000;
localparam ST_READ0 = 3'b001;
localparam ST_READ1 = 3'b010;
localparam ST_WRITE0= 3'b011;
localparam ST_WRITE1= 3'b100;
localparam ST_WAIT_CLEAR= 3'b101;

assign done_o 	= done_o_reg;
assign ready_o 	= ready_o_reg;
assign valid_o 	= valid_o_reg;
assign data_o 	= data_o_reg;

assign sdram_request_o	= sdram_request_o_reg;
assign sdram_command_o	= sdram_command_o_reg;
assign sdram_length_o	= sdram_length_o_reg;
assign sdram_address_o	= sdram_address_o_reg;
assign sdram_data_o		= sdram_data_o_reg;

always @(posedge clock_i) begin
	if (!resetn_i) begin
		state_reg 			<= ST_IDLE;
		delay_counter_reg 	<= 1'b0;

		done_o_reg 			<= 1'b0;
		ready_o_reg 		<= 1'b1;
		valid_o_reg 		<= 1'b0;
		data_o_reg 			<= 'b0;

		sdram_request_o_reg <= 1'b0;
		sdram_command_o_reg <= 1'b0;
		sdram_length_o_reg 	<= 'b0;
		sdram_address_o_reg <= 'b0;
		sdram_data_o_reg 	<= 'b0;
	end
	else begin
		// default signals
		sdram_request_o_reg 	<= 1'b0;
		valid_o_reg 			<= 1'b0;

		// state machine sequencing
		if (delay_counter_reg) delay_counter_reg <= delay_counter_reg - 1'b1;
		else begin
			case(state_reg)

				// accept command
				ST_IDLE: begin
					if (req_i) begin
						// control signals
						ready_o_reg 			<= 1'b0;
						done_o_reg 				<= 1'b0;

						// register the command
						sdram_command_o_reg 	<= rw_i;
						sdram_length_o_reg 		<= 1'b0; 	// single word
						sdram_address_o_reg 	<= addr_i;
						sdram_data_o_reg[UI_BW_DATA_BUS-1:0] 	<= data_i;

						// sequencing
						if (!rw_i) 	state_reg 	<= ST_READ0;
						else 		state_reg 	<= ST_WRITE0;
					end
				end
				ST_READ0: begin
					if (sdram_ready_i) begin
						delay_counter_reg 		<= 1'b1; 		// needed
						sdram_request_o_reg 	<= 1'b1;
						state_reg 				<= ST_READ1;
					end
				end
				ST_READ1: begin
					if (sdram_done_i) begin
						state_reg 				<= ST_WAIT_CLEAR;
						data_o_reg 				<= sdram_data_i[UI_BW_DATA_BUS-1:0];
					end
				end

				ST_WRITE0: begin
					if (sdram_ready_i) begin
						delay_counter_reg 		<= 1'b1; 		// needed
						sdram_request_o_reg 	<= 1'b1;
						state_reg 				<= ST_WRITE1;
					end
				end

				ST_WRITE1: begin
					if (sdram_done_i) begin
						done_o_reg 				<= 1'b1;
						state_reg 				<= ST_WAIT_CLEAR;
					end
				end

				ST_WAIT_CLEAR: begin
					done_o_reg <= 1'b1;
					if (clear_i) begin
						state_reg 	<= ST_IDLE;
						ready_o_reg <= 1'b1;
						done_o_reg 	<= 1'b0;
					end
				end

			endcase
		end
	end
end


endmodule

`endif // _SDRAM_PROTOCOL_INTERFACE_V_