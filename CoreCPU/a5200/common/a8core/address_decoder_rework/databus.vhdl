
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
ENTITY databus IS
PORT 
( 
	MEMORY_TYPE : in std_logic_vector(1 downto 0);
	OS_ROM_DATA : in std_logic_vector(7 downto 0);
	BASIC_ROM_DATA : in std_logic_vector(7 downto 0);
	LOW_RAM_DATA : in std_logic_vector(7 downto 0);
	HIGH_RAM_DATA : in std_logic_vector(7 downto 0);

	IO_TYPE : in std_logic_vector(2 downto 0);
	GTIA_DATA : in std_logic_vector(7 downto 0);
	POKEY1_DATA : in std_logic_vector(7 downto 0);
	POKEY2_DATA : in std_logic_vector(7 downto 0);
	PIA_DATA : in std_logic_vector(7 downto 0);
	ANTIC_DATA : in std_logic_vector(7 downto 0);
	CARTEMU_DATA : in std_logic_vector(7 downto 0);
	FREEZER_DATA : in std_logic_vector(7 downto 0);
	PBI_DATA : in std_logic_vector(7 downto 0);
	
	MAIN_TYPE : in std_logic_vector(0 downto 0);

	DATA_OUT: out std_logic_vector(7 downto 0);

	-- RAM/ROM:
	-- FROM RAM MAPPER
	--0 = BLOCK OS ROM
	--1 = BLOCK BASIC ROM
	--2 = LOW RAM
	--3 = HIGH RAM

	-- IO MUX
	--0 = RAM MUX (SDRAM or BLOCK RAM)
	--1 = IO MUX (ANY CHIPS, CART EMU, FREEZER, PULLUPS)

	-- SUB DEVICE MUX
	-- IO:
	--0 = GTIA
	--2 = POKEY1
	--3 = PIA
	--4 = ANTIC
	--5 = CARTEMU
	--6 = POKEY2
	--7 = FREEZER
);

END databus;

ARCHITECTURE vhdl OF databus IS
BEGIN
	process(MEMORY_TYPE,OS_ROM_DATA,BASIC_ROM_DATA,LOW_RAM_DATA,HIGH_RAM_DATA)
	begin
		MEMORY_DATA <= (others=>'X');

		case RAM_TYPE is 
			when "00" =>
				MEMORY_DATA <= OS_ROM_DATA;
			when "01" =>
				MEMORY_DATA <= BASIC_ROM_DATA;
			when "10" =>
				MEMORY_DATA <= LOW_RAM_DATA;
			when others =>
				MEMORY_DATA <= HIGH_RAM_DATA;
		end case;
	end process;

	process(IO_TYPE,GTIA_DATA,POKEY1_DATA,PIA_DATA,ANTIC_DATA,CARTEMU_DATA,POKEY2_DATA,FREEZER_DATA)
	begin
		IO_DATA <= (others=>'X');
		case IO_TYPE is
			when "000" =>
				IO_DATA <= GTIA_DATA;
			when "001" =>
				IO_DATA <= PBI_DATA;
			when "010" =>
				IO_DATA <= POKEY1_DATA;
			when "011" =>
				IO_DATA <= PIA_DATA;
			when "100" =>
				IO_DATA <= ANTIC_DATA;
			when "101" =>
				IO_DATA <= CARTEMU_DATA;
			when "110" =>
				IO_DATA <= POKEY2_DATA;
			when others =>
				IO_DATA <= FREEZER_DATA;
		end case;
	end process;

	process(MAIN_TYPE,MEMORY_DATA,IO_DATA)
	begin
		MAIN_DATA <= (others=>'X');
		case MAIN_TYPE is
			when "00" =>
				MAIN_DATA <= MEMORY_DATA;
			when others =>
				MAIN_DATA <= IO_DATA;
		end case;
	end process;

	DATA_OUT <= MAIN_DATA;

END vhdl;

