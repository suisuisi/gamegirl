-- Copyright (c) 2010 Gregory Estrade (greg@torlus.com)
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

entity gen_ctrl is
	port(
		RST_N  : in  std_logic;
		CLK    : in  std_logic;

		-- controller port pins
		DAT    : in  std_logic_vector(7 downto 0);
		DOUT   : out std_logic_vector(7 downto 0);
		CTL    : in  std_logic_vector(7 downto 0); -- output enable

		J3BUT  : in  std_logic;
		SWAP_Y : in  std_logic;

		UP     : in  std_logic;
		DOWN   : in  std_logic;
		LEFT   : in  std_logic;
		RIGHT  : in  std_logic;
		A      : in  std_logic;
		B      : in  std_logic;
		C      : in  std_logic;
		START  : in  std_logic;
		MODE   : in  std_logic;
		X      : in  std_logic;
		Y      : in  std_logic;
		Z      : in  std_logic;

		LG_SEL     : in  std_logic_vector(1 downto 0);
		LG_SENSOR  : in std_logic;
		LG_A       : in  std_logic;
		LG_B       : in  std_logic;
		LG_C       : in  std_logic;
		LG_START   : in std_logic;
		LG_SENSOR2 : in std_logic;
		LG_A2      : in  std_logic;
		LG_START2  : in std_logic;

		MSEL   : in  std_logic;
		mouse_x: in  std_logic_vector(7 downto 0);
		mouse_y: in  std_logic_vector(7 downto 0);
		mouse_flags: in std_logic_vector(7 downto 0);
		mouse_strobe: in std_logic

	);
end gen_ctrl;

architecture rtl of gen_ctrl is

signal J_UP              : std_logic;
signal J_DOWN            : std_logic;
signal TH                : std_logic;
signal TH_D              : std_logic;
signal TR                : std_logic;
signal TR_D              : std_logic;
signal TL                : std_logic;
signal JCNT              : integer range 0 to 3;
signal JTMR              : integer range 0 to 129000;
signal MSTATE            : std_logic_vector(3 downto 0);
signal MOUSE             : std_logic_vector(4 downto 0);
signal MSTROB            : std_logic;
signal MACKDELAY	       : integer;
signal MOUSE_Y_ADJ       : std_logic_vector(8 downto 0);
signal MOUSE_FLAGS_ADJ   : std_logic_vector(7 downto 0);
signal mouse_x_latch     : std_logic_vector(7 downto 0);
signal mouse_y_latch     : std_logic_vector(7 downto 0);
signal mouse_flags_latch : std_logic_vector(7 downto 0);

signal mouse_x_latch_d   : std_logic_vector(7 downto 0);
signal mouse_y_latch_d   : std_logic_vector(7 downto 0);
signal mouse_flags_latch_d: std_logic_vector(7 downto 0);

signal MTH               : std_logic;
signal JDO               : std_logic_vector(2 downto 0);
begin

TH <= DAT(6) or not CTL(6);
TR <= DAT(5) or not CTL(5);
TL <= DAT(4) or not CTL(4);

J_UP <= UP when SWAP_Y = '0' else DOWN;
J_DOWN <= DOWN when SWAP_Y = '0' else UP;
MOUSE_Y_ADJ <= mouse_flags(5) & mouse_y when SWAP_Y = '0' else (not mouse_flags(5) & not mouse_y) + 1;
MOUSE_FLAGS_ADJ <= mouse_flags(7 downto 6) & MOUSE_Y_ADJ(8) & mouse_flags(4 downto 0);

process( CLK )
begin
	if rising_edge(CLK) then
		TH_D <= TH;
		TR_D <= TR;
	end if;
end process;

