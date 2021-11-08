-- Copyright (c) 2009 Frank Buss (fb@frank-buss.de)
-- See license.txt for license

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.all;
use work.YaGraphConPackage.all;

entity MyComputer is
	port(
		clk_50mhz: in std_logic;
		VGA_BLUE: out std_logic;
		VGA_GREEN: out std_logic;
		VGA_HSYNC: out std_logic;
		VGA_RED: out std_logic;
		VGA_VSYNC: out std_logic;
		debug: out unsigned(7 downto 0)
	);
end entity MyComputer;

architecture rtl of MyComputer is
	constant ADDRESS_WIDTH: natural := 17;
	constant BIT_DEPTH: natural := 1;

	constant SYSTEM_SPEED: natural := 50e6;

	constant RESET_VECTOR: std_logic_vector(15 downto 0) := x"0200";
	
	signal registerAddress: unsigned(7 downto 0);
	signal registerValue: unsigned(7 downto 0);
	signal registerWrite: std_logic;
	signal registerQ: unsigned(7 downto 0);
	signal framebufferWrite: std_logic;
	signal vsync: std_logic;
	signal pixel: unsigned(BIT_DEPTH-1 downto 0);
	signal vgaHsync: std_logic;
	signal vgaVsync: std_logic;
  
  -- reset counter
	signal resetCounter: integer range 0 to 200 := 0;

	-- 6502
   signal cpuReset: std_logic := '1';
   signal cpuData: std_logic_vector(7 downto 0);
   signal cpuAddress: std_logic_vector(15 downto 0);
   signal cpuRead: std_logic;
	signal cpuClock: std_logic := '0';
	signal cpuDelay: integer range 0 to 2 := 0;
	
	-- CPU RAM
   signal ramAddress: std_logic_vector(12 downto 0);
   signal ramQ: std_logic_vector(7 downto 0);
   signal ramWren: std_logic := '0';
   signal ramData: std_logic_vector(7 downto 0);
	
begin

	YaGraphCon_instance: entity YaGraphCon
		generic map(ADDRESS_WIDTH, BIT_DEPTH)
		port map(
			clock => clk_50mhz,
			registerAddress => registerAddress,
			registerValue => registerValue,
			registerWrite => registerWrite,
			registerQ => registerQ,
			framebufferWrite => framebufferWrite,
			vsync => vsync,
			pixel => pixel,
			vgaHsync => vgaHsync,
			vgaVsync => vgaVsync
		);

	A6502_instance: entity work.A6502
		port map(
			clk => cpuClock,
			rst => cpuReset,
			--irq => '1', 
			--nmi => '1',
			rdy => '1',
			d => cpuData,
			ad => cpuAddress,
			r => cpuRead);

	cpuRAM_instance: entity work.cpuRAM PORT MAP(
		clock => clk_50mhz,
		q => ramQ,
		address => ramAddress,
		wren => ramWren,
		data => ramData
	);		 

	process(clk_50mhz)
	begin
		if rising_edge(clk_50mhz) then
			ramWren <= '0';
			if cpuDelay < 2 then
				cpuDelay <= cpuDelay + 1;
			else
				cpuDelay <= 0;
				cpuClock <= not cpuClock;
			end if;

			case resetCounter is
				when 1 =>
					cpuReset <= '1';
					resetCounter <= resetCounter + 1;
				when 200 =>
					cpuReset <= '0';
				when others =>
					resetCounter <= resetCounter + 1;
			end case;
			
			registerWrite <= '0';
			framebufferWrite <= '0';
			ramAddress <= cpuAddress(12 downto 0);
			cpuData <= ramQ;
			registerAddress <= unsigned(cpuAddress(7 downto 0));
			if cpuRead = '1' then
				case cpuAddress(15 downto 8) is
					when x"d0" =>
						cpuData <= std_logic_vector(registerQ);
					when others =>
						case cpuAddress is
							when x"fffc" =>
								cpuData <= RESET_VECTOR(7 downto 0);
							when x"fffd" =>
								cpuData <= RESET_VECTOR(15 downto 8);
							when others =>
								null;
						end case;
				end case;
			else
				if cpuDelay = 0 and cpuClock = '0' then
					case cpuAddress(15 downto 8) is
						when x"d0" =>
							if cpuAddress(7 downto 0) = std_logic_vector(to_unsigned(WRITE_FRAMEBUFFER_REGISTER, 8)) then
								framebufferWrite <= '1';
							end if;
							registerValue <= unsigned(cpuData);
							registerWrite <= '1';
						when others =>
							ramWren <= '1';
							ramData <= cpuData;
					end case;
				end if;
				cpuData <= (others => 'Z');
			end if;
			
			debug <= unsigned(cpuReset & cpuClock & cpuData(7 downto 2));
			
		end if;
	end process;

	VGA_RED <= pixel(0);
	VGA_GREEN <= pixel(0);
	VGA_BLUE <= pixel(0);
	VGA_HSYNC <= vgaHsync;
	VGA_VSYNC <= vgaVsync;
  
end architecture rtl;
