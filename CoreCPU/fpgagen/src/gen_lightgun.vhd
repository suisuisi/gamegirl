-- Copyright (c) 2020 Gyorgy Szombathelyi
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- Please report bugs to the author, but before you do so, please
-- make sure that this is not a derivative work and that
-- you have the latest version of this file.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity gen_lightgun is
	port(
		RST_N        : in  std_logic;
		CLK          : in  std_logic;

		CE_PIX       : in  std_logic;
		VBL          : in  std_logic;
		HBL          : in  std_logic;
		mouse_x      : in  std_logic_vector(7 downto 0);
		mouse_y      : in  std_logic_vector(7 downto 0);
		mouse_flags  : in  std_logic_vector(7 downto 0);
		mouse_strobe : in  std_logic;

		JUSTIFIER    : in  std_logic;
		TARGET       : out std_logic;
		SENSOR       : out std_logic;
		A            : out std_logic;
		B            : out std_logic;
		C            : out std_logic;
		START        : out std_logic
	);
end gen_lightgun;

architecture rtl of gen_lightgun is

signal X       : unsigned(8 downto 0);
signal Y       : unsigned(8 downto 0);
signal X_MAX   : unsigned(8 downto 0);
signal Y_MAX   : unsigned(8 downto 0);
signal LG_X    : unsigned(8 downto 0);
signal LG_Y    : unsigned(8 downto 0);
signal HBL_D   : std_logic;
signal VBL_D   : std_logic;
signal SENSOR_DELAY : std_logic_vector(9 downto 0);

begin

-- H and V counters
process( RST_N, CLK )
begin
	if RST_N = '0' then
		X <= (others => '0');
		Y <= (others => '0');
		X_MAX <= (others => '0');
		Y_MAX <= (others => '0');
	elsif rising_edge(CLK) then
		if CE_PIX = '1' then
			VBL_D <= VBL;
			HBL_D <= HBL;
			if VBL = '1' then
				X <= (others => '0');
				Y <= (others => '0');
				if VBL_D = '0' and Y > Y_MAX then
					Y_MAX <= Y - 1;
				end if;
			elsif HBL = '1' then
				X <= (others => '0');
				if HBL_D = '0' then
					Y <= Y + 1;
					if X > X_MAX then
						X_MAX <= X - 1;
					end if;
				end if;
			else
				X <= X + 1;
			end if;
		end if;
	end if;

end process;

C <= '0';

-- Mouse
process( RST_N, CLK )
variable new_x: unsigned(9 downto 0);
variable new_y: unsigned(9 downto 0);
begin
	if RST_N = '0' then
		LG_X <= (others => '0');
		LG_Y <= (others => '0');
		A <= '0';
		B <= '0';
		START <= '0';
	elsif rising_edge(CLK) then
		new_x := '0'&LG_X;
		new_y := '0'&LG_Y;
		if mouse_strobe = '1' then
			A <= mouse_flags(0);
			B <= mouse_flags(1);
			START <= mouse_flags(2);
			if mouse_flags(5) = '1' then
				new_y := new_y + unsigned(not(mouse_y));
				if new_y > Y_MAX then
					new_y := '0'&Y_MAX;
				end if;
			else
				new_y := new_y - unsigned(mouse_y);
				if new_y(9) = '1' then
					new_y := (others=>'0');
				end if;
			end if;
			if mouse_flags(4) = '1' then
				new_x := new_x - unsigned(not(mouse_x));
				if new_x(9) = '1' then
					new_x := (others=>'0');
				end if;
			else
				new_x := new_x + unsigned(mouse_x);
				if new_x > X_MAX then
					new_x := '0'&X_MAX;
				end if;
			end if;
		end if;
		if new_y < 8 then
			new_y := "00"&x"08";
		end if;
		LG_X <= new_x(8 downto 0);
		LG_Y <= new_y(8 downto 0);
	end if;
end process;

-- Crosshair
process( RST_N, CLK )
variable x_diff: unsigned(8 downto 0);
variable y_diff: unsigned(8 downto 0);
variable x_diff1: unsigned(8 downto 0);
variable y_diff1: unsigned(8 downto 0);
begin
	if RST_N = '0' then
		TARGET <= '0';
	elsif rising_edge(CLK) then
		if CE_PIX = '1' then
			x_diff  := X - LG_X;
			x_diff1 := x_diff - 1;
			y_diff  := Y - LG_Y;
			y_diff1 := y_diff - 1;
			if HBL = '0' and VBL = '0' and
         ((LG_X = X and (y_diff(8 downto 3) = 0 or std_logic_vector(y_diff1(8 downto 3)) = "111111")) or
         (LG_Y = Y and (x_diff(8 downto 3) = 0 or std_logic_vector(x_diff1(8 downto 3)) = "111111")))
			then
				TARGET <= '1';
			else
				TARGET <= '0';
			end if;
		end if;
	end if;
end process;

-- Sensor output
process( RST_N, CLK )
begin
	if RST_N = '0' then
		SENSOR_DELAY <= (others => '0');
		SENSOR <= '0';
	elsif rising_edge(CLK) then
		if SENSOR_DELAY /= 0 then
			SENSOR_DELAY <= SENSOR_DELAY - 1;
			if SENSOR_DELAY = 32 then
				SENSOR <= '1';
			end if;
		else
			SENSOR <= '0';
		end if;
		if HBL = '0' and VBL = '0' and LG_X = X and LG_Y = Y then
			if JUSTIFIER = '1' then
				SENSOR_DELAY <= "01"&x"FF";
			else
				SENSOR_DELAY <= (others => '1');
			end if;
		end if;
	end if;
end process;

end rtl;
