#!/usr/local/altera/quartus/bin/quartus_stp -t

#   832bridge.tcl - Virtual JTAG proxy for Altera devices
#
#   Description: Create a TCP connection to communicate between
#   the 832 Debugger and the Debug module of a running 832 core.
#   This TCL script requires Quartus STP to be installed.
#  
#   Based on Binary Logic's vjtag example code.
#   
#   This file is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

###################### Parameters ###########################

set service_port 33581
set listen_address 127.0.0.1

###################### Code #################################

# Setup connection
proc setup_blaster {} {
	global usbblaster_name
	global test_device

	# List all USB-Blasters connected to the system.  If there's only one
	# use that, otherwise prompt the user to choose one.
	set count 1
	foreach hardware_name [get_hardware_names] {
		if { [string match "USB-Blaster*" $hardware_name] } {
			puts "Device $count: $hardware_name"
			set usbblaster_name $hardware_name
			set count [expr $count + 1]
		}
	}

	if {$count>2} {
		puts "More than one USB-Blaster found - please select a device."
		gets stdin id
		scan $id "%d" idno
		set count 1
		foreach hardware_name [get_hardware_names] {
			if { [string match "USB-Blaster*" $hardware_name] } {
				if { $count == $idno } {
					puts "Selected $hardware_name"
					set usbblaster_name $hardware_name
				}
				set count [expr $count + 1]
			}
		}
	}


	# List all devices on the chain.  If there's only one, select that,
	# otherwise prompt the user to select one.

	puts "Devices on JTAG chain:";
	set count 0
	foreach device_name [get_device_names -hardware_name $usbblaster_name] {
		puts $device_name
		set test_device $device_name
		set count [expr $count + 1]		
	}

	if {$count>1} {
		puts "More than one device found - please select the appropriate device.";
		gets stdin id
		foreach device_name [get_device_names -hardware_name $usbblaster_name] {
			if { [string match "@$id*" $device_name] } {
				set test_device $device_name
			}
		}
	}
	puts "Selected $test_device.";
}

# Open device 
proc openport {} {
	global usbblaster_name
	global test_device
	set res 1
	if [ catch { open_device -hardware_name $usbblaster_name -device_name $test_device } ] { set res 0 }

	# Set IR to 0, which is bypass mode - which has the side-effect of verifying that there's a suitable JTAG instance.
	catch { device_lock -timeout 10000 }
	if [ catch { device_virtual_ir_shift -instance_index 0 -ir_value 3 -no_captured_ir_value } ] {
		set res 0
		catch {device_unlock}
		catch {close_device}
	}
	return $res
}


# Close device.  Just used if communication error occurs
proc closeport { } {
	global usbblaster_name
	global test_device

	# Set IR back to 0, which is bypass mode
	catch { device_virtual_ir_shift -instance_index 0 -ir_value 3 -no_captured_ir_value }

	catch {device_unlock}
	catch {close_device}
}

# Convert decimal number to the required binary code
proc dec2bin {i {width {}}} {

    set res {}
    if {$i<0} {
        set sign -
        set i [expr {abs($i)}]
    } else {
        set sign {}
    }
    while {$i>0} {
        set res [expr {$i%2}]$res
        set i [expr {$i/2}]
    }
    if {$res == {}} {set res 0}

    if {$width != {}} {
        append d [string repeat 0 $width] $res
        set res [string range $d [string length $res] end]
    }
    return $sign$res
}

# Convert a binary string to a decimal/ascii number
proc bin2dec {bin} {
    if {$bin == 0} {
        return 0
    } elseif {[string match -* $bin]} {
        set sign -
        set bin [string range $bin[set bin {}] 1 end]
    } else {
        set sign {}
    }
    return $sign[expr 0b$bin]
}

# Send data to the Altera input FIFO buffer
proc send {chr} {
	if [ catch { device_virtual_ir_shift -instance_index 0 -ir_value 1 -no_captured_ir_value } ] { return -1 }
	device_virtual_dr_shift -dr_value [dec2bin $chr 32] -instance_index 0  -length 32 -no_captured_dr_value
	return 1
}

