set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE22F17I7

set_location_assignment PIN_N6 -to LED
#set_location_assignment PIN_M16 -to CLOCK_50[0]
#set_location_assignment PIN_R8 -to CLOCK_50[1]
set_location_assignment PIN_E1 -to CLOCK_27[0]
#set_location_assignment PIN_T9 -to CLOCK_27[1]

set_location_assignment PIN_F8 -to VGA_R[5]
set_location_assignment PIN_E8 -to VGA_R[4]
set_location_assignment PIN_C8 -to VGA_R[3]
set_location_assignment PIN_E10 -to VGA_R[2]
set_location_assignment PIN_E9 -to VGA_R[1]
set_location_assignment PIN_F9 -to VGA_R[0]

set_location_assignment PIN_B5 -to VGA_B[5]
set_location_assignment PIN_A5 -to VGA_B[4]
set_location_assignment PIN_B4 -to VGA_B[3]
set_location_assignment PIN_A4 -to VGA_B[2]
set_location_assignment PIN_B6 -to VGA_B[1]
set_location_assignment PIN_A6 -to VGA_B[0]

set_location_assignment PIN_D5 -to VGA_G[5]
set_location_assignment PIN_C6 -to VGA_G[4]
set_location_assignment PIN_A7 -to VGA_G[3]
set_location_assignment PIN_B7 -to VGA_G[2]
set_location_assignment PIN_D8 -to VGA_G[1]
set_location_assignment PIN_D6 -to VGA_G[0]

set_location_assignment PIN_D9 -to VGA_VS
set_location_assignment PIN_C9 -to VGA_HS

set_location_assignment PIN_T7 -to AUDIO_L
set_location_assignment PIN_R7 -to AUDIO_R
set_location_assignment PIN_G2 -to UART_TX
set_location_assignment PIN_G1 -to UART_RX

set_location_assignment PIN_T2 -to SPI_DO
set_location_assignment PIN_R3 -to SPI_DI
set_location_assignment PIN_R1 -to SPI_SCK
set_location_assignment PIN_P3 -to SPI_SS3
set_location_assignment PIN_H2 -to CONF_DATA0
set_location_assignment PIN_T3 -to SPI_SS2
set_location_assignment PIN_N3 -to SPI_SS4

set_location_assignment PIN_N12 -to SDRAM_A[0]
set_location_assignment PIN_L14 -to SDRAM_A[1]
set_location_assignment PIN_L13 -to SDRAM_A[2]
set_location_assignment PIN_J13 -to SDRAM_A[3]
set_location_assignment PIN_J14 -to SDRAM_A[4]
set_location_assignment PIN_F14 -to SDRAM_A[5]
set_location_assignment PIN_F13 -to SDRAM_A[6]
set_location_assignment PIN_E11 -to SDRAM_A[7]
set_location_assignment PIN_D14 -to SDRAM_A[8]
set_location_assignment PIN_C11 -to SDRAM_A[9]
set_location_assignment PIN_P14 -to SDRAM_A[10]
set_location_assignment PIN_D11 -to SDRAM_A[11]
set_location_assignment PIN_B14 -to SDRAM_A[12]

set_location_assignment PIN_N16 -to SDRAM_DQ[0]
set_location_assignment PIN_N15 -to SDRAM_DQ[1]
set_location_assignment PIN_L15 -to SDRAM_DQ[2]
set_location_assignment PIN_L16 -to SDRAM_DQ[3]
set_location_assignment PIN_K15 -to SDRAM_DQ[4]
set_location_assignment PIN_K16 -to SDRAM_DQ[5]
set_location_assignment PIN_J15 -to SDRAM_DQ[6]
set_location_assignment PIN_J16 -to SDRAM_DQ[7]
set_location_assignment PIN_C15 -to SDRAM_DQ[8]
set_location_assignment PIN_C16 -to SDRAM_DQ[9]
set_location_assignment PIN_D15 -to SDRAM_DQ[10]
set_location_assignment PIN_D16 -to SDRAM_DQ[11]
set_location_assignment PIN_F16 -to SDRAM_DQ[12]
set_location_assignment PIN_F15 -to SDRAM_DQ[13]
set_location_assignment PIN_D12 -to SDRAM_DQ[14]
set_location_assignment PIN_C14 -to SDRAM_DQ[15]

set_location_assignment PIN_R16 -to SDRAM_BA[0]
set_location_assignment PIN_R14 -to SDRAM_BA[1]

set_location_assignment PIN_B16 -to SDRAM_DQMH
set_location_assignment PIN_G16 -to SDRAM_DQML

set_location_assignment PIN_P16 -to SDRAM_nRAS
set_location_assignment PIN_N14 -to SDRAM_nCAS

set_location_assignment PIN_G15 -to SDRAM_nWE
set_location_assignment PIN_P15 -to SDRAM_nCS
set_location_assignment PIN_A15 -to SDRAM_CKE
set_location_assignment PIN_A14 -to SDRAM_CLK