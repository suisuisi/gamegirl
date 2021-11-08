#************************************************************
# THIS IS A WIZARD-GENERATED FILE.                           
#
# Version 13.1.4 Build 182 03/12/2014 SJ Full Version
#
#************************************************************

# Copyright (C) 1991-2014 Altera Corporation
# Your use of Altera Corporation's design tools, logic functions 
# and other software and tools, and its AMPP partner logic 
# functions, and any output files from any of the foregoing 
# (including device programming or simulation files), and any 
# associated documentation or information are expressly subject 
# to the terms and conditions of the Altera Program License 
# Subscription Agreement, Altera MegaCore Function License 
# Agreement, or other applicable license agreement, including, 
# without limitation, that your use is for the sole purpose of 
# programming logic devices manufactured by Altera and sold by 
# Altera or its authorized distributors.  Please refer to the 
# applicable agreement for further details.



# Clock constraints

create_clock -name "CLOCK_27" -period 37.037 [get_ports {CLOCK_27}]
create_clock -name {SPI_SCK}  -period 41.666 -waveform { 20.8 41.666 } [get_ports {SPI_SCK}]

# Automatically constrain PLL and other generated clocks
derive_pll_clocks -create_base_clocks

# Automatically calculate clock uncertainty to jitter and other effects.
derive_clock_uncertainty

set sdram_clk "dcm_system|altpll_component|auto_generated|pll1|clk[2]"
set mem_clk   "dcm_system|altpll_component|auto_generated|pll1|clk[1]"
set sys_clk   "dcm_system|altpll_component|auto_generated|pll1|clk[0]"

set snd_clk   "dcm_misc|altpll_component|auto_generated|pll1|clk[0]"
set uart_clk  "dcm_misc|altpll_component|auto_generated|pll1|clk[1]"

set cpu_clk   "dcm_cpu_inst|altpll_component|auto_generated|pll1|clk[0]"
set dsp_clk   "dcm_cpu_inst|altpll_component|auto_generated|pll1|clk[1]"

# Clock groups
set_clock_groups -asynchronous -group [get_clocks {SPI_SCK}] -group [get_clocks dcm_system|altpll_component|auto_generated|pll1|clk[*]]
set_clock_groups -asynchronous -group [get_clocks {SPI_SCK}] -group [get_clocks dcm_cpu_inst|altpll_component|auto_generated|pll1|clk[*]]

set_multicycle_path -from [get_registers {sys_inst|CPUUnit|cpu*}] -setup -start 2
set_multicycle_path -from [get_registers {sys_inst|CPUUnit|cpu*}] -hold -start 1
set_multicycle_path -from [get_registers {sys_inst|CPUUnit|cpu*}] -to [get_registers {sys_inst|seg_mapper|*addr*}] -setup -start 1
set_multicycle_path -from [get_registers {sys_inst|CPUUnit|cpu*}] -to [get_registers {sys_inst|seg_mapper|*addr*}] -hold -start 0

# Some relaxed constrain to the VGA pins. The signals should arrive together, the delay is not really important.
set_output_delay -clock [get_clocks $sys_clk] -max 0 [get_ports {VGA_*}]
set_output_delay -clock [get_clocks $sys_clk] -min -5 [get_ports {VGA_*}]

set_multicycle_path -to {VGA_*[*]} -setup 2
set_multicycle_path -to {VGA_*[*]} -hold 1

# SDRAM delays
set_input_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -max 6.4 [get_ports SDRAM_DQ[*]]
set_input_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -min 3.5 [get_ports SDRAM_DQ[*]]

set_output_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -max 1.5 [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]
set_output_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -min -0.8 [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]

set_false_path -from [get_clocks $uart_clk] -to [get_clocks $cpu_clk]
set_false_path -from [get_clocks $cpu_clk] -to [get_clocks $uart_clk]
set_false_path -from [get_clocks $snd_clk] -to [get_clocks $cpu_clk]
set_false_path -from [get_clocks $cpu_clk] -to [get_clocks $snd_clk]
set_false_path -from [get_clocks $cpu_clk] -to [get_clocks $mem_clk]
set_false_path -from [get_clocks $dsp_clk] -to [get_clocks $mem_clk]

set_false_path -to [get_ports {SDRAM_CLK}]
set_false_path -to [get_ports {AUDIO_L}]
set_false_path -to [get_ports {AUDIO_R}]
set_false_path -to [get_ports {LED}]
