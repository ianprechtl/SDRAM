`ifndef _SDRAM_REFRESH_CONTROLLER_V_
`define _SDRAM_REFRESH_CONTROLLER_V_

module sdram_refresh_controller #(
	parameter N_CYCLES 	= 0, 		// max number of cycles between refreshes issued
	parameter BW_CYCLES = 0, 		
	parameter BW_DEPTH 	= 0 		// how many refreshes can accumulate (ideally should not be necessary)
)(
	// general ports
	input 			clock_i,
	input 			resetn_i,
	input 			status_i, 		// 0: sdram not initialized, 1: sdram initialized
	input 			execute_i, 		// 1: refresh being executed 
	output 			refresh_o 		// 0: no refresh necessary, 1: refresh necessary
); 


// port mapping
// ------------------------------------------------------------------

// issue a refresh until there is no longer any accumulated refreshes
reg refresh_reg;
assign refresh_o = (refresh_counter_reg) ? 1'b1 : 1'b0; 


// state machine logic
// ------------------------------------------------------------------
reg 	[BW_CYCLES-1:0]	cycle_counter_reg;
reg 	[BW_DEPTH-1:0] 	refresh_counter_reg;

always @(posedge clock_i) begin
	// reset state
	if (!resetn_i) begin
		cycle_counter_reg 	<= N_CYCLES[BW_CYCLES-1:0];
		refresh_counter_reg <= 'b0;
	end
	// active sequencing states
	else begin

		// only monitor refreshes once the controller has initialized the SDRAM
		if (status_i) begin

			// update refresh counter if either the cycle counter is expired (+1) 
			// or the controller issued a refresh (-1)
			refresh_counter_reg <= refresh_counter_reg + (!cycle_counter_reg) - execute_i;

			// renew cycle count if expired
			if (!cycle_counter_reg) cycle_counter_reg <= N_CYCLES[BW_CYCLES-1:0];
			else 					cycle_counter_reg <= cycle_counter_reg - 1'b1;
		end
	end
end

endmodule

`endif // _SDRAM_REFRESH_CONTROLLER_V_