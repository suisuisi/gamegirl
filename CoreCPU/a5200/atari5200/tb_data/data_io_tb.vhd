library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;
  use ieee.std_logic_textio.all;

library std_developerskit ; -- used for to_string
--  use std_developerskit.std_iopak.all;

entity data_io_tb is
end;

architecture rtl of data_io_tb is

  constant CLK_A_PERIOD : time := 1 us / (1.79*32);

  signal CLK_A : std_logic;

  signal reset_n : std_logic;

  signal spi_clk : std_logic;
  signal spi_ss_io : std_logic_vector(1 downto 0);
  signal spi_miso : std_logic;
  signal spi_mosi : std_logic;

  signal request : std_logic;
  signal write : std_logic;
  signal ready : std_logic;
  signal sector : std_logic_vector(23 downto 0);

  signal addr : std_logic_vector(8 downto 0);
  signal data_out : std_logic_vector(7 downto 0);
  signal data_in : std_logic_vector(7 downto 0);
  signal wr_en : std_logic;

  signal spi_enable : std_logic;
  signal spi_tx_data : std_logic_vector(7 downto 0);
  signal spi_rx_data : std_logic_vector(7 downto 0);
  signal spi_busy : std_logic;

  signal spi_addr : integer;

begin
	p_clk_gen_a : process
	begin
	clk_a <= '1';
	wait for CLK_A_PERIOD/2;
	clk_a <= '0';
	wait for CLK_A_PERIOD - (CLK_A_PERIOD/2 );
	end process;

	reset_n <= '0', '1' after 1000ns;


	spi_master1 : entity work.spi_master
		generic map(slaves=>2,d_width=>8)
		port map (clock=>clk_a,reset_n=>reset_n,enable=>spi_enable,cpol=>'0',cpha=>'0',cont=>'0',clk_div=>4,addr=>spi_addr,
		          tx_data=>spi_tx_data, miso=>spi_miso,sclk=>spi_clk,ss_n=>spi_ss_io,mosi=>spi_mosi,
					 rx_data=>spi_rx_data,busy=>spi_busy);

	spi_fake : process
 	variable type_conv : std_logic_vector(8 downto 0);
	begin
	spi_enable <= '0';
	spi_addr <= 0;
	wait for 1500us;

	spi_tx_data <= x"50";
	spi_enable <= '1';
	wait for CLK_A_PERIOD*2;
	spi_tx_data <= x"FF";
	spi_enable <= '0';
	wait until spi_busy='0';

	for i in 0 to 3 loop
		spi_tx_data <= x"ff";
		spi_enable <= '1';
		wait for CLK_A_PERIOD*2;
		spi_tx_data <= x"FF";
		spi_enable <= '0';
		wait until spi_busy='0';
	end loop;

	spi_addr <= 1;
	spi_tx_data <= x"ff";
	spi_enable <= '1';
	wait for CLK_A_PERIOD*2;
	spi_tx_data <= x"FF";
	spi_enable <= '0';
	wait until spi_busy='0';
	spi_addr <= 0;
	wait for 20us;

	spi_tx_data <= x"51";
	spi_enable <= '1';
	wait for CLK_A_PERIOD*2;
	spi_tx_data <= x"FF";
	spi_enable <= '0';
	wait until spi_busy='0';

	for i in 0 to 511 loop
		type_conv := std_logic_vector(to_unsigned(i,9));
		spi_tx_data <= type_conv(7 downto 0);
		spi_enable <= '1';
		wait for CLK_A_PERIOD*4;
		spi_tx_data <= x"FF";
		spi_enable <= '0';
		wait until spi_busy='0';
	end loop;

	spi_tx_data <= x"ff";
	spi_enable <= '1';
	wait for CLK_A_PERIOD*2;
	spi_tx_data <= x"FF";
	spi_enable <= '0';
	wait until spi_busy='0';

	-- NEXT

	spi_addr <= 1;
	spi_tx_data <= x"ff";
	spi_enable <= '1';
	wait for CLK_A_PERIOD*2;
	spi_tx_data <= x"FF";
	spi_enable <= '0';
	wait until spi_busy='0';
	spi_addr <= 0;
	wait for 20us;

	spi_tx_data <= x"50";
	spi_enable <= '1';
	wait for CLK_A_PERIOD*2;
	spi_tx_data <= x"FF";
	spi_enable <= '0';
	wait until spi_busy='0';

	for i in 0 to 3 loop
		spi_tx_data <= x"ff";
		spi_enable <= '1';
		wait for CLK_A_PERIOD*2;
		spi_tx_data <= x"FF";
		spi_enable <= '0';
		wait until spi_busy='0';
	end loop;

	spi_addr <= 1;
	spi_tx_data <= x"ff";
	spi_enable <= '1';
	wait for CLK_A_PERIOD*2;
	spi_tx_data <= x"FF";
	spi_enable <= '0';
	wait until spi_busy='0';
	spi_addr <= 0;
	wait for 20us;

	spi_tx_data <= x"51";
	spi_enable <= '1';
	wait for CLK_A_PERIOD*2;
	spi_tx_data <= x"FF";
	spi_enable <= '0';
	wait until spi_busy='0';

	for i in 0 to 511 loop
		type_conv := std_logic_vector(to_unsigned(511-i,9));
		spi_tx_data <= type_conv(7 downto 0);
		spi_enable <= '1';
		wait for CLK_A_PERIOD*4;
		spi_tx_data <= x"FF";
		spi_enable <= '0';
		wait until spi_busy='0';
	end loop;

	spi_tx_data <= x"ff";
	spi_enable <= '1';
	wait for CLK_A_PERIOD*2;
	spi_tx_data <= x"FF";
	spi_enable <= '0';
	wait until spi_busy='0';

	-- NEXT - WRITE...

	spi_addr <= 1;
	spi_tx_data <= x"ff";
	spi_enable <= '1';
	wait for CLK_A_PERIOD*2;
	spi_tx_data <= x"FF";
	spi_enable <= '0';
	wait until spi_busy='0';
	spi_addr <= 0;
	wait for 20us;

	spi_tx_data <= x"50";
	spi_enable <= '1';
	wait for CLK_A_PERIOD*2;
	spi_tx_data <= x"FF";
	spi_enable <= '0';
	wait until spi_busy='0';

	for i in 0 to 3 loop
		spi_tx_data <= x"ff";
		spi_enable <= '1';
		wait for CLK_A_PERIOD*2;
		spi_tx_data <= x"FF";
		spi_enable <= '0';
		wait until spi_busy='0';
	end loop;

	spi_addr <= 1;
	spi_tx_data <= x"ff";
	spi_enable <= '1';
	wait for CLK_A_PERIOD*2;
	spi_tx_data <= x"FF";
	spi_enable <= '0';
	wait until spi_busy='0';
	spi_addr <= 0;
	wait for 20us;

	spi_tx_data <= x"52";
	spi_enable <= '1';
	wait for CLK_A_PERIOD*2;
	spi_tx_data <= x"FF";
	spi_enable <= '0';
	wait until spi_busy='0';

	for i in 0 to 511 loop
		spi_tx_data <= x"FF";
		spi_enable <= '1';
		wait for CLK_A_PERIOD*4;
		spi_tx_data <= x"FF";
		spi_enable <= '0';
		wait until spi_busy='0';
	end loop;

	spi_tx_data <= x"ff";
	spi_enable <= '1';
	wait for CLK_A_PERIOD*2;
	spi_tx_data <= x"FF";
	spi_enable <= '0';
	wait until spi_busy='0';

	wait for 100ms;
	
	end process;

	spi_request : process
	begin
	sector <= (others=>'0');
	request <= '0';
	write <= '0';
	wait for 1500us;

	sector <= x"123456";
	request <= '1';
	wait until ready = '1';
	request <= '0';
	wait for CLK_A_PERIOD*20;
	wait until ready = '0';


	sector <= x"654321";
	request <= '1';
	wait until ready = '1';
	request <= '0';
	wait for CLK_A_PERIOD*20;
	wait until ready = '0';

	sector <= x"111111";
	write <= '1';
	wait until ready = '1';
	write <= '0';
	wait for CLK_A_PERIOD*20;
	wait until ready = '0';

	wait for 100ms;
	end process;

	ram : entity work.generic_ram_infer
	generic map
	(
		ADDRESS_WIDTH => 9,
		SPACE => 512,
		DATA_WIDTH => 8
	)
   PORT map
   (
      clock => spi_clk,
      data => data_out,
      address => addr,
      we => wr_en,
      q => data_in
   );

	data_io : entity work.data_io
	PORT MAP
	(
		CLK => spi_clk,
		RESET_n =>reset_n,
		
		-- SPI connection - up to upstream to make miso 'Z' on ss_io going high
	   SPI_CLK => spi_clk,
	   SPI_SS_IO => spi_ss_io(0),
	   SPI_MISO => spi_miso,
	   SPI_MOSI => spi_mosi,
		
		-- Sector access request
		read_request => request,
		write_request => write,
		sector => sector,
		ready => ready,
		
		-- DMA to RAM
		ADDR => addr,
		DATA_OUT => data_out,
		DATA_IN => data_in,
		WR_EN => wr_en
	 );

end rtl;

