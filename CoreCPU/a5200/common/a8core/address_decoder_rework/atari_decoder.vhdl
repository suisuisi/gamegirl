
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


ENTITY atari_decoder IS
GENERIC
(
	system : integer := 0; -- 0=Atari XL,1=Atari 800, 10=Atari5200 (space left for more systems)
);
PORT 
( 
	ADDR : in std_logic_vector(15 downto 0);
	MPD_N : in std_logic;
	PORTB : in std_logic_vector(7 downto 0);
	EXTENDED_SELF_TEST : in std_logic;
	EXTENDED_ACCESS : in std_logic; -- current bank selection switches antic seperately?

	EMU_CART_RD4 : in std_logic;
	EMU_CART_RD5 : in std_logic;

	FREEZER : in std_logic;

	IO_OUT: out std_logic_vector(0 downto 0)
	IODEVICE_OUT: out std_logic_vector(2 downto 0)
	ADDRCALC_OUT: out std_logic_vector(2 downto 0)

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

	-- RAM/ROM:
	-- FROM RAM MAPPER
	--0 = BLOCK OS ROM
	--1 = BLOCK BASIC ROM
	--2 = BLOCK RAM
	--3 = SDRAM

	-- ADDRCALC MUX
	--0 = RAM
	--1 = OS ROM
	--2 = BANKED_RAM
	--3 = OS ROM
	--4 = BASIC ROM
	--5 = CART EMU
	--6 = FREEZER ROM
	--7 = FREEZER RAM
);

END atari_decoder;

ARCHITECTURE vhdl OF atari_decoder IS
	signal IO: std_logic_vector(0 downto 0)
	signal IODEVICE: std_logic_vector(2 downto 0)
	signal ADDRCALC: std_logic_vector(2 downto 0)
BEGIN

	process(addr,stereo,freezer)
	begin
		IODEVICE <= (others=>'X');

		-- PBI? TODO
		case addr(10 downto 8) is
			-- GTIA
			when "000" =>
				IODEVICE <= "000";
			-- POKEY
			when "010" =>				
				IODEVICE <= (stereo=1 and addr(4))&"10";
			-- PIA
			when "011" =>
				IODEVICE <= "011";
				
			-- ANTIC
			when "100" =>
				IODEVICE <= "100";
				
			-- CART_CONFIG
			when "101" =>
				IODEVICE <= "101";

			-- FREEZER
			when "111" =>
				IODEVICE <= "111";
				
			when others =>
		end case
	end process;

	IO <= addr(15) and addr(14) and not(addr(13)) and addr(12); --D(1101)

	--0 = RAM
	--1 = OS ROM
	--2 = BANKED_RAM
	--3 = OS ROM
	--4 = BASIC ROM
	--5 = CART EMU
	--6 = FREEZER ROM
	--7 = FREEZER RAM

	process(addr,mpd_n,portb,extended_access,extended_self_test,emu_cart_rd4,emu_cart_rd5,freezer,freezer_access_ram)
	begin
		ADDRCALC <= (others=>'0');

		if (freezer = '0') then
			case addr(15 downto 12) is

				-- 0x80 cart
				when X"8" |X"9" =>
					ADDRCALC <= (emu_cart_rd4)&"0"&(emu_cart_rd4);
			
				-- 0xa0 cart (BASIC ROM 0xa000 - 0xbfff (8k))
				when X"A" |X"B" =>
					ADDRCALC <= (emu_cart_rd5 or not(portb(1)))&"0"&(emu_cart_rd5);

				-- banked area
				-- SELF TEST ROM 0x5000->0x57ff and XE RAM
				when X"5" =>
					ADDRCALC <= "0"&extended_access& (extended_self_test and not(addr(11)));

				-- SELF TEST ROM 0x5000->0x57ff and XE RAM
				when X"4" |X"6" |X"7" =>
					ADDRCALC <= "0"&extended_access&"0";
					
				-- OS ROM d800->0xffff (math pack)
				when X"D" =>
					ADDRCALC <= "0"&(portb(0) and pbi_mpd_n)& (portb(0) and pbi_mpd_n);

				-- OS ROM 0xc00->0xcff				
				-- OS ROM e000->0xffff
				when X"C" |X"E" |X"F" =>
					ADDRCALC <= "0"&portb(0)&portb(0);
					
				when others =>
					ADDRCALC <= "000";
			end case;
		else
			ADDRCALC <= "11"&freezer_access_ram;
		end if;
	end process;

	IO_OUT <= IO;
	IODEVICE_OUT <= IODEVICE;
	ADDRCALC_OUT <= ADDRCALC;
end vhdl;

