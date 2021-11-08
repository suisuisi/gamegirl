-- Port of the A2601 FPGA implementation for the Turbo Chameleon

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

-- -----------------------------------------------------------------------

entity main is
	port (
-- Clocks
		clk8 : in std_logic;
		dotclock_n : in std_logic;

-- Bus
		romlh_n : in std_logic;
		ioef_n : in std_logic;

-- Buttons
		freeze_n : in std_logic;

-- MMC/SPI
		spi_miso : in std_logic;
		mmc_cd_n : in std_logic;
		mmc_wp : in std_logic;

-- MUX CPLD
		mux_clk : out std_logic;
		mux : out unsigned(3 downto 0);
		mux_d : out unsigned(3 downto 0);
		mux_q : in unsigned(3 downto 0);

-- USART
		usart_tx : in std_logic;
		usart_clk : in std_logic;
		usart_rts : in std_logic;
		usart_cts : in std_logic;

-- Video
		red : out unsigned(4 downto 0);
		grn : out unsigned(4 downto 0);
		blu : out unsigned(4 downto 0);
		nHSync : out std_logic;
		nVSync : out std_logic;

-- Audio
		sigmaL : out std_logic;
		sigmaR : out std_logic
	);
end entity;

-- -----------------------------------------------------------------------

architecture rtl of main is
	type state_t is (TEST_IDLE, TEST_FILL, TEST_FILL_W, TEST_CHECK, TEST_CHECK_W, TEST_ERROR);
	
-- System clocks
	signal vid_clk: std_logic := '0';
	signal sysclk : std_logic := '0';
	signal ena_1mhz : std_logic := '0';
	signal ena_1khz : std_logic := '0';

	signal reset_button_n : std_logic := '0';
	
-- Global signals
	signal reset : std_logic := '0';
	signal end_of_pixel : std_logic := '0';

-- RAM Test
	signal state : state_t := TEST_IDLE;
	signal noise_bits : unsigned(7 downto 0) := (others => '0');
	
-- MUX
	signal mux_clk_reg : std_logic := '0';
	signal mux_reg : unsigned(3 downto 0) := (others => '1');
	signal mux_d_reg : unsigned(3 downto 0) := (others => '1');
	signal debug_reg_latched : unsigned(7 downto 0) := (others => '1');
	signal debug_reg : unsigned(7 downto 0) := (others => '1');

-- 4 Port joystick adapter
	signal video_joystick_shift_reg : std_logic := '0';

-- LEDs
	signal led_green : std_logic := '0';
	signal led_red : std_logic := '0';

-- VGA
	signal hsync : std_logic := '0';
	signal vsync : std_logic := '0';
	
	signal red_reg : unsigned(4 downto 0) := (others => '0');
	signal grn_reg : unsigned(4 downto 0) := (others => '0');
	signal blu_reg : unsigned(4 downto 0) := (others => '0');
	
-- Sound
	signal sigma_l : std_logic := '0';
	signal sigma_r : std_logic := '0';
	signal sigmaL_reg : std_logic := '0';
	signal sigmaR_reg : std_logic := '0';

-- Docking station
	signal docking_ena : std_logic := '0';
	signal docking_irq : std_logic := '0';
	signal irq_n : std_logic := '0';
	
	signal docking_joystick1 : unsigned(5 downto 0) := (others => '0');
	signal docking_joystick2 : unsigned(5 downto 0) := (others => '0');
	signal docking_joystick3 : unsigned(5 downto 0) := (others => '0');
	signal docking_joystick4 : unsigned(5 downto 0) := (others => '0');
	
-- A2601
	signal audio: std_logic := '0';
   signal O_VSYNC: std_logic := '0';
   signal O_HSYNC: std_logic := '0';
	signal O_VIDEO_R: std_logic_vector(3 downto 0) := (others => '0');
	signal O_VIDEO_G: std_logic_vector(3 downto 0) := (others => '0');
	signal O_VIDEO_B: std_logic_vector(3 downto 0) := (others => '0');			
	signal res: std_logic := '0';
	signal p_l: std_logic := '0';
	signal p_r: std_logic := '0';
	signal p_a: std_logic := '0';
	signal p_u: std_logic := '0';
	signal p_d: std_logic := '0';
	signal p2_l: std_logic := '0';
	signal p2_r: std_logic := '0';
	signal p2_a: std_logic := '0';
	signal p2_u: std_logic := '0';
	signal p2_d: std_logic := '0';
	signal p_start: std_logic := '0';
	signal p_select: std_logic := '0';
	signal next_cartridge: std_logic := '0';
