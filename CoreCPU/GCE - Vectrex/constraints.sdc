# Clock constraints

# Generated clock

create_generated_clock -name clkdiv -source [get_nets {guest|pll|altpll_component|auto_generated|wire_pll1_clk[0]}] -divide_by 32 [get_keepers {vectrex_mist:guest|vectrex:vectrex|clock_div2[6]}]

# Automatically constrain PLL and other generated clocks
derive_pll_clocks

# Automatically calculate clock uncertainty to jitter and other effects.
derive_clock_uncertainty

set_time_format -unit ns -decimal_places 3

set_input_delay -clock [get_clocks {guest|pll|altpll_component|auto_generated|pll1|clk[0]}] -max 6.4 [get_ports ${RAM_IN}]
set_input_delay -clock [get_clocks {guest|pll|altpll_component|auto_generated|pll1|clk[0]}] -min 3.2 [get_ports ${RAM_IN}]

set_output_delay -clock [get_clocks {guest|pll|altpll_component|auto_generated|pll1|clk[0]}] -max 1.5 [get_ports ${RAM_OUT}]
set_output_delay -clock [get_clocks {guest|pll|altpll_component|auto_generated|pll1|clk[0]}] -min -0.8 [get_ports ${RAM_OUT}]

set_clock_groups -asynchronous -group [get_clocks {spiclk}] -group [get_clocks {guest|pll|altpll_component|auto_generated|pll1|clk[*]}]

set_output_delay -clock [get_clocks {guest|pll|altpll_component|auto_generated|pll1|clk[0]}] -max 1.0 [get_ports ${VGA_OUT}]
set_output_delay -clock [get_clocks {guest|pll|altpll_component|auto_generated|pll1|clk[0]}] -min 0.5 [get_ports ${VGA_OUT}]

set_multicycle_path -to ${VGA_OUT} -setup 2
set_multicycle_path -to ${VGA_OUT} -hold 1

set_false_path -to [get_ports ${RAM_CLK}]
set_false_path -to ${FALSE_OUT}
set_false_path -from ${FALSE_IN}
