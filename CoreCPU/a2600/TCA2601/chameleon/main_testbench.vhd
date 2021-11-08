library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.all;

entity main_testbench is
end entity main_testbench;

architecture test of main_testbench is

	signal clk8 : std_logic := '0';
	signal dotclock_n : std_logic := '0';
	signal romlh_n : std_logic := '0';
	signal ioef_n : std_logic := '0';
	signal freeze_n : std_logic := '0';
	signal spi_miso : std_logic := '0';
	signal mmc_cd_n : std_logic := '0';
	signal mmc_wp : std_logic := '0';
	signal mux_clk : std_logic := '0';
	signal mux : unsigned(3 downto 0) := (others => '0');
	signal mux_d : unsigned(3 downto 0) := (others => '0');
	signal mux_q : unsigned(3 downto 0) := (others => '0');
	signal usart_tx : std_logic := '0';
	signal usart_clk : std_logic := '0';
	signal usart_rts : std_logic := '0';
	signal usart_cts : std_logic := '0';
	signal red : unsigned(4 downto 0) := (others => '0');
	signal grn : unsigned(4 downto 0) := (others => '0');
	signal blu : unsigned(4 downto 0) := (others => '0');
	signal nHSync : std_logic := '0';
	signal nVSync : std_logic := '0';
	signal sigmaL : std_logic := '0';
	signal sigmaR : std_logic := '0';

begin
	
	main_inst: entity main 
		port map(
			clk8 => clk8,
			dotclock_n => dotclock_n,
			romlh_n => romlh_n,
			ioef_n => ioef_n,
			freeze_n => freeze_n,
			spi_miso => spi_miso,
			mmc_cd_n => mmc_cd_n,
			mmc_wp => mmc_wp,
			mux_clk => mux_clk,
			mux => mux,
			mux_d => mux_d,
			mux_q => mux_q,
			usart_tx => usart_tx,
			usart_clk => usart_clk,
			usart_rts => usart_rts,
			usart_cts => usart_cts,
			red => red,
			grn => grn,
			blu => blu,
			nHSync => nHSync,
			nVSync => nVSync,
			sigmaL => sigmaL,
			sigmaR => sigmaR
		);

	process
	begin
		-- 50 MHz clock
		while true loop
			wait for 20 ns; clk8 <= not clk8;
		end loop;

		-- show simulation end
		assert false report "no failure, simulation successful" severity failure;
		
	end process;
	

end architecture test;