--	signal p_bs: std_logic;
--	signal LED: std_logic_vector(2 downto 0);
--	signal I_SW : std_logic_vector(2 downto 0) := (others => '0');
--	signal JOYSTICK_GND: std_logic;
--	signal JOYSTICK2_GND: std_logic;

begin

-- -----------------------------------------------------------------------
-- A2601 core
-- -----------------------------------------------------------------------
	a2601Instance : entity work.A2601NoFlash
		port map (
			vid_clk => vid_clk,
			audio => audio,
         O_VSYNC => O_VSYNC,
         O_HSYNC => O_HSYNC,
			O_VIDEO_R => O_VIDEO_R,
			O_VIDEO_G => O_VIDEO_G,
			O_VIDEO_B => O_VIDEO_B,
         res => res,
         p_l => p_l,
         p_r => p_r,
         p_a => p_a,
         p_u => p_u,
         p_d => p_d,
         p2_l => p2_l,
         p2_r => p2_r,
         p2_a => p2_a,
         p2_u => p2_u,
         p2_d => p2_d,
         p_start => p_start,
         p_select => p_select,
			next_cartridge => '0', --next_cartridge,
         p_bs => open,
			LED => open,
			I_SW => "111",
         JOYSTICK_GND => open,
			JOYSTICK2_GND => open
		);

	myComputerInstance : entity work.MyComputer
		port map (
			clk_50mhz => vid_clk,
			VGA_BLUE => blu_reg(4),
			VGA_GREEN => grn_reg(4),
			VGA_HSYNC => hsync,
			VGA_RED => red_reg(4),
			VGA_VSYNC => vsync,
			debug => debug_reg
		);

	process(red_reg, grn_reg, blu_reg, O_VIDEO_R, O_VIDEO_G, O_VIDEO_B, O_HSYNC, O_VSYNC, audio)
	begin
		if true then
			-- VGA test
			red <= red_reg;
			grn <= grn_reg;
			blu <= blu_reg;
			nHSync <= not hsync;
			nVSync <= not vsync;
			sigmaL <= sigmaL_reg;
			sigmaR <= sigmaR_reg;
		else
			-- A2601
			red <= unsigned(O_VIDEO_R) & "0";
			grn <= unsigned(O_VIDEO_G) & "0";
			blu <= unsigned(O_VIDEO_B) & "0";
			nHSync <= not O_HSYNC;
			nVSync <= not O_VSYNC;
			sigmaL <= audio;
			sigmaR <= audio;
		end if;
	end process;
			
	res <= '0';
--	p_l <= reset_button_n;
--	p_r <= freeze_n;
--	p_a <= usart_cts;
--	p_u <= '1';
--	p_d <= '1';
--	p2_l <= reset_button_n;
--	p2_r <= freeze_n;
--	p2_a <= usart_cts;
--	p2_u <= '1';
--	p2_d <= '1';
	--p_l <= docking_joystick1(0);
--	p_r <= docking_joystick1(1);
--	p_a <= docking_joystick1(2);
	--p_u <= docking_joystick1(3);
	--p_d <= docking_joystick1(4);

	-- 9 pin d-sub joystick pinout:
	-- pin 1: up
	-- pin 2: down
	-- pin 3: left
	-- pin 4: right
	-- pin 6: fire
	
	-- Atari 2600, 6532 ports:
	-- PA0: right joystick, up
	-- PA1: right joystick, down
	-- PA2: right joystick, left
	-- PA3: right joystick, right
	-- PA4: left joystick, up
	-- PA5: left joystick, down
	-- PA6: left joystick, left
	-- PA7: left joystick, right
	-- PB0: start
	-- PB1: select
	-- PB3: B/W, color
	-- PB6: left difficulty
	-- PB7: right difficulty

	-- Atari 2600, TIA input:
	-- I5: right joystick, fire
	-- I6: left joystick, fire
	
	-- pinout docking station joystick 1/2:
	-- bit 0: up
	-- bit 1: down
	-- bit 2: left
	-- bit 3: right
	-- bit 4: fire
	p_l <= docking_joystick1(2);
	p_r <= docking_joystick1(3);
	p_a <= docking_joystick1(4);
	p_u <= docking_joystick1(0);
	p_d <= docking_joystick1(1);

	p2_l <= docking_joystick2(2);
	p2_r <= docking_joystick2(3);
	p2_a <= docking_joystick2(4);
	p2_u <= docking_joystick2(0);
	p2_d <= docking_joystick2(1);
	p_start <= freeze_n;
	p_select <= usart_cts;
	next_cartridge <= reset_button_n;
