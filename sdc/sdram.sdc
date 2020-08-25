# ISSI SDRAM specifications
set tSU 	1.500
set tH 		0.800
set tAC 	5.400
set tOH 	2.700

# for jtag port timing - set this board value
# >> jtagconfig -d
create_clock -period 6MHz {altera_reserved_tck}
set_clock_groups -asynchronous -group {altera_reserved_tck}

# set these to the relevant clock nodes
# 	- input clock
create_clock -name CLOCK_virt -period 50.000
create_generated_clock -name DRAM_CLK -source [get_nets {pll_reset|pll_20_3phase_inst|altera_pll_i|outclk_wire[0]}] [get_ports {DRAM_CLK}]

# set signal-to-sdram timing constraints
set_input_delay -clock {CLOCK_virt} -max [expr $tAC] [get_ports {DRAM_DQ*}]
set_input_delay -clock {CLOCK_virt} -min [expr $tOH] [get_ports {DRAM_DQ*}]
set_output_delay -clock {DRAM_CLK} -max [expr $tSU] [get_ports {DRAM_CKE DRAM_CS_N DRAM_CAS_N DRAM_RAS_N DRAM_WE_N DRAM_UDQM DRAM_LDQM DRAM_BA[*] DRAM_ADDR[*] DRAM_DQ[*]}]
set_output_delay -clock {DRAM_CLK} -min [expr -$tH] [get_ports {DRAM_CKE DRAM_CS_N DRAM_CAS_N DRAM_RAS_N DRAM_WE_N DRAM_UDQM DRAM_LDQM DRAM_BA[*] DRAM_ADDR[*] DRAM_DQ[*]}]