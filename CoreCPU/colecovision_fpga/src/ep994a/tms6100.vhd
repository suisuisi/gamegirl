----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 	GreyRogue
-- 
-- Create Date:    2018/05/19 
-- Design Name: 
-- Module Name:    tms6100 - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_MISC.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

entity tms6100 IS
	port
	(
		reset   : in STD_LOGIC;
		clk_i   : in STD_LOGIC;
		ce_n_i  : in STD_LOGIC;
		add1_i  : in STD_LOGIC;
		add2_i  : in STD_LOGIC;
		add4_i  : in STD_LOGIC;
		add8_i  : in STD_LOGIC;
		add8_o  : out STD_LOGIC;
		m0_i    : in STD_LOGIC;
		m1_i    : in STD_LOGIC;
		re_o    : out STD_LOGIC;
		addr_o  : out STD_LOGIC_VECTOR (14 downto 0); -- 2x chips
		data_i  : in STD_LOGIC_VECTOR (7 downto 0)
	);
end tms6100;

architecture tms6100_Behavioral of tms6100 is
	signal addr      : std_logic_vector(19 downto 0);
	signal databit   : std_logic_vector(7 downto 0);
	signal branch_hi : std_logic_vector(5 downto 0);
	signal loading   : std_logic_vector(3 downto 0);
	signal branching : std_logic;
	signal add_all   : std_logic_vector(3 downto 0);
	signal last_m0   : std_logic;

begin

	addr_o <= addr(14 downto 0);
	add_all <= add8_i & add4_i & add2_i & add1_i;
	
	process(clk_i, reset)
	variable k : std_logic;
	begin
		if reset = '1' then
			addr <= (others => '0');
			databit <= x"80";
			loading <= x"0";
			branching <= '0';
			re_o <= '0';
			last_m0 <= '0';
		elsif rising_edge(clk_i) and (ce_n_i='0') then
			re_o <= '0';
			last_m0 <= m0_i;
			if (branching='1') then
				addr <= addr(19 downto 14) & branch_hi & data_i;
				branching <= '0';
				re_o <= '1';
			elsif ((m0_i='1') and (m1_i='1')) then
				branching <= '1';
				branch_hi <= data_i(5 downto 0);
			elsif m1_i='1' then
			   case loading is
					when x"0" =>
						addr <= addr(19 downto 4) & add_all;
						loading <= x"1";
					when x"1" =>
						addr <= addr(19 downto 8) & add_all & addr(3 downto 0);
						loading <= x"2";
					when x"2" =>
						addr <= addr(19 downto 12) & add_all & addr(7 downto 0);
						loading <= x"3";
					when x"3" =>
						addr <= addr(19 downto 16) & add_all & addr(11 downto 0);
						loading <= x"4";
					when x"4" =>
						addr <= "00" & add_all(1 downto 0) & addr(15 downto 0);
						loading <= x"5";
					when others =>
						addr <= addr;
				end case;
			elsif (last_m0='0' and m0_i='1' and loading/=x"0") then
				re_o <= '1';
				loading <= x"0";
				databit <= x"80";
			elsif (last_m0='0' and m0_i='1' and addr<x"08000") then --2x chips
				add8_o <= or_reduce(databit and data_i);
				if (databit(0) = '1') then
					addr <= std_logic_vector(unsigned(addr) + to_unsigned(1, addr'length));
					re_o <= '1';
				end if;
				databit <= databit(0) & databit(7 downto 1);
			end if;
		end if;
	end process;

end tms6100_Behavioral;

