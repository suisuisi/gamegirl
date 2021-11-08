library IEEE;
use IEEE.std_logic_1164.all;

package sdram is
component sdram
	port (

-- System
		clk    : in std_logic;
		init_n : in std_logic;

-- SDRAM interface
		SDRAM_DQ : inout std_logic_vector(15 downto 0);
		SDRAM_A : out std_logic_vector(12 downto 0);
		SDRAM_nWE : out std_logic;
		SDRAM_nRAS : out std_logic;
		SDRAM_nCAS : out std_logic;
		SDRAM_BA : out std_logic_vector(1 downto 0);
		SDRAM_DQML : out std_logic;
		SDRAM_DQMH : out std_logic;
		SDRAM_nCS : out std_logic;

-- SDRAM ports
		romwr_req : in std_logic;
		romwr_ack : out std_logic;
		romwr_a : in std_logic_vector(23 downto 1);
		romwr_d : in std_logic_vector(15 downto 0);

		romrd_req : in std_logic;
		romrd_ack : out std_logic;
		romrd_a : in std_logic_vector(23 downto 1);
		romrd_q : out std_logic_vector(15 downto 0);

		ram68k_req : in std_logic;
		ram68k_ack : out std_logic;
		ram68k_we : in std_logic;
		ram68k_a : in std_logic_vector(15 downto 1);
		ram68k_d : in std_logic_vector(15 downto 0);
		ram68k_q : out std_logic_vector(15 downto 0);
		ram68k_u_n : in std_logic;
		ram68k_l_n : in std_logic;

		sram_req : in std_logic;
		sram_ack : out std_logic;
		sram_we : in std_logic;
		sram_a : in std_logic_vector(15 downto 1);
		sram_d : in std_logic_vector(15 downto 0);
		sram_q : out std_logic_vector(15 downto 0);
		sram_u_n : in std_logic;
		sram_l_n : in std_logic;

		vram_req : in std_logic;
		vram_ack : out std_logic;
		vram_we : in std_logic;
		vram_a : in std_logic_vector(15 downto 1);
		vram_d : in std_logic_vector(15 downto 0);
		vram_q : out std_logic_vector(15 downto 0);
		vram_u_n : in std_logic;
		vram_l_n : in std_logic;

		vram32_req : in std_logic;
		vram32_ack : out std_logic;
		vram32_a   : in std_logic_vector(15 downto 1);
		vram32_q   : out std_logic_vector(31 downto 0);

		svp_ram1_req : in std_logic;
		svp_ram1_ack : out std_logic;
		svp_ram1_we : in std_logic;
		svp_ram1_a : in std_logic_vector(16 downto 1);
		svp_ram1_d : in std_logic_vector(15 downto 0);
		svp_ram1_q : out std_logic_vector(15 downto 0);

		svp_ram2_req : in std_logic;
		svp_ram2_ack : out std_logic;
		svp_ram2_we : in std_logic;
		svp_ram2_a : in std_logic_vector(16 downto 1);
		svp_ram2_d : in std_logic_vector(15 downto 0);
		svp_ram2_q : out std_logic_vector(15 downto 0);
		svp_ram2_u_n : in std_logic;
		svp_ram2_l_n : in std_logic;

		svp_rom_req : in std_logic;
		svp_rom_ack : out std_logic;
		svp_rom_a : in std_logic_vector(23 downto 1);
		svp_rom_q : out std_logic_vector(15 downto 0)
);
end component;
end package;
