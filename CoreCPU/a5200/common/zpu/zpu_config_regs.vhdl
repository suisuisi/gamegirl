---------------------------------------------------------------------------
-- (c) 2013 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_MISC.all;

ENTITY zpu_config_regs IS
GENERIC
(
	platform : integer := 1; -- So ROM can detect which type of system...
	spi_clock_div : integer := 4; -- Quite conservative by default - probably want to use 1 with 28MHz input clock, 2 for 57MHz input clock, 4 for 114MHz input clock etc
	usb : integer :=0; -- USB host slave instances
	nMHz_clock_div : integer -- divide the nMHz clock by n to get 1MHz
);
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;
	
	POKEY_ENABLE : in std_logic;
	
	ADDR : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
	CPU_DATA_IN : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
	RD_EN : IN STD_LOGIC;
	WR_EN : IN STD_LOGIC;
	
	-- GENERIC INPUT REGS (need to synchronize upstream...)
	IN1 : in std_logic_vector(31 downto 0); 
	IN2 : in std_logic_vector(31 downto 0); 
	IN3 : in std_logic_vector(31 downto 0); 
	IN4 : in std_logic_vector(31 downto 0); 
	
	-- GENERIC OUTPUT REGS
	OUT1 : out  std_logic_vector(31 downto 0); 
	OUT2 : out  std_logic_vector(31 downto 0); 
	OUT3 : out  std_logic_vector(31 downto 0); 
	OUT4 : out  std_logic_vector(31 downto 0); 
	OUT5 : out  std_logic_vector(31 downto 0); 
	OUT6 : out  std_logic_vector(31 downto 0); 
	OUT7 : out  std_logic_vector(31 downto 0); 
	OUT8 : out  std_logic_vector(31 downto 0); 

	-- change clock support
	PLL_WRITE : out std_logic;
	PLL_DATA : out std_logic_vector(31 downto 0);
	PLL_ADDR : out std_logic_vector(7 downto 2);
	
	-- SPI
	SPI_CLK : out std_logic;
	SPI_DO : out std_logic;
	SPI_DI : in std_logic;
	SPI_SELECT0 : out std_logic;
	SPI_SELECT1 : out std_logic;

	-- SD DMA
	sd_addr : out std_logic_vector(15 downto 0);
	sd_data : out std_logic_vector(7 downto 0);
	sd_write : out std_logic;
	
	-- ATARI interface (in future we can also turbo load by directly hitting memory...)
	SIO_DATA_IN  : out std_logic;
	SIO_COMMAND : in std_logic;
	SIO_DATA_OUT : in std_logic;
	SIO_CLK_OUT : in std_logic;
	
	-- CPU interface
	DATA_OUT : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
	PAUSE_ZPU : out std_logic;

	-- 1MHz clock (multiple)
	CLK_nMHz : in std_logic;

	-- USB host
	CLK_USB : in std_logic;

	USBWireVPin :in std_logic_vector(usb-1 downto 0);
	USBWireVMin :in std_logic_vector(usb-1 downto 0);
	USBWireVPout :out std_logic_vector(usb-1 downto 0);
	USBWireVMout :out std_logic_vector(usb-1 downto 0);
	USBWireOE_n :out std_logic_vector(usb-1 downto 0);

	-- I2C (400k)
	i2c0_sda_in : in std_logic;
	i2c0_scl_in : in std_logic;
	i2c0_sda_wen : out std_logic;
	i2c0_scl_wen : out std_logic;
	
	i2c1_sda_in : in std_logic;
	i2c1_scl_in : in std_logic;
	i2c1_sda_wen : out std_logic;
	i2c1_scl_wen : out std_logic		
);
END zpu_config_regs;

