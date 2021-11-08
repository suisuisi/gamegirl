--
-- VGA video pattern generator
--
-- Copyright (c) 2009 Frank Buss (fb@frank-buss.de)
-- See license.txt for license
--
-- VGA timings:
-- clocks per line:
-- 1. HSync low pulse for 96 clocks
-- 2. back porch for 48 clocks
-- 3. data for 640 clocks
-- 4. front porch for 16 clocks
--
-- VSync timing per picture (800 clocks = 1 line):
-- 1. VSync low pulse for 2 lines
-- 2. back porch for 29 lines
-- 3. data for 480 lines
-- 4. front porch for 10 lines


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.all;
use work.YaGraphConPackage.all;

entity OutputGenerator is
	generic(
		ADDRESS_WIDTH: natural;
		BIT_DEPTH: natural;
		PITCH_WIDTH: natural
	);
	port(
		clock: in std_logic;
		
		-- VGA output
	  	pixel: out unsigned(BIT_DEPTH-1 downto 0);
	  	vgaHsync: out std_logic;
	  	vgaVsync: out std_logic;
		
		-- microcontroller interface
	  	vsync: out std_logic;
		
		-- framebuffer
		readAddress: out unsigned(ADDRESS_WIDTH-1 downto 0);
		q: in unsigned(BIT_DEPTH-1 downto 0);
		framebufferStart: in unsigned(ADDRESS_WIDTH-1 downto 0);
		framebufferPitch: in unsigned(PITCH_WIDTH-1 downto 0)
	 );
end entity OutputGenerator;

architecture rtl of OutputGenerator is
	constant H_SYNC_PULSE: natural := 96;
	constant H_BACK_PORCH: natural := 48 + H_SYNC_PULSE;
	constant H_DATA: natural := 640 + H_BACK_PORCH;
	constant H_FRONT_PORCH: natural := 16 + H_DATA;

	constant V_SYNC_PULSE: natural := 2;
	constant V_BACK_PORCH: natural := 29 + V_SYNC_PULSE;
	constant V_DATA: natural := 480 + V_BACK_PORCH;
	constant V_FRONT_PORCH: natural := 10 + V_DATA;

	signal pixelCounter: natural range 0 to 1023 := 0;
	signal lineCounter: natural range 0 to 1023 := 0;
	signal divide2: std_logic := '0';
	signal pixelRepeat: std_logic := '0';
	signal lineRepeat: std_logic := '0';
	
	signal framebufferPitchLatched: unsigned(PITCH_WIDTH-1 downto 0);
	signal framebufferCurrentAddress: unsigned(ADDRESS_WIDTH-1 downto 0);
	signal framebufferLastLineAddress: unsigned(ADDRESS_WIDTH-1 downto 0);

	signal lastPixel: unsigned(BIT_DEPTH-1 downto 0);
  
begin

	vgaOut: process(clock)
	begin
		if rising_edge(clock) then
			divide2 <= not divide2;
			if divide2 = '1' then
				-- default values
				pixel <= (others => '0');
				
				-- horizontal timing for one line
				pixelCounter <= pixelCounter + 1;
				if pixelCounter < H_SYNC_PULSE then
					vgaHsync <= '0';
				elsif pixelCounter < H_BACK_PORCH then
					vgaHsync <= '1';
				elsif pixelCounter = H_FRONT_PORCH then
					pixelCounter <= 0;
					lineCounter <= lineCounter + 1;
				end if;

				-- vertical timing for one screen
				if lineCounter < V_SYNC_PULSE then
					vgaVsync <= '0';
					vsync <= '1';
				elsif lineCounter < V_BACK_PORCH then
					vgaVsync <= '1';
					vsync <= '0';
				elsif lineCounter = V_FRONT_PORCH then
					lineCounter <= 0;

					-- latch framebuffer start on VSync
					framebufferPitchLatched <= framebufferPitch;
					framebufferCurrentAddress <= framebufferStart;
					framebufferLastLineAddress <= framebufferStart;
					lineRepeat <= '1';
					pixelRepeat <= '0';
				end if;
				
				-- display pixels
				if lineCounter >= V_BACK_PORCH and lineCounter < V_DATA then
					if pixelCounter >= H_BACK_PORCH and pixelCounter < H_DATA then
						if pixelRepeat = '1' then
							pixel <= lastPixel;
							framebufferCurrentAddress <= framebufferCurrentAddress + 1;
						else
							lastPixel <= q;
							pixel <= q;
						end if;
						pixelRepeat <= not pixelRepeat;
					end if;
					if pixelCounter = H_DATA then
						pixelRepeat <= '0';
						if lineRepeat = '1' then
							framebufferCurrentAddress <= framebufferLastLineAddress;
						else
							framebufferLastLineAddress <= adjustLength(framebufferLastLineAddress + framebufferPitchLatched, framebufferLastLineAddress'length);
							framebufferCurrentAddress <= adjustLength(framebufferLastLineAddress + framebufferPitchLatched, framebufferCurrentAddress'length);
						end if;
						lineRepeat <= not lineRepeat;
					end if;
				end if;
			end if;
		end if;
	end process;

	readAddress <= framebufferCurrentAddress;
	
end architecture rtl;
