
---------------------------------------------------------------------------
-- (c) 2017 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_MISC.all;


-- Purpose:
-- Maps atari devices onto FPGA devices
-- So we map atari ram access to sdram or block ram -> and offset the address appropriately
ENTITY addressbus IS
GENERIC
(
	WIDTH : in integer := 16
);
PORT 
( 
	SELECTED_DEVICE : in std_logic_vector(1 downto 0);
	ADDR_0 : in std_logic_vector(WIDTH-1 downto 0);
	ADDR_1 : in std_logic_vector(WIDTH-1 downto 0);
	ADDR_2 : in std_logic_vector(WIDTH-1 downto 0);

	ADDR_OUT: out std_logic_vector(WIDTH-1 downto 0);
);

END addressbus;

ARCHITECTURE vhdl OF addressbus IS
BEGIN
	process(SELECTED_DEVICE,ADDR_0,ADDR_1,ADDR_2)
	begin
		ADDR_OUT <= (others=>'X');

		case SELECTED_DEVICE is 
			when "00" =>
				ADDR_OUT <= ADDR_0;
			when "01" =>
				ADDR_OUT <= ADDR_1;
			when others =>
				ADDR_OUT <= ADDR_2;
		end case;
	end process;

END vhdl;

