-- Copyright (c) 2009 Frank Buss (fb@frank-buss.de)
-- See license.txt for license

library ieee;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use work.all;
use work.YaGraphConPackage.all;

entity YaGraphCon is
	generic(
		ADDRESS_WIDTH: natural;
		BIT_DEPTH: natural
	);
	port(
		-- main clock
		clock: in std_logic;
		
		-- register interface
		registerAddress: in unsigned(7 downto 0);
		registerValue: in unsigned(7 downto 0);
		registerWrite: in std_logic;
		registerQ: out unsigned(7 downto 0);
		framebufferWrite: in std_logic;
		vsync: out std_logic;
		
		-- graphics output
	  	pixel: out unsigned(BIT_DEPTH-1 downto 0);
	  	vgaHsync: out std_logic;
	  	vgaVsync: out std_logic
	);
end entity YaGraphCon;

architecture rtl of YaGraphCon is
	constant PITCH_WIDTH: natural := minNatural(16, ADDRESS_WIDTH);
	
	-- 1st RAM port for read-only access
	signal framebufferReadAddress1: unsigned(ADDRESS_WIDTH-1 downto 0);
	signal framebufferQ1: unsigned(BIT_DEPTH-1 downto 0);

	-- 2nd RAM port for read-only access
	signal framebufferReadAddress2: unsigned(ADDRESS_WIDTH-1 downto 0);
	signal framebufferQ2: unsigned(BIT_DEPTH-1 downto 0);

	-- 3rd RAM port for write access
	signal framebufferWriteAddress: unsigned(ADDRESS_WIDTH-1 downto 0);
	signal framebufferData: unsigned(BIT_DEPTH-1 downto 0);
	signal framebufferWriteEnable: std_logic;
	
	-- OutputGenerator signals
	signal framebufferStart: unsigned(31 downto 0);
	signal framebufferPitch: unsigned(15 downto 0);
  
	-- GraphicsAccelerator signals
	signal reset: std_logic := '0';
	signal writeStart: unsigned(ADDRESS_WIDTH-1 downto 0);
	signal writeSize: unsigned(ADDRESS_WIDTH-1 downto 0);
	signal registers: registerSetType := (others => (others => '0'));
	signal busy: std_logic;
	signal start: std_logic;
	signal acceleratorBusy: std_logic;
	signal acceleratorWriteAddress: unsigned(ADDRESS_WIDTH-1 downto 0);
	signal acceleratorData: unsigned(BIT_DEPTH-1 downto 0);
	signal acceleratorWriteEnable: std_logic;
	
begin

	Framebuffer_instance: entity Framebuffer
		generic map(ADDRESS_WIDTH, BIT_DEPTH)
		port map(
			clock => clock,
			readAddress1 => framebufferReadAddress1,
			q1 => framebufferQ1,
			readAddress2 => framebufferReadAddress2,
			q2 => framebufferQ2,
			writeAddress => framebufferWriteAddress,
			data => framebufferData,
			writeEnable => framebufferWriteEnable
		);

	OutputGenerator_instance: entity OutputGenerator
		generic map(ADDRESS_WIDTH, BIT_DEPTH, PITCH_WIDTH)
		port map(
			clock => clock,
			pixel => pixel,
			vgaHsync => vgaHsync,
			vgaVsync => vgaVsync,
			vsync => vsync,
			readAddress => framebufferReadAddress1,
			q => framebufferQ1,
			framebufferStart => framebufferStart(ADDRESS_WIDTH - 1 downto 0),
			framebufferPitch => framebufferPitch(PITCH_WIDTH - 1 downto 0)
		);

	GraphicsAccelerator_instance: entity GraphicsAccelerator
		generic map(ADDRESS_WIDTH, BIT_DEPTH, PITCH_WIDTH)
		port map(
			clock => clock,
			reset => reset,
			registers => registers,
			busy => busy,
			start => start,
			framebufferWrite => framebufferWrite,
			readAddress => framebufferReadAddress2,
			writeAddress => acceleratorWriteAddress,
			data => acceleratorData,
			q => framebufferQ2,
			writeEnable => acceleratorWriteEnable
		);

	process(clock)
	begin
		if rising_edge(clock) then
			reset <= '0';
			start <= '0';
			framebufferWriteAddress <= acceleratorWriteAddress;
			framebufferData <= acceleratorData;
			framebufferWriteEnable <= acceleratorWriteEnable;
			if registerWrite = '1' then
				registers(to_integer(registerAddress)) <= registerValue;
				if registerAddress = COMMAND_REGISTER then 
					start <= '1';
				end if;
			end if;
			registers(STATUS_REGISTER)(0) <= busy;
			registerQ <= registers(to_integer(registerAddress));
		end if;
	end process;
	
	framebufferStart <= registers(FRAMEBUFFER_START_REGISTER + 3) & registers(FRAMEBUFFER_START_REGISTER + 2) & registers(FRAMEBUFFER_START_REGISTER + 1) & registers(FRAMEBUFFER_START_REGISTER);
	framebufferPitch <= registers(FRAMEBUFFER_PITCH_REGISTER + 1) & registers(FRAMEBUFFER_PITCH_REGISTER);

end architecture rtl;