process( RST_N, CLK )
begin
	if RST_N = '0' then
		DOUT <= (others => '1');

		JCNT <= 0;
		JTMR <= 0;

	elsif rising_edge(CLK) then
		if J3BUT = '0' then
			-- state reset timer for 6 button controller
			-- about 1.5ms
			if(JTMR > 90000) then
				JCNT <= 0;
			else
				JTMR <= JTMR + 1;
			end if;

		end if;

		if TH_D = '0' and TH = '1' then JCNT <= JCNT + 1; end if;
		if TH_D /= TH then JTMR <= 0; end if;

		DOUT <= DAT;
		if CTL(7) = '0' then DOUT(7) <= '1'; end if;
		if LG_SEL = "01" then -- Menacer
			if TR_D = '1' and TR = '0' then
				MTH <= '1';
			end if;
			if LG_SENSOR = '1' then
				MTH <= '0';
			end if;
			if CTL(6) = '0' then DOUT(6) <= MTH;   end if;
			if CTL(5) = '0' then DOUT(5) <= '0';   end if;
			if CTL(4) = '0' then DOUT(4) <= '0';   end if;
			if CTL(3) = '0' then DOUT(3) <= (not START) or LG_START; end if;
			if CTL(2) = '0' then DOUT(2) <= (not C) or LG_C;         end if;
			if CTL(1) = '0' then DOUT(1) <= (not A) or LG_A;         end if;
			if CTL(0) = '0' then DOUT(0) <= (not B) or LG_B;         end if;
		elsif LG_SEL(1) = '1' then -- Justifier
			if DAT(6) = '1' then -- TH high
				JDO <= "100";
			elsif TL = '0' then
				-- gun enabled
				if TR = '0' then
					-- blue gun
					JDO(1) <= START and (not LG_START);
					JDO(0) <= A and (not LG_A);
					if LG_SENSOR = '1' then
						JDO(2) <= '0';
					end if;
				elsif LG_SEL(0) = '1' then
					-- pink gun
					JDO(1) <= not LG_START2;
					JDO(0) <= not LG_A2;
					if LG_SENSOR2 = '1' then
						JDO(2) <= '0';
					end if;
				else
					if LG_SENSOR = '1' then
						JDO(2) <= '0';
					end if;
					JDO(1 downto 0) <= "11";
				end if;
			else
				JDO <= "111";
			end if;
			if CTL(6) = '0' then DOUT(6) <= JDO(2); end if;
			if CTL(5) = '0' then DOUT(5) <= '1'; end if;
			if CTL(4) = '0' then DOUT(4) <= '1'; end if;
			if CTL(3) = '0' then DOUT(3) <= '0'; end if;
			if CTL(2) = '0' then DOUT(2) <= '0'; end if;
			if CTL(1) = '0' then DOUT(1) <= JDO(1); end if;
			if CTL(0) = '0' then DOUT(0) <= JDO(0); end if;
		elsif MSEL = '0' and DAT(6) = '1' then
			-- joy TH = 1
			if(J3BUT='1' or JCNT/=3) then
				if CTL(5) = '0' then DOUT(5) <= C;       end if;
				if CTL(4) = '0' then DOUT(4) <= B;       end if;
				if CTL(3) = '0' then DOUT(3) <= RIGHT;   end if;
				if CTL(2) = '0' then DOUT(2) <= LEFT;    end if;
				if CTL(1) = '0' then DOUT(1) <= J_DOWN;  end if;
				if CTL(0) = '0' then DOUT(0) <= J_UP;    end if;
			else
				if CTL(5) = '0' then DOUT(5) <= C;       end if;
				if CTL(4) = '0' then DOUT(4) <= B;       end if;
				if CTL(3) = '0' then DOUT(3) <= MODE;    end if;
				if CTL(2) = '0' then DOUT(2) <= X;       end if;
				if CTL(1) = '0' then DOUT(1) <= Y;       end if;
				if CTL(0) = '0' then DOUT(0) <= Z;       end if;
			end if;
		elsif MSEL = '0' then
			-- joy TH = 0
			if(J3BUT='1' or JCNT<2) then
				if CTL(5) = '0' then DOUT(5) <= START;   end if;
				if CTL(4) = '0' then DOUT(4) <= A;       end if;
				if CTL(3) = '0' then DOUT(3) <= '0';     end if;
				if CTL(2) = '0' then DOUT(2) <= '0';     end if;
				if CTL(1) = '0' then DOUT(1) <= J_DOWN;  end if;
				if CTL(0) = '0' then DOUT(0) <= J_UP;    end if;
			elsif (JCNT=2) then
				if CTL(5) = '0' then DOUT(5) <= START;   end if;
				if CTL(4) = '0' then DOUT(4) <= A;       end if;
				if CTL(3) = '0' then DOUT(3) <= '0';     end if;
				if CTL(2) = '0' then DOUT(2) <= '0';     end if;
				if CTL(1) = '0' then DOUT(1) <= '0';     end if;
				if CTL(0) = '0' then DOUT(0) <= '0';     end if;
			else
				if CTL(5) = '0' then DOUT(5) <= START;   end if;
				if CTL(4) = '0' then DOUT(4) <= A;       end if;
				if CTL(3) = '0' then DOUT(3) <= '1';     end if;
				if CTL(2) = '0' then DOUT(2) <= '1';     end if;
				if CTL(1) = '0' then DOUT(1) <= '1';     end if;
				if CTL(0) = '0' then DOUT(0) <= '1';     end if;
			end if;
		else
			-- mouse
			if CTL(4) = '0' then DOUT(4) <= MOUSE(4); end if;
			if CTL(3) = '0' then DOUT(3) <= MOUSE(3); end if;
			if CTL(2) = '0' then DOUT(2) <= MOUSE(2); end if;
			if CTL(1) = '0' then DOUT(1) <= MOUSE(1); end if;
			if CTL(0) = '0' then DOUT(0) <= MOUSE(0); end if;
		end if;
	end if;

