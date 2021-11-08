----------------------------------------------------------------------------------
-- tispeechsyn.vhd
--
-- Implementation of the TI Speech Synthesizer.
-- The module is not 100% compatible with the orignal design.
--
-- This file is part of the ep994a design, a TI-99/4A clone 
-- designed by Erik Piehl in October 2016.
-- Erik Piehl, Kauniainen, Finland, speccery@gmail.com
--
-- This is copyrighted software.
-- Please see the file LICENSE for license terms. 
--
-- NO WARRANTY, THE SOURCE CODE IS PROVIDED "AS IS".
-- THE SOURCE IS PROVIDED WITHOUT ANY GUARANTEE THAT IT WILL WORK 
-- FOR ANY PARTICULAR USE. IN NO EVENT IS THE AUTHOR LIABLE FOR ANY 
-- DIRECT OR INDIRECT DAMAGE CAUSED BY THE USE OF THE SOFTWARE.
-----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

use work.tms5220;
use work.tms6100;

entity tispeechsyn is
	port
	(
		model     : in STD_LOGIC_VECTOR (1 downto 0);
		reset_n_i : in STD_LOGIC;
		clk_i     : in STD_LOGIC;
		addr_i    : in STD_LOGIC_VECTOR (15 downto 0);
		data_i    : in STD_LOGIC_VECTOR (7 downto 0);
		data_o    : out STD_LOGIC_VECTOR (7 downto 0);
		mem_n_i   : in STD_LOGIC;
		dbin_i    : in STD_LOGIC;
		ready_o   : out STD_LOGIC;
		--int_n_o   : out STD_LOGIC_VECTOR; --nc
		aout_o     : out signed(7 downto 0);
		
		sr_re_o   : out STD_LOGIC;
		sr_addr_o : out STD_LOGIC_VECTOR (14 downto 0);  --Get ROM data from elsewhere
		sr_data_i : in STD_LOGIC_VECTOR (7 downto 0)
	);
end tispeechsyn;

architecture tispeechsyn_Behavioral of tispeechsyn is

  signal add1          : std_logic;
  signal add2          : std_logic;
  signal add4          : std_logic;
  signal add8          : std_logic;
  signal add8r         : std_logic;
  signal m0            : std_logic;
  signal m1            : std_logic;
  signal rs_n_o        : std_logic;
  signal ws_n_o        : std_logic;
  signal ready_n       : std_logic;

begin
	ready_o <= not ready_n;
  -----------------------------------------------------------------------------
  -- tms5220
  -----------------------------------------------------------------------------
  tms5220_b : tms5220
    port map (
		model     => model,
		reset     => not reset_n_i,
		clk_i     => clk_i,
		ce_n_i    => '0',--not clk_i,
		rs_n_i    => rs_n_o,
		ws_n_i    => ws_n_o,
		add1_o    => add1,
		add2_o    => add2,
		add4_o    => add4,
		add8_o    => add8,
		add8_i    => add8r,
		m0_o      => m0,
		m1_o      => m1,
		data_i    => data_i,
		data_o    => data_o,
		ready_n_o => ready_n,
		int_n_o   => open,
		aout_o    => aout_o
    );

  -----------------------------------------------------------------------------
  -- tms6100
  -----------------------------------------------------------------------------
  tms6100_b : tms6100
    port map (
		reset     => not reset_n_i,
		clk_i     => clk_i,
		ce_n_i    => '0',--not clk_i,
		add1_i    => add1,
		add2_i    => add2,
		add4_i    => add4,
		add8_i    => add8,
		add8_o    => add8r,
		m0_i      => m0,
		m1_i      => m1,
		re_o      => sr_re_o,
		addr_o    => sr_addr_o,
		data_i    => sr_data_i
    );

	process(clk_i, reset_n_i)
	begin
		if reset_n_i = '0' then
			rs_n_o <= '1';
			ws_n_o <= '1';
		elsif rising_edge(clk_i) then
			--reset_n_i already 1;
			rs_n_o <= '1';
			ws_n_o <= '1';
			if    (addr_i(15 downto 10)=b"100100" and addr_i(0)='0' and mem_n_i='0' and dbin_i='1') then
				rs_n_o <= '0';
			elsif (addr_i(15 downto 10)=b"100101" and addr_i(0)='0' and mem_n_i='0' and dbin_i='0') then
				ws_n_o <= '0';
			end if;
		end if;
	end process;

end tispeechsyn_Behavioral;

