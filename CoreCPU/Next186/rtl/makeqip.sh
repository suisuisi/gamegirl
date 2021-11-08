#!/bin/sh

echo -n > Next186.qip
for vhd in $(find . -name "*.v"); do
	echo "set_global_assignment -name VERILOG_FILE [file join $::quartus(qip_path) $vhd      ]" >> Next186.qip
done