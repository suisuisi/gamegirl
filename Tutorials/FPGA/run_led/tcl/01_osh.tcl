#------------------GLOBAL--------------------#
set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED"
set_global_assignment -name ENABLE_INIT_DONE_OUTPUT OFF

#复位引脚
set_location_assignment	PIN_M1	-to RSTn

#时钟引脚
set_location_assignment	PIN_R9	-to CLK

#LED对应的引脚
set_location_assignment	PIN_J1	-to LED_Out[0]
set_location_assignment	PIN_J2	-to LED_Out[1]
set_location_assignment	PIN_K1	-to LED_Out[2]
set_location_assignment	PIN_K2	-to LED_Out[3]





