

---------------------------------------------------------------------------
-- (c) 2017 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_MISC.all;


ENTITY bus_master_arbiter IS
PORT 
( 
	ANTIC_REQUEST : in std_logic;
	CPU_REQUEST : in std_logic;
	DMA_REQUEST : in std_logic;

	SELECTED_MASTER : out std_logic_vector(1 downto 0)
);

END bus_master_arbiter;

ARCHITECTURE vhdl OF bus_master_arbiter IS
	constant selected_antic : std_logic_vector(1 downto 0) := "11";
	constant selected_cpu : std_logic_vector(1 downto 0) := "01";
	constant selected_dma : std_logic_vector(1 downto 0) := "10";
	constant selected_none : std_logic_vector(1 downto 0) := "00";
BEGIN
	-- Basic... 1)antic, 2)dma, 3)cpu
	selected_master <= (antic_request or dma_request)&(antic_request or (cpu_request xor dma_request));
END vhdl;

