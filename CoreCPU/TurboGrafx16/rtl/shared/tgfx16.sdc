# Note: topmodule must be defined in a board-specific .sdc file,
# which must come before this one in the file list.
# For MiST it will typically be "", for other platforms which wrap the MiST toplevel
# it will likely be "guest|"

# Clock constraints

set sdram_clk "${topmodule}pll|altpll_component|auto_generated|pll1|clk[0]"
set mem_clk   "${topmodule}pll|altpll_component|auto_generated|pll1|clk[1]"
set sys_clk   "${topmodule}pll|altpll_component|auto_generated|pll1|clk[2]"

# Clock groups
set_clock_groups -asynchronous -group [get_clocks {spiclk}] -group [get_clocks ${topmodule}pll|altpll_component|auto_generated|pll1|clk[*]]

# Some relaxed constrain to the VGA pins. The signals should arrive together, the delay is not really important.
set_output_delay -clock [get_clocks $sys_clk] -max 0 [get_ports ${VGA_OUT}]
set_output_delay -clock [get_clocks $sys_clk] -min -5 [get_ports ${VGA_OUT}]

set_multicycle_path -to ${VGA_OUT} -setup 2
set_multicycle_path -to ${VGA_OUT} -hold 1

# SDRAM delays
set_input_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports ${RAM_CLK}] -max 6.6 [get_ports ${RAM_IN}]
set_input_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports ${RAM_CLK}] -min 3.5 [get_ports ${RAM_IN}]

set_output_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports ${RAM_CLK}] -max 1.5 [get_ports ${RAM_OUT}]
set_output_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports ${RAM_CLK}] -min -0.8 [get_ports ${RAM_OUT}]

set_multicycle_path -from [get_clocks $sdram_clk] -to [get_clocks $mem_clk] -setup -end 2

set_false_path -to [get_ports ${RAM_CLK}]
set_false_path -to [get_ports ${FALSE_OUT}]
set_false_path -from [get_ports ${FALSE_IN}]