ARCHITECTURE vhdl OF zpu_config_regs IS

	component usbHostCyc2Wrap_usb1t11
	port (
		clk_i :in std_logic;
		rst_i :in std_logic;
		address_i : in std_logic_vector(7 downto 0);
		data_i : in std_logic_vector(7 downto 0);
		data_o : out std_logic_vector(7 downto 0);
		we_i :in std_logic;
		strobe_i :in std_logic;
		ack_o :out std_logic;
		irq :out std_logic;
		usbClk :in std_logic;
	
		USBWireVPin :in std_logic;
		USBWireVMin :in std_logic;
		USBWireVPout :out std_logic;
		USBWireVMout :out std_logic;
		USBWireOE_n :out std_logic;
		USBFullSpeed :out std_logic
	);
	end component;

	function vectorize(s: std_logic) return std_logic_vector is
	variable v: std_logic_vector(0 downto 0);
	begin
		v(0) := s;
		return v;
	end;
	
	signal device_decoded : std_logic_vector(7 downto 0);	
	signal device_wr_en : std_logic_vector(7 downto 0);	
	signal device_rd_en : std_logic_vector(7 downto 0);	
	signal addr_decoded : std_logic_vector(31 downto 0);	
	
	signal out1_next : std_logic_vector(31 downto 0);
	signal out1_reg : std_logic_vector(31 downto 0);
	signal out2_next : std_logic_vector(31 downto 0);
	signal out2_reg : std_logic_vector(31 downto 0);
	signal out3_next : std_logic_vector(31 downto 0);
	signal out3_reg : std_logic_vector(31 downto 0);
	signal out4_next : std_logic_vector(31 downto 0);
	signal out4_reg : std_logic_vector(31 downto 0);
	signal out5_next : std_logic_vector(31 downto 0);
	signal out5_reg : std_logic_vector(31 downto 0);
	signal out6_next : std_logic_vector(31 downto 0);
	signal out6_reg : std_logic_vector(31 downto 0);
	signal out7_next : std_logic_vector(31 downto 0);
	signal out7_reg : std_logic_vector(31 downto 0);
	signal out8_next : std_logic_vector(31 downto 0);
	signal out8_reg : std_logic_vector(31 downto 0);
	
	signal spi_miso : std_logic;
	signal spi_mosi : std_logic;
	signal spi_busy : std_logic;	
	signal spi_enable : std_logic;
	signal spi_chip_select : std_logic_vector(1 downto 0);
	signal spi_clk_out : std_logic;
	
	signal spi_tx_data : std_logic_vector(7 downto 0);
	signal spi_rx_data : std_logic_vector(7 downto 0);
	
	signal spi_select_next : std_logic_vector(1 downto 0);
	signal spi_select_reg : std_logic_vector(1 downto 0);
	signal spi_slave_next : std_logic;
	signal spi_slave_reg : std_logic;
	signal spi_slave_reg_integer : integer;
	signal spi_speed_next : std_logic_vector(7 downto 0);
	signal spi_speed_reg : std_logic_vector(7 downto 0);
	signal spi_speed_reg_integer : integer;

	signal uart_data_out : std_logic_vector(15 downto 0);
	
	signal pause_next : std_logic_vector(31 downto 0);
	signal pause_reg : std_logic_vector(31 downto 0);
	signal paused_next : std_logic;
	signal paused_reg : std_logic;

	signal timer_next : std_logic_vector(31 downto 0);
	signal timer_reg : std_logic_vector(31 downto 0);

	signal timer2_next : std_logic_vector(31 downto 0);
	signal timer2_reg : std_logic_vector(31 downto 0);
	signal timer2_threshold_next : std_logic_vector(31 downto 0);
	signal timer2_threshold_reg : std_logic_vector(31 downto 0);

	signal spi_dma_addr_next : std_logic_vector(15 downto 0);
	signal spi_dma_addrend_next : std_logic_vector(15 downto 0);
	signal spi_dma_wr : std_logic;
	signal spi_dma_next : std_logic;
	signal spi_dma_addr_reg : std_logic_vector(15 downto 0);
	signal spi_dma_addrend_reg : std_logic_vector(15 downto 0);
	signal spi_dma_reg : std_logic;

	signal spi_clk_div_integer : integer;
	signal spi_slave_integer : integer;

	subtype usb_data_type is std_logic_vector(7 downto 0);
	type usb_data_array is array(0 to USB-1) of usb_data_type;
	signal usb_data : usb_data_array;

	signal data_out_regs : std_logic_vector(31 downto 0);
	signal data_out_mux : std_logic_vector(31 downto 0);

	signal i2c0_busy_next : std_logic;
	signal i2c0_busy_reg : std_logic;
	signal i2c0_read_data : std_logic_vector(7 downto 0);
	signal i2c0_write_next  : std_logic;
	signal i2c0_write_reg  : std_logic;
	signal i2c0_write_data_reg : std_logic_vector(15 downto 0);
	signal i2c0_write_data_next : std_logic_vector(15 downto 0);
	signal i2c0_error  : std_logic;

	signal i2c1_busy_next : std_logic;
	signal i2c1_busy_reg : std_logic;
	signal i2c1_read_data : std_logic_vector(7 downto 0);
	signal i2c1_write_next  : std_logic;
	signal i2c1_write_reg  : std_logic;
	signal i2c1_write_data_reg : std_logic_vector(15 downto 0);
	signal i2c1_write_data_next : std_logic_vector(15 downto 0);
	signal i2c1_error  : std_logic;

	-- Create 1MHz toggle from 48MHZ USB clock
	signal tick_count_next : std_logic_vector(7 downto 0);
	signal tick_count_reg : std_logic_vector(7 downto 0);
	signal tick_toggle_next : std_logic;
	signal tick_toggle_reg : std_logic;
	signal tick_toggle_safe_reg : std_logic;
	signal tick_toggle_safe_next : std_logic;
	signal tick_us : std_logic;

	-- pokey style 17-bit LSFR, but faster
	signal rand_out : std_logic_vector(7 downto 0);