--	p_s <= freeze_n;
	-- p_bs <= '1';
	-- LED: std_logic_vector(2 downto 0);
	-- I_SW <= '0'
	-- JOYSTICK_GND <= '0';
	-- JOYSTICK2_GND <= '0';

	
-- -----------------------------------------------------------------------
-- Clocks and PLL
-- -----------------------------------------------------------------------
	pllInstance : entity work.pll8
		port map (
			inclk0 => clk8,
			c0 => sysclk,
			c1 => open, 
			c2 => open,
			c3 => open,
			c4 => vid_clk,
			locked => open
		);

-- -----------------------------------------------------------------------
-- 1 Mhz and 1 Khz clocks
-- -----------------------------------------------------------------------
	my1Mhz : entity work.chameleon_1mhz
		generic map (
			clk_ticks_per_usec => 100
		)
		port map (
			clk => sysclk,
			ena_1mhz => ena_1mhz,
			ena_1mhz_2 => open
		);

	my1Khz : entity work.chameleon_1khz
		port map (
			clk => sysclk,
			ena_1mhz => ena_1mhz,
			ena_1khz => ena_1khz
		);


-- -----------------------------------------------------------------------
-- Sound test
-- -----------------------------------------------------------------------
	process(sysclk)
	begin
		if rising_edge(sysclk) then
			if ena_1khz = '1' then
				sigma_l <= not sigma_l;
				sigma_r <= not sigma_r;
			end if;
		end if;
	end process;
	sigmaL_reg <= sigma_l;
	sigmaR_reg <= sigma_r;

	
-- -----------------------------------------------------------------------
-- Docking station
-- -----------------------------------------------------------------------
	myDockingStation : entity work.chameleon_docking_station
		port map (
			clk => sysclk,
			ena_1mhz => ena_1mhz,
			enable => docking_ena,
			
			docking_station => '1',
			
			dotclock_n => dotclock_n,
			io_ef_n => ioef_n,
			rom_lh_n => romlh_n,
			irq_d => irq_n,
			irq_q => docking_irq,
			
			joystick1 => docking_joystick1,
			joystick2 => docking_joystick2,
			joystick3 => docking_joystick3,
			joystick4 => docking_joystick4,
			keys => open,
			restore_key_n => open,
			
			amiga_power_led => led_green,
			amiga_drive_led => led_red,
			amiga_reset_n => open,
			amiga_scancode => open
		);

-- -----------------------------------------------------------------------
-- MUX CPLD
-- -----------------------------------------------------------------------
	-- MUX clock
	process(sysclk)
	begin
		if rising_edge(sysclk) then
			mux_clk_reg <= not mux_clk_reg;
		end if;
	end process;

	-- MUX read
	process(sysclk)
	begin
		if rising_edge(sysclk) then
			if mux_clk_reg = '1' then
				case mux_reg is
				when X"6" =>
					irq_n <= mux_q(2);
				when X"B" =>
					reset_button_n <= mux_q(1);
				when others =>
					null;
				end case;
			end if;
		end if;
	end process;

	-- MUX write
	process(sysclk)
	begin
		if rising_edge(sysclk) then
			docking_ena <= '0';
			if mux_clk_reg = '1' then
				case mux_reg is
				when X"7" =>
					mux_d_reg <= debug_reg_latched(3 downto 0);
					mux_reg <= X"0";
				when X"0" =>
					mux_d_reg <= debug_reg_latched(7 downto 4);
					mux_reg <= X"1";
					debug_reg_latched <= debug_reg;
				when X"1" =>
					--mux_d_reg <= "1111";
					mux_d_reg <= "1101";
					mux_reg <= X"7";
				when others =>
					mux_d_reg <= "1101";
					mux_reg <= X"7";
				end case;
			end if;
		end if;
	end process;
	
	mux_clk <= mux_clk_reg;
	mux_d <= mux_d_reg;
	mux <= mux_reg;

-- -----------------------------------------------------------------------
-- LEDs
-- -----------------------------------------------------------------------
	myGreenLed : entity work.chameleon_led
		port map (
			clk => sysclk,
			clk_1khz => ena_1khz,
			led_on => '0',
			led_blink => '1',
			led => led_red,
			led_1hz => led_green
		);

end architecture;
