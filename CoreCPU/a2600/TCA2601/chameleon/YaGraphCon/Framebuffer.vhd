-- Copyright (c) 2009 Frank Buss (fb@frank-buss.de)
-- See license.txt for license

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.all;
use work.YaGraphConPackage.all;

entity Framebuffer is
	generic(
		ADDRESS_WIDTH: natural;
		BIT_DEPTH: natural
	);
	port(
		clock: in std_logic;

		-- 1st RAM port for read-only access
		readAddress1: in unsigned(ADDRESS_WIDTH-1 downto 0);
		q1: out unsigned(BIT_DEPTH-1 downto 0);

		-- 2nd RAM port for read-only access
		readAddress2: in unsigned(ADDRESS_WIDTH-1 downto 0);
		q2: out unsigned(BIT_DEPTH-1 downto 0);

		-- 3rd RAM port for write access
		writeAddress: in unsigned(ADDRESS_WIDTH-1 downto 0);
		data: in unsigned(BIT_DEPTH-1 downto 0);
		writeEnable: in std_logic
	);
end entity Framebuffer;

architecture rtl of Framebuffer is

	-- infering template for Xilinx block RAM
	constant ADDR_WIDTH : integer := ADDRESS_WIDTH;
	constant DATA_WIDTH : integer := BIT_DEPTH;
	type framebufferType is array (2**ADDR_WIDTH-1 downto 0) of unsigned(DATA_WIDTH-1 downto 0);
	signal framebufferRam1: framebufferType;
	signal framebufferRam2: framebufferType;

begin

	-- infering template for Xilinx block RAM
	ram1: process(clock)
	begin
		if rising_edge(clock) then
		--if (clock'event and clock = '1') then
			if writeEnable = '1' then
				framebufferRam1(to_integer(writeAddress)) <= data;
			end if;
			q1 <= framebufferRam1(to_integer(readAddress1));
		end if;
	end process;

	-- infering template for Xilinx block RAM
	ram2: process(clock)
	begin
		if rising_edge(clock) then
		--if (clock'event and clock = '1') then
			if writeEnable = '1' then
				framebufferRam2(to_integer(writeAddress)) <= data;
			end if;
			q2 <= framebufferRam2(to_integer(readAddress2));
		end if;
	end process;

end architecture rtl;
