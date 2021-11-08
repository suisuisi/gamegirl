
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
ENTITY ram_mapper IS
GENERIC
(
	IS_ANTIC : in integer; -- 0 for cpu, 1 for antic
	HIGH_START_BANK : integer := 0; -- 0=sdram only, 5=512k ram. (2^n*16)
	LOW_MEMORY : in integer
)
PORT 
( 
	CLK : in std_logic;     -- bank switch logic is registered
	RESET_N : in std_logic;

	ADDRCALC : in std_logic_vector(2 downto 0);
	ADDR : in std_logic_vector(15 downto 0);

	ADDR_OUT: out std_logic_vector(24 downto 0);
	RAM_TYPE_OUT: out std_logic_vector(1 downto 0);
	EXTENDED_ACCESS_OUT : out std_logic;
	EXTENDED_SELF_TEST_OUT : out std_logic

	-- RAM/ROM:
	-- FROM RAM MAPPER
	--0 = BLOCK OS ROM
	--1 = BLOCK BASIC ROM
	--2 = LOW RAM
	--3 = HIGH RAM

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

END ram_mapper;

ARCHITECTURE vhdl OF ram_mapper IS
BEGIN


BASE_RAM_ADDR(15 downto 0) <= addr(15 downto 0);
BASE_RAM_ADDR(22 downto 16) <= (others=>'0');

BANKED_RAM_ADDR(13 downto 0) <= addr(13 downto 0);
BANKED_RAM_ADDR(22 downto 14) <= extended_bank_reg;

gen_normal_memory : if low_memory=0 generate

	-- SRAM memory map (512k)
	-- base 64k RAM  - banks 0-3    "000 0000 1111 1111 1111 1111" (TOP)
	-- to 512k RAM   - banks 4-31   "000 0111 1111 1111 1111 1111" (TOP)
	-- SDRAM memory map (8MB)
	-- base 64k RAM  - banks 0-3    "000 0000 1111 1111 1111 1111" (TOP)
	-- to 512k RAM   - banks 4-31   "000 0111 1111 1111 1111 1111" (TOP) 
	-- to 4MB RAM    - banks 32-255 "011 1111 1111 1111 1111 1111" (TOP)
	-- +64k          - banks 256-259"100 0000 0000 1111 1111 1111" (TOP)
	BASE_RAM_TYPE    <= "10"

	-- SCRATCH       - 4MB+64k-5MB
	-- 128k freezer ram		"100 100Y YYYY YYYY YYYY YYYY"
	FREEZER_RAM_ADDR <= "100100" & freezer_access_address;
	-- 64k freezer rom		"100 1010 YYYY YYYY YYYY YYYY"
	FREEZER_ROM_ADDR <= "1001010" & freezer_access_address(15 downto 0);
	-- CARTS         -              "101 YYYY YYY0 0000 0000 0000" (BOT) - 2MB! 8kb banks
	--CART_ADDR      <= "101"&cart_select& "0000000000000";
	CART_ADDR	<= "1" & emu_cart_address(20) & (not emu_cart_address(20)) & emu_cart_address(19 downto 0);
	-- BASIC/OS ROM  -              "111 XXXX XX00 0000 0000 0000" (BOT) (BASIC IN SLOT 0!), 2nd to last 512K				
	BASIC_ROM_ADDR <= "000000000"   & addr;
	OS_ROM_ADDR    <= "000000000"   & addr;
	BASIC_ROM_TYPE <= "00"
	OS_ROM_TYPE    <= "01"
	-- SYSTEM        -              "111 1000 0000 0000 0000 0000" (BOT) - LAST 512K

end generate;

gen_low_memory1 : if low_memory=1 generate

	BASE_RAM_TYPE    <= "11"

	-- SRAM memory map (1024k) for Aeon lite 
	CART_ADDR      <= "0000" & "1"&emu_cart_address(17 downto 0); 
	BASIC_ROM_ADDR <= "000" & x"6"&"10" & addr(13 downto 0);
	OS_ROM_ADDR    <= "000" & x"6"&"11" & addr(13 downto 0);
	BASIC_ROM_TYPE <= "11"
	OS_ROM_TYPE    <= "11"
	FREEZER_RAM_ADDR <= "000" & "001" & freezer_access_address;
	FREEZER_ROM_ADDR <= "000" & x"7" & freezer_access_address(15 downto 0);

-- 0x10000-0x1FFFF (0x810000 in zpu space) = freeze backup - 64k
-- 0x20000-0x3FFFF (0x820000 in zpu space) = freezer ram (128k)
-- 0x40000-0x67FFF (0x840000 in zpu space) = carts - 160k
-- 0x48000-0x67FFF (0x848000 in zpu space) = directory cache - 128k
-- 0x68000-0x6FFFF (0x868000 in zpu space) = os rom/basic rom - 32k
-- 0x70000-0x7FFFF (0x870000 in zpu space) = freezer rom (64k)

end generate;

gen_low_memory2 : if low_memory=2 generate

	BASE_RAM_TYPE    <= "11"

	-- SRAM memory map (512k) for Papilio duo 
	CART_ADDR      <= "0000" & "01"&emu_cart_address(16 downto 0); 
	BASIC_ROM_ADDR <= "0000" & "01110"&addr(13 downto 0);
	OS_ROM_ADDR    <= "0000" & "01111"&addr(13 downto 0);
	BASIC_ROM_TYPE <= "11"
	OS_ROM_TYPE    <= "11"

end generate;

	extended_access_separate <= not(portb(4+is_antic));
	extended_access_single <= not(portb(4));
	extended_bank_base <= "000000100";

	process(ram_select,portb,extended_access_separate,extended_access_single,extended_bank_base)
	begin	
		extended_bank_offset <= (others=>'X');
		extended_self_test_next <= 'X';
		extended_access_next <= 'X';

		case ram_select is
			when "000" => -- 64k
				extended_access_next <= '0';
				extended_bank_offset <= (others=>'0');
				extended_self_test_next <= not(portb(7)) and portb(0);
			when "001" => -- 128k			
				extended_access_next <= extended_access_separate;
				extended_bank_offset <= "0000000"&portb(3 downto 2);
				extended_self_test_next <= not(portb(7)) and portb(0);
			when "010" => -- 320k compy shop
				extended_access_next <= extended_access_separate;
				extended_bank_offset <= "00000"&portb(7 downto 6)&portb(3 downto 2);
				extended_self_test_next <= '0';
				extended_self_test_next <= not(portb(7)) and portb(0) and not(extended_access_separate);
			when "011" => -- 320k rambo
				extended_access_next <= extended_access_single;
				extended_bank_offset <= "00000"&portb(6 downto 5)&portb(3 downto 2);
				extended_self_test_next <= not(portb(7)) and portb(0);
			when "100" => -- 576k compy shop
				extended_access_next <= extended_access_separate;
				extended_bank_offset <= "0000"&portb(7 downto 6)&portb(3 downto 1);
				extended_self_test_next <= not(portb(7)) and portb(0) and not(extended_access_separate);
			when "101" => -- 576k rambo
				extended_access_next <= extended_access_single;
				extended_bank_offset <= "0000"&portb(6 downto 5)&portb(3 downto 1);
				extended_self_test_next <= not(portb(7)) and portb(0);
			when "110" => -- 1088k rambo
				extended_access_next <= extended_access_single;
				extended_bank_offset <= "000"&portb(7 downto 5)&portb(3 downto 1);
				extended_self_test_next <= not(portb(7)) and portb(0) and not(extended_access_single);
			when "111" => -- 4MB!	
				extended_access_next <= '1';
				extended_bank_offset <= "0"&portb(7 downto 0);
				extended_self_test_next <= '0'; -- always off!
			when others =>
				-- TODO - portc!
		end case;
	end process;

	extended_bank_next <= std_logic_vector(unsigned(extended_bank_bank) + unsigned(extended_bank_offset));
	extended_bank_high_ram_next <= or_reduce(extended_bank_next(8 downto high_start_bank));

	process(clk,reset_n)
	begin
		if (reset_n='0') then
			extended_access_reg <= '0';
			extended_bank_reg <= (others=>'0');
			extended_bank_high_ram_reg <= '0';
			extended_self_test_reg <= '0';
		elseif (clk'event and clk='1') then
			extended_access_reg <= extended_access_next;
			extended_bank_reg <= extended_bank_next;
			extended_bank_high_ram_reg <= extended_Bank_high_ram_next;
			extended_self_test_reg <= extended_self_test_next;
		end if;
	end process;

	--0 = RAM
	--1 = OS ROM
	--2 = BANKED_RAM
	--3 = OS ROM
	--4 = BASIC ROM
	--5 = CART EMU
	--6 = FREEZER ROM
	--7 = FREEZER RAM

	process(addrcalc,BASE_RAM_ADDR,BASE_RAM_TYPE,BANKED_RAM_ADDR,extended_bank_high_ram_reg,OS_ROM_ADDR,OS_ROM_TPE,BASIC_ROM_ADDR,BASIC_ROM_TYPE,CART_ADDR,FREEZER_ROM_ADDR,FREEZER_RAM_ADDR)
	begin
		addr_adjusted <= (others=>'X');
		ram_type <= "xx";

		case addrcalc is =>
		when "000" =>
			-- ram
			addr_adjusted <= BASE_RAM_ADDR;
			ram_type <= BASE_RAM_TYPE;
		when "010" =>
			-- banked ram
			addr_adjusted <= BANKED_RAM_ADDR;
			ram_type <= "1"&extended_bank_high_ram_reg;
		when "001"|"011" =>
			-- os rom
			addr_adjusted <= OS_ROM_ADDR;
			ram_type <= OS_ROM_TYPE;
		when "100" =>
			-- basic rom
			addr_adjusted <= BASIC_ROM_ADDR;
			ram_type <= BASIC_ROM_TYPE;
		when "101" =>
			addr_adjusted <= CART_ADDR;
			ram_type <= "11";
		when "110" =>
			addr_adjusted <= FREEZER_ROM_ADDR;
			ram_type <= "11";
		when "111" =>
			addr_adjusted <= FREEZER_RAM_ADDR;
			ram_type <= "11";
			--
		end case;
	end process;

	ADDR_OUT <= addr_adjusted;
	RAM_TYPE_OUT <= ram_type;
	EXTENDED_ACCESS_OUT <= extended_access_reg;
	EXTENDED_SELF_TEST_OUT <= extended_self_test_reg;
end vhdl;