end process;

-- Mouse
process( RST_N, CLK )
begin
	if RST_N = '0' then
		MOUSE <= (others => '0');
		MSTATE <= (others =>'0');
		MACKDELAY <= 0;
		MSTROB <= '0';
	elsif rising_edge(CLK) then
		MSTROB <= '0';
		if MSTROB = '1' then
			case MSTATE is
			when "0000" => MOUSE <= "10000";
			when "0001" => MOUSE <= "01011";
			when "0010" => MOUSE(3 downto 0) <= "1111";
			when "0011" => MOUSE(3 downto 0) <= "1111";
			when "0100" => MOUSE(3 downto 0) <= mouse_flags_latch_d(7 downto 4);
			when "0101" => MOUSE(3 downto 0) <= '0' & mouse_flags_latch_d(2 downto 0);
			when "0110" => MOUSE(3 downto 0) <= mouse_x_latch_d(7 downto 4);
			when "0111" => MOUSE(3 downto 0) <= mouse_x_latch_d(3 downto 0);
			when "1000" => MOUSE(3 downto 0) <= mouse_y_latch_d(7 downto 4);
			when "1001" => MOUSE(3 downto 0) <= mouse_y_latch_d(3 downto 0);
			when others => null;
			end case;
		end if;

		if MSTATE = "1001" and MSEL = '1' and TH = '1' and TR = '1' then
			mouse_x_latch <= (others => '0');
			mouse_y_latch <= (others => '0');
			mouse_flags_latch(7 downto 4) <= (others => '0');
		end if;
		if mouse_strobe = '1' then
			mouse_x_latch <= mouse_x;
			mouse_y_latch <= MOUSE_Y_ADJ(7 downto 0);
			mouse_flags_latch <= MOUSE_FLAGS_ADJ;
		end if;
		if MSTATE = "0000" and MSTROB = '1' then
			mouse_x_latch_d <= mouse_x_latch;
			mouse_y_latch_d <= mouse_y_latch;
			mouse_flags_latch_d <= mouse_flags_latch;
		end if;

		if MSEL = '1' then
			if TH = '1' and TR = '1' then
				MSTATE <= "0000";
				MACKDELAY <= 0;
				MSTROB <= '1';
			elsif ((TH_D /= TH) or (TR_D /= TR)) and MSTATE /= "1001" then
				MSTATE <= MSTATE + 1;
				MACKDELAY <= 500;
				MSTROB <= '1';
			end if;
		end if;

		if MACKDELAY /= 0 then
			MACKDELAY <= MACKDELAY - 1;
			if MACKDELAY = 1 then
				MOUSE(4) <= not MOUSE(4);
			end if;
		end if;
	end if;
end process;

end rtl;
