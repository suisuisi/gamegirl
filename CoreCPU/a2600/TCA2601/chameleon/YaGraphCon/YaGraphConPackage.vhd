-- Copyright (c) 2009 Frank Buss (fb@frank-buss.de)
-- See license.txt for license

library ieee;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

package YaGraphConPackage is
	-- registers
	subtype byte is unsigned(7 downto 0);
	constant COMMAND_REGISTER: integer := 16#00#;
	constant SRC_START_REGISTER: integer := 16#01#;
	constant SRC_PITCH_REGISTER: integer := 16#05#;
	constant DST_START_REGISTER: integer := 16#07#;
	constant DST_PITCH_REGISTER: integer := 16#0b#;
	constant COLOR_REGISTER: integer := 16#0d#;
	constant BLIT_WIDTH_REGISTER: integer := 16#0e#;
	constant BLIT_HEIGHT_REGISTER: integer := 16#10#;
	constant X0_REGISTER: integer := 16#12#;
	constant Y0_REGISTER: integer := 16#14#;
	constant X1_REGISTER: integer := 16#16#;
	constant Y1_REGISTER: integer := 16#18#;
	constant FRAMEBUFFER_START_REGISTER: integer := 16#1a#;
	constant FRAMEBUFFER_PITCH_REGISTER: integer := 16#1e#;
	constant STATUS_REGISTER: integer := 16#20#;
	constant WRITE_FRAMEBUFFER_REGISTER: integer := 16#21#;
	constant REGISTER_BYTE_COUNT: integer := 16#22#;
	type registerSetType is array ((8 * REGISTER_BYTE_COUNT)-1 downto 0) of byte;
	
	-- commands for COMMAND_REGISTER
	constant RESET_COMMAND: byte := x"00";
	constant SET_PIXEL: byte := x"01";
	constant DRAW_LINE: byte := x"02";
	constant FILL_RECT: byte := x"03";
	constant BLIT_SIZE: byte := x"04";
	constant BLIT_COMMAND: byte := x"05";
	constant BLIT_TRANSPARENT: byte := x"06";
	constant WRITE_FRAMEBUFFER: byte := x"07";

	-- useful synthesizable functions
	function adjustLength(value: unsigned; length: natural) return unsigned;
	function maxNatural(left, right: natural) return natural;
	function minNatural(left, right: natural) return natural;
end;

package body YaGraphConPackage is
	function adjustLength(value: unsigned; length: natural) return unsigned is
		variable result: unsigned(length-1 downto 0);
	begin
		if value'length >= length then
			result := value(length-1 downto 0);
		else
			result := to_unsigned(0, length - value'length) & value;
		end if;
		return result;
	end;

	function maxNatural(left, right: natural) return natural is
	begin
		if left > right then
			return left;
		else
			return right;
		end if;
	end;

	function minNatural(left, right: natural) return natural is
	begin
		if left < right then
			return left;
		else
			return right;
		end if;
	end;
end;
