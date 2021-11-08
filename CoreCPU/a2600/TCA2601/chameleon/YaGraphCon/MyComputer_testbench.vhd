library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.all;

entity MyComputer_testbench is
end entity MyComputer_testbench;

architecture test of MyComputer_testbench is

	signal clock: std_logic := '0';

begin
	
	MyComputer_instance: entity MyComputer
		port map(
			clk_50mhz => clock,
			VGA_BLUE => open,
			VGA_GREEN => open,
			VGA_HSYNC => open,
			VGA_RED => open,
			VGA_VSYNC => open
		);

	-- create 50 MHz clock
	process
	begin
		while true loop
			wait for 10 ns; clock <= not clock;
		end loop;
	end process;

	process
	begin
		wait for 10 us;

		-- show simulation end
		assert false report "no failure, simulation successful" severity failure;
		
	end process;
	

end architecture test;