begin
	-- register
	process(clk,reset_n)
	begin
		if (reset_n='0') then
			out1_reg <= (others=>'0');
			out2_reg <= (others=>'0');
			out3_reg <= (others=>'0');
			out4_reg <= (others=>'0');
			out5_reg <= (others=>'0');
			out6_reg <= (others=>'0');
			out7_reg <= (others=>'0');
			out8_reg <= (others=>'0');
			
			spi_slave_reg <= '1';
			spi_select_reg <= (others=>'1');
			spi_speed_reg <= X"80";

			pause_reg <= (others=>'0');
			paused_reg <= '0';

			timer_reg <= (others=>'0');
			timer2_reg <= (others=>'0');
			timer2_threshold_reg <= (others=>'0');
			tick_toggle_safe_reg <= '0';

			spi_dma_addr_reg <= (others=>'0');
			spi_dma_addrend_reg <= (others=>'0');
			spi_dma_reg <= '0';

			i2c0_busy_reg <= '0';
			i2c0_write_reg <= '0';
			i2c0_write_data_reg <= (others=>'0');
			i2c1_busy_reg <= '0';
			i2c1_write_reg <= '0';
			i2c1_write_data_reg <= (others=>'0');
		elsif (clk'event and clk='1') then	
			out1_reg <= out1_next;
			out2_reg <= out2_next;
			out3_reg <= out3_next;
			out4_reg <= out4_next;
			out5_reg <= out5_next;
			out6_reg <= out6_next;
			out7_reg <= out7_next;
			out8_reg <= out8_next;
			
			spi_slave_reg <= spi_slave_next;
			spi_select_reg <= spi_select_next;
			spi_speed_reg <= spi_speed_next;

			pause_reg <= pause_next;
			paused_reg <= paused_next;

			timer_reg <= timer_next;
			timer2_reg <= timer2_next;
			timer2_threshold_reg <= timer2_threshold_next;
			tick_toggle_safe_reg <= tick_toggle_safe_next;

			spi_dma_addr_reg <= spi_dma_addr_next;
			spi_dma_addrend_reg <= spi_dma_addrend_next;
			spi_dma_reg <= spi_dma_next;

			i2c0_busy_reg <= i2c0_busy_next;
			i2c0_write_reg <= i2c0_write_next;
			i2c0_write_data_reg <= i2c0_write_data_next;
			i2c1_busy_reg <= i2c1_busy_next;
			i2c1_write_reg <= i2c1_write_next;
			i2c1_write_data_reg <= i2c1_write_data_next;
		end if;
	end process;

	-- register (tick clk)
	process(CLK_nMHz,reset_n) 
	begin
		if (reset_n='0') then
			tick_count_reg <= (others=>'0');
			tick_toggle_reg <= '0';
		elsif (CLK_nMHz'event and CLK_nMHz='1') then	
			tick_count_reg <= tick_count_next;
			tick_toggle_reg <= tick_toggle_next;
		end if;
	end process;

	-- create exact 1MHz
	process(tick_count_reg, tick_toggle_reg)
	begin
		tick_count_next <= std_logic_vector(unsigned(tick_count_reg)-1);
		tick_toggle_next <= tick_toggle_reg;
		if (or_reduce(tick_count_reg)='0') then
			tick_toggle_next <= not(tick_toggle_reg);
			tick_count_next <= std_logic_vector(to_unsigned(nMHz_clock_div-1,8));
		end if;
	end process;

	tick_toggle_synchronizer : entity work.synchronizer
		port map (clk=>clk, raw=>tick_toggle_reg, sync=>tick_toggle_safe_next);	

	process(tick_toggle_safe_reg, tick_toggle_safe_next)
	begin
		tick_us <= '0';
		if (tick_toggle_safe_reg = tick_toggle_safe_next) then
			tick_us <= '0';
		else
			tick_us <= '1';
		end if;
	end process;	

	-- timer for exact us
	process(timer_reg,tick_us)
	begin
		timer_next <= timer_reg;

		if (tick_us = '1') then
			timer_next <= std_logic_vector(unsigned(timer_reg)+1);
		end if;
	end process;

	process(timer2_reg,timer2_threshold_reg,tick_us)
	begin
		timer2_next <= timer2_reg;

		if (tick_us = '1') then
			timer2_next <= std_logic_vector(unsigned(timer2_reg)+1);
		end if;

		if (timer2_reg >= timer2_threshold_reg) then
			timer2_next <= (others=>'0');
		end if;
	end process;

	-- random result
	poly_17_19_lfsr : entity work.pokey_poly_17_9
		port map(clk=>clk,reset_n=>reset_n,init=>'0',enable=>'1',select_9_17=>'0',bit_out=>open,rand_out=>rand_out);

	-- decode address
	decode_addr : entity work.complete_address_decoder
		generic map(width=>5)
		port map (addr_in=>addr(4 downto 0), addr_decoded=>addr_decoded);

	decode_device : entity work.complete_address_decoder
		generic map(width=>3)
		port map (addr_in=>addr(10 downto 8), addr_decoded=>device_decoded);

	-- spi - for sd card access without bit banging...
	-- 200KHz to start with - probably fine for 8-bit, can up it later after init
	spi_clk_div_integer <= to_integer(unsigned(spi_speed_reg));
	spi_slave_integer <= to_integer(unsigned(vectorize(spi_slave_reg)));
	spi_master1 : entity work.spi_master
		generic map(slaves=>2,d_width=>8)
		port map (clock=>clk,reset_n=>reset_n,enable=>spi_enable,cpol=>'0',cpha=>'0',cont=>'0',clk_div=>spi_clk_div_integer,addr=>spi_slave_integer,
		          tx_data=>spi_tx_data, miso=>spi_miso,sclk=>spi_clk_out,ss_n=>spi_chip_select,mosi=>spi_mosi,
					 rx_data=>spi_rx_data,busy=>spi_busy);

	-- spi-programming model:
	-- reg for write/read
	-- data (send/receive)
	-- busy
	-- speed - 0=400KHz, 1=10MHz? Start with 400KHz then atari800core...
	-- chip select


	 -- TODO: Use real clk freq... Not that important since only used on eclaire for now anyway.
	 i2c_master0 : entity work.i2c_master
	 	generic map(input_clk=>58_000_000, bus_clk=>400_000)
		port map (clk=>clk,reset_n=>reset_n,ena=>i2c0_write_reg,addr=>i2c0_write_data_reg(15 downto 9),rw=>i2c0_write_data_reg(8),data_wr=>i2c0_write_data_reg(7 downto 0),busy=>i2c0_busy_next,data_rd=>i2c0_read_data,ack_error=>i2c0_error,
		sda_in=>i2c0_sda_in,scl_in=>i2c0_scl_in,sda_wen=>i2c0_sda_wen,scl_wen=>i2c0_scl_wen);
	 i2c_master1 : entity work.i2c_master
	 	generic map(input_clk=>58_000_000, bus_clk=>400_000)
		port map (clk=>clk,reset_n=>reset_n,ena=>i2c1_write_reg,addr=>i2c1_write_data_reg(15 downto 9),rw=>i2c1_write_data_reg(8),data_wr=>i2c1_write_data_reg(7 downto 0),busy=>i2c1_busy_next,data_rd=>i2c1_read_data,ack_error=>i2c1_error,
		sda_in=>i2c1_sda_in,scl_in=>i2c1_scl_in,sda_wen=>i2c1_sda_wen,scl_wen=>i2c1_scl_wen);
		
	-- device decode
	-- 0x000 - own regs (0)
	-- 0x100 - uart (1)
	-- 0x200 - usb1 (2)
	-- 0x300 - usb2 (3)
	-- 0x400 - usb3 (4)
	-- 0x500 - usb4 (5)
	-- 0x600 - usb5 (6)
	-- 0x700 - pll  (7)

	device_wr_en <= device_decoded and (wr_en&wr_en&wr_en&wr_en&wr_en&wr_en&wr_en&wr_en);
	device_rd_en <= device_decoded and (rd_en&rd_en&rd_en&rd_en&rd_en&rd_en&rd_en&rd_en);

	-- pll
	PLL_WRITE <= device_wr_en(7);
	PLL_DATA <= cpu_data_in;
	PLL_ADDR <= addr(5 downto 0); -- already shifted
	
	-- simplest uart, running with pokey divisors
	-- can not easily poll frequently enough with zpu when also polling usb
	--pokey_enable/(divisor(e.g. 0x28)+6)/2 = bit rate
	simple_uart_inst : entity work.sio_handler
	PORT  MAP
	(
		CLK => CLK,
		ADDR => addr(4 downto 0),
		CPU_DATA_IN => cpu_data_in(7 downto 0),
		EN => device_rd_en(1),
		WR_EN => device_wr_en(1),
		
		RESET_N => reset_n,

		POKEY_ENABLE => POKEY_ENABLE,
		
		SIO_DATA_IN  => sio_data_in,
		SIO_COMMAND => sio_command,
		SIO_DATA_OUT => sio_data_out,
		SIO_CLK_OUT => sio_clk_out,
		
		-- CPU interface
		DATA_OUT => uart_data_out
	);

	-- USB host
	USBGEN:
	for I in 0 to USB-1 generate
		usbcon : usbHostCyc2Wrap_usb1t11
		port map 
		(
			clk_i => clk,
			rst_i => not(reset_n),
			address_i => addr(7 downto 0),
			data_i => cpu_data_in(7 downto 0),
			data_o => usb_data(I), -- 2D array
			we_i => device_wr_en(I+2),
			strobe_i => device_wr_en(I+2) or device_rd_en(I+2),
			ack_o => open, -- always right away - checked in sim
			irq => open,
			usbClk => CLK_USB,
		
			USBWireVPin => USBWireVPin(I),
			USBWireVMin => USBWireVMin(I),
			USBWireVPout => USBWireVPout(I),
			USBWireVMout => USBWireVMout(I),
			USBWireOE_n => USBWireOE_n(I),
			USBFullSpeed => open
		);
	end generate USBGEN;

	process(device_decoded, data_out_regs, uart_data_out, usb_data)
	begin
		data_out_mux <= (others=>'0');
		if (device_decoded(0) = '1') then
			data_out_mux <= data_out_regs;
		end if;

		if (device_decoded(1) = '1') then
			data_out_mux(15 downto 0) <= uart_data_out;
		end if;

		for I in 0 to USB-1 loop
			if (device_decoded(I+2) = '1') then
				data_out_mux(7 downto 0) <= usb_data(I);
			end if;
		end loop;
	end process;

	-- hardware regs for ZPU
	--
	-- 0-3: GENERIC INPUT (RO)
	-- 4-7: GENERIC OUTPUT (R/W)
	--  8: W:PAUSE, R:Timer (1ms)
	--   9: SPI_DATA
	-- SPI_DATA (DONE) 
	--		W - write data (starts transmission)
	--		R - read data (wait for complete first)
	--  10: SPI_STATE
	-- SPI_STATE/SPI_CTRL (DONE) 
	--    R: 0=busy
	--    W: 0=select_n, speed
	--  11: SIO
	-- SIO
	--    R: 0=CMD
	--  12: TYPE
	-- FPGA board (DONE) 
	--    R(32 bits) 0=DE1
	--  13 : SPI_DMA
	--    W(15 downto 0 = addr),(31 downto 16 = endAddr)
	--  14-15 : GENERIC OUTPUT (R/W)
	--  16    : I2C0 (W=AADD where AA is AAAAAAAR (r=1 is read)), (R=YXDD, where DD(0xff) is data, X(0x100) is busy and Y(0x200) is error)
	--  17    : I2C1 (as above, connection 2)
	--  18    : timer - TODO docs
	--  19    : rand - TODO docs
	--  20-21 : GENERIC OUTPUT (R/W) - TODO reorganise!
				
	-- Writes to registers
	process(cpu_data_in,device_wr_en,addr,addr_decoded, spi_speed_reg, spi_slave_reg, spi_select_reg, out1_reg, out2_reg, out3_reg, out4_reg, out5_reg, out6_reg, out7_reg, out8_reg, pause_reg, spi_dma_addr_reg, spi_dma_addrend_reg, spi_dma_reg, spi_busy, spi_dma_addr_next, i2c0_write_reg, i2c1_write_reg, i2c0_busy_next, i2c0_busy_reg, i2c1_busy_next, i2c1_busy_reg, i2c0_write_data_reg, i2c1_write_data_reg, timer2_threshold_reg, tick_us)
	begin
		spi_speed_next <= spi_speed_reg;
		spi_slave_next <= spi_slave_reg;
		spi_select_next <= spi_select_reg;
		spi_tx_data <= (others=>'0');
		spi_enable <= '0';

		out1_next <= out1_reg;
		out2_next <= out2_reg;
		out3_next <= out3_reg;
		out4_next <= out4_reg;
		out5_next <= out5_reg;
		out6_next <= out6_reg;
		out7_next <= out7_reg;
		out8_next <= out8_reg;

		timer2_threshold_next <= timer2_threshold_reg;

		paused_next <= '0';
		pause_next <= pause_reg;
		if (not(pause_reg = X"00000000")) then
			if (tick_us='1') then
				pause_next <= std_LOGIC_VECTOR(unsigned(pause_reg)-to_unsigned(1,32));
			end if;
			paused_next <= '1';
		end if;

		spi_dma_addr_next <= spi_dma_addr_reg;
		spi_dma_addrend_next <= spi_dma_addrend_reg;
		spi_dma_wr <= '0';
		spi_dma_next <= spi_dma_reg;
		if (spi_dma_reg = '1') then
			paused_next <= '1';

			if (spi_busy = '0') then
				spi_dma_wr <= '1';
				spi_dma_addr_next <= std_logic_vector(unsigned(spi_dma_addr_reg)+to_unsigned(1,16));
				spi_dma_next <= '0';

				if (not(spi_dma_addr_next = spi_dma_addrend_reg)) then
					spi_tx_data <= X"ff";
					spi_enable <= '1';
					spi_dma_next <= '1';
				end if;
			end if;
		end if;

		-- Problem here is the interaction between busy and blocking
		-- When busy immediately unblocks when it needs to wait! TODO
		i2c0_write_next <= i2c0_write_reg;
		i2c0_write_data_next <= i2c0_write_data_reg;
		if (i2c0_write_reg = '1') then
			paused_next <= '1';
			if (i2c0_busy_next = '1' and i2c0_busy_reg = '0') then
				paused_next <= '0';
				i2c0_write_next <= '0';
			end if;
		end if;

		i2c1_write_next <= i2c1_write_reg;
		i2c1_write_data_next <= i2c1_write_data_reg;
		if (i2c1_write_reg = '1') then
			paused_next <= '1';
			if (i2c1_busy_next = '1' and i2c1_busy_reg = '0') then
				paused_next <= '0';
				i2c1_write_next <= '0';
			end if;
		end if;

		if (device_wr_en(0) = '1') then
			if(addr_decoded(4) = '1') then
				out1_next <= cpu_data_in;
			end if;	
			
			if(addr_decoded(5) = '1') then
				out2_next <= cpu_data_in;
			end if;	

			if(addr_decoded(6) = '1') then
				out3_next <= cpu_data_in;
			end if;	

			if(addr_decoded(7) = '1') then
				out4_next <= cpu_data_in;
			end if;	

			if(addr_decoded(14) = '1') then
				out5_next <= cpu_data_in;
			end if;	

			if(addr_decoded(15) = '1') then
				out6_next <= cpu_data_in;
			end if;	

			if(addr_decoded(8) = '1') then
				pause_next <= cpu_data_in;
				paused_next <= '1';
			end if;	

			if(addr_decoded(9) = '1') then
				-- TODO, check overrun?
				spi_tx_data <= cpu_data_in(7 downto 0);
				spi_enable <= '1';
			end if;	

			if(addr_decoded(10) = '1') then
				spi_slave_next <= cpu_data_in(0);
				spi_select_next <= cpu_data_in(2 downto 1);
				if (cpu_data_in(3) = '1') then
					spi_speed_next <= X"80"; -- slow, for init
				else
					spi_speed_next <= std_logic_vector(to_unsigned(spi_clock_div,8)); -- turbo - up to 25MHz for SD, 20MHz for MMC I believe... If 1 then clock is half input, if 2 then clock is 1/4 input etc.
				end if;
			end if;	

			if(addr_decoded(13) = '1') then
				paused_next <= '1';
				spi_dma_addr_next <= cpu_data_in(15 downto 0);
				spi_dma_addrend_next <= cpu_data_in(31 downto 16);

				spi_dma_next <= '1';

				spi_tx_data <= X"ff";
				spi_enable <= '1';
			end if;

			if(addr_decoded(16) = '1') then
				i2c0_write_next <= '1';
				paused_next <= '1';
				i2c0_write_data_next <= cpu_data_in(15 downto 0);
			end if;

			if(addr_decoded(17) = '1') then
				i2c1_write_next <= '1';
				paused_next <= '1';
				i2c1_write_data_next <= cpu_data_in(15 downto 0);
			end if;

			if(addr_decoded(18) = '1') then  --timer2 threshold
				timer2_threshold_next <= cpu_data_in(31 downto 0);
			end if;

			if(addr_decoded(20) = '1') then
				out7_next <= cpu_data_in;
			end if;	

			if(addr_decoded(21) = '1') then
				out8_next <= cpu_data_in;
			end if;	


		end if;
	end process;
	
	-- Read from registers
	process(addr,addr_decoded, in1, in2, in3, in4, out1_reg, out2_reg, out3_reg, out4_reg, out5_reg, out6_reg, out7_reg, out8_reg, SIO_COMMAND, spi_rx_data, spi_busy, timer_reg, timer2_reg, i2c0_busy_reg, i2c0_read_data, i2c1_busy_reg, i2c1_read_data, i2c0_error, i2c1_error, rand_out)
	begin
		data_out_regs <= (others=>'0');

		if (addr_decoded(0) = '1') then
			data_out_regs <= in1;
		end if;
		
		if (addr_decoded(1) = '1') then
			data_out_regs <= in2;
		end if;		
		
		if (addr_decoded(2) = '1') then
			data_out_regs <= in3;
		end if;		
		
		if (addr_decoded(3) = '1') then
			data_out_regs <= in4;
		end if;

		if (addr_decoded(4) = '1') then
			data_out_regs <= out1_reg;
		end if;
		
		if (addr_decoded(5) = '1') then
			data_out_regs <= out2_reg;
		end if;		
		
		if (addr_decoded(6) = '1') then
			data_out_regs <= out3_reg;
		end if;		
		
		if (addr_decoded(7) = '1') then
			data_out_regs <= out4_reg;
		end if;

		if (addr_decoded(14) = '1') then
			data_out_regs <= out5_reg;
		end if;

		if (addr_decoded(15) = '1') then
			data_out_regs <= out6_reg;
		end if;

		if(addr_decoded(20) = '1') then
			data_out_regs <= out7_reg;
		end if;	

		if(addr_decoded(21) = '1') then
			data_out_regs <= out8_reg;
		end if;	

		if (addr_decoded(8) = '1') then
			data_out_regs <= timer_reg;
		end if;

		if (addr_decoded(9) = '1') then
			data_out_regs(7 downto 0) <= spi_rx_data;
		end if;

		if (addr_decoded(10) = '1') then
			data_out_regs(0) <= spi_busy;
		end if;		

		if(addr_decoded(11) = '1') then
			data_out_regs(0) <= SIO_COMMAND;
		end if;	
		
		if (addr_decoded(12) = '1') then
			data_out_regs <= std_logic_vector(to_unsigned(platform,32));
		end if;

		if (addr_decoded(16) = '1') then
			data_out_regs(9) <= i2c0_error;
			data_out_regs(8) <= i2c0_busy_reg;
			data_out_regs(7 downto 0) <= i2c0_read_data;
		end if;

		if (addr_decoded(17) = '1') then
			data_out_regs(9) <= i2c1_error;
			data_out_regs(8) <= i2c1_busy_reg;
			data_out_regs(7 downto 0) <= i2c1_read_data;
		end if;


		if(addr_decoded(18) = '1') then -- timer2 value
			data_out_regs <= timer2_reg;
		end if;

		if(addr_decoded(19) = '1') then -- rand
			data_out_regs(7 downto 0) <= rand_out;
		end if;
	end process;	
	
	-- outputs
	PAUSE_ZPU <= paused_reg;

	out1 <= out1_reg;
	out2 <= out2_reg;
	out3 <= out3_reg;
	out4 <= out4_reg;
	out5 <= out5_reg;
	out6 <= out6_reg;
	out7 <= out7_reg;
	out8 <= out8_reg;
	
	--SDCARD_CLK <= spi_clk_out;
	--SDCARD_CMD <= spi_mosi;
	--spi_miso <= SDCARD_DAT; -- INPUT!! XXX
	--SDCARD_DAT3 <= spi_chip_select(0);
	--FLASH_SELECT <= spi_chip_select(1);

	SPI_CLK <= spi_clk_out;
	SPI_DO <= spi_mosi;
	spi_miso <= SPI_DI; -- INPUT!! XXX
	SPI_SELECT0 <= spi_select_reg(0);
	SPI_SELECT1 <= spi_select_reg(1);

	data_out <= data_out_mux;

	sd_addr <= spi_dma_addr_reg;
	sd_data <= spi_rx_data;
	sd_write <= spi_dma_wr;
end vhdl;