# Read data in from the Altera output FIFO buffer
proc recv {} {
	# Check if there is anything to read
	if [ catch { device_virtual_ir_shift -instance_index 0 -ir_value 2 -no_captured_ir_value } ] { return -1 }
	set tdi [device_virtual_dr_shift -dr_value 0000 -instance_index 0 -length 4]
	if {![expr $tdi & 1]} {
		device_virtual_ir_shift -instance_index 0 -ir_value 0 -no_captured_ir_value
		set tdi [device_virtual_dr_shift -dr_value 00000000000000000000000000000000 -instance_index 0 -length 32]
		return [bin2dec $tdi]
	} else {
		return -1
	}
}

# Read data in from the Altera output FIFO buffer
proc recv_blocking {} {
	while {1} {
		if [ catch { device_virtual_ir_shift -instance_index 0 -ir_value 2 -no_captured_ir_value } ] { return [ bin2dec 0 ] }
		set tdi [device_virtual_dr_shift -dr_value 0000 -instance_index 0 -length 4]
#		puts $tdi
		if {![expr $tdi & 1]} {
			device_virtual_ir_shift -instance_index 0 -ir_value 0 -no_captured_ir_value
			set tdi [device_virtual_dr_shift -dr_value 00000000000000000000000000000000 -instance_index 0 -length 32]
			return [bin2dec $tdi]
		}
	}
}

########## Process a connection on the port ###########################

proc conn {channel_name client_address client_port} {
	global service_port
	global listen_address
	global wait_connection

	# Configure the channel for binary
	fconfigure $channel_name -translation binary -buffering none -blocking true

	puts "Connection from $client_address"
	flush $channel_name

	set portopen 0

	while {1} {
		# Try to read a character from the buffer
		set cmd [read $channel_name 1]
		set parambytes [read $channel_name 1]
		set responsebytes [read $channel_name 1]
		set byteparam [read $channel_name 1]
		if {[eof $channel_name]} {
			break
		}
		set numchars [string length $byteparam]


		# Did we receive something?
		if { $numchars > 0 } {

			scan $cmd %c ascii

			if { $ascii == 255} {
				puts -nonewline $channel_name [format %c $portopen]
				# Release the USB blaster again
				if { $portopen == 1 } closeport
				set portopen 0
			}
			
			if { $ascii != 255} {
#				puts [dec2bin $ascii]
				if { $portopen == 0 } {
					if [ openport ] { set portopen 1 }
				}

				set cmd [expr $ascii << 24]
				scan $parambytes %c parambytes
				set cmd [expr $cmd | [expr $parambytes << 16]]
				scan $responsebytes %c responsebytes
				set cmd [expr $cmd | [expr $responsebytes << 8]]
				scan $byteparam %c byteparam
				set cmd [expr $cmd | $byteparam]
				send $cmd

				# Sending parameters, if any

				set $cmd 0
				while { $parambytes > 0 } {
					set byteparam [read $channel_name 1]
					scan $byteparam %c ascii
					set cmd [expr [expr $cmd << 8] | $ascii]
					set parambytes [expr $parambytes - 1]
					if {$parambytes==0 || $parambytes==4} {
#						puts "Sending param..."
						send $cmd
					}
				}

				while { $responsebytes > 0 } {
#					puts "Waiting for response"
					if {[eof $channel_name]} break
					set rx [recv_blocking]
					puts -nonewline $channel_name [format %c [expr [expr $rx >> 24] & 255]]
					puts -nonewline $channel_name [format %c [expr [expr $rx >> 16] & 255]]
					puts -nonewline $channel_name [format %c [expr [expr $rx >> 8] & 255]]
					puts -nonewline $channel_name [format %c [expr $rx & 255]]
					set responsebytes [expr $responsebytes -4]
				}
	#				puts "done"
			}
		}
	}
	if { $portopen == 1 } {
		closeport
		set portopen 0
		puts "port closed"
	}
	close $channel_name
	puts "\nClosed connection"


	set wait_connection 1
}

####################### Main code ###################################
global usbblaster_name
global test_device
global wait_connection

# Find the USB Blaster
setup_blaster

# Start the server socket
socket -server conn -myaddr $listen_address $service_port

# Loop forever
while {1} {

	# Set the exit variable to 0
	set wait_connection 0

	# Display welcome message
	puts "832bridge listening for 832ocd connections on $listen_address:$service_port"

	# Wait for the connection to exit
	vwait wait_connection 
}
##################### End Code ########################################

