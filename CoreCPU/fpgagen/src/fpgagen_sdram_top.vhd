-- Copyright (c) 2010 Gregory Estrade (greg@torlus.com)
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- Please report bugs to the author, but before you do so, please
-- make sure that this is not a derivative work and that
-- you have the latest version of this file.

library STD;
use STD.TEXTIO.ALL;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.sdram.all;

entity fpgagen_sdram_top is
port(
	reset_n      : in std_logic;
	MCLK         : in std_logic; --  54MHz
	SDR_CLK      : in std_logic; -- 108MHz

	FPGA_INIT_N  : in std_logic;

	DRAM_ADDR    : out std_logic_vector(12 downto 0);
	DRAM_BA_0    : out std_logic;
	DRAM_BA_1    : out std_logic;
	DRAM_CAS_N   : out std_logic;
	DRAM_CKE     : out std_logic;
	DRAM_CS_N    : out std_logic;
	DRAM_DQ      : inout std_logic_vector(15 downto 0);
	DRAM_LDQM    : out std_logic;
	DRAM_RAS_N   : out std_logic;
	DRAM_UDQM    : out std_logic;
	DRAM_WE_N    : out std_logic;

	DAC_LDATA    : out std_logic_vector(15 downto 0);
	DAC_RDATA    : out std_logic_vector(15 downto 0);

	RED          : out std_logic_vector(3 downto 0);
	GREEN        : out std_logic_vector(3 downto 0);
	BLUE         : out std_logic_vector(3 downto 0);
	VS           : out std_logic;
	HS           : out std_logic;
	HBL          : out std_logic;
	VBL          : out std_logic;
	IN_BORDER    : out std_logic;
	CE_PIX       : out std_logic;

	LED          : out std_logic;

	-- Port 1
	DINA     : in  std_logic_vector(7 downto 0);
	DOUTA    : out std_logic_vector(7 downto 0);
	OEA      : out std_logic_vector(7 downto 0);

	-- Port 2
	DINB     : in  std_logic_vector(7 downto 0);
	DOUTB    : out std_logic_vector(7 downto 0);
	OEB      : out std_logic_vector(7 downto 0);

	saveram_addr : in std_logic_vector(14 downto 0);
	saveram_we   : in std_logic;
	saveram_din  : in std_logic_vector(7 downto 0);
	saveram_rd   : in std_logic;
	saveram_dout : out std_logic_vector(7 downto 0);

        -- ROM Loader / Host boot data
	ext_reset_n  : in std_logic := '1';
	ext_bootdone : in std_logic := '0';
	ext_data     : in std_logic_vector(15 downto 0) := (others => '0');
	ext_data_req : out std_logic;
	ext_data_ack : in std_logic := '0';

        -- DIP switches
	ext_sw         : in std_logic_vector(15 downto 0)  -- 1 - SVP
	                                                   -- 3 - PSG EN
	                                                   -- 4 - FM EN
	                                                   -- 5 - Export
	                                                   -- 6 - PAL
	                                                   -- 9 - VRAM speed emu
	                                                   -- 10 - EEPROM emu (fake)
	                                                   -- 13 - HiFi PCM
	                                                   -- 14 - CPU Turbo
	                                                   -- 15 - Border
	                                                   -- 0 - CRAM dots
);
end entity;

architecture rtl of fpgagen_sdram_top is

signal SDRAM_BA : std_logic_vector(1 downto 0);

-- "FLASH"
signal romwr_req : std_logic := '0';
signal romwr_ack : std_logic;
signal romwr_a : unsigned(23 downto 1);
signal romwr_d : std_logic_vector(15 downto 0);

signal romrd_req : std_logic := '0';
signal romrd_ack : std_logic;
signal romrd_a : std_logic_vector(23 downto 1);
signal romrd_q : std_logic_vector(15 downto 0);

-- 68000 RAM
signal ram68k_req : std_logic;
signal ram68k_ack : std_logic;
signal ram68k_we : std_logic;
signal ram68k_a : std_logic_vector(15 downto 1);
signal ram68k_d : std_logic_vector(15 downto 0);
signal ram68k_q : std_logic_vector(15 downto 0);
signal ram68k_l_n : std_logic;
signal ram68k_u_n : std_logic;

-- SRAM
signal sram_req : std_logic := '0';
signal sram_ack : std_logic;
signal sram_we : std_logic := '0';
signal sram_a : std_logic_vector(15 downto 1);
signal sram_d : std_logic_vector(15 downto 0);
signal sram_q : std_logic_vector(15 downto 0);
signal sram_l_n : std_logic;
signal sram_u_n : std_logic;

-- VRAM
signal vram_req : std_logic;
signal vram_ack : std_logic;
signal vram_we : std_logic;
signal vram_a : std_logic_vector(15 downto 1);
signal vram_d : std_logic_vector(15 downto 0);
signal vram_q : std_logic_vector(15 downto 0);
signal vram_l_n : std_logic;
signal vram_u_n : std_logic;

signal vram32_req : std_logic;
signal vram32_ack : std_logic;
signal vram32_a   : std_logic_vector(15 downto 1);
signal vram32_q   : std_logic_vector(31 downto 0);

-- SVP
signal svp_ram1_req : std_logic;
signal svp_ram1_ack : std_logic;
signal svp_ram1_we  : std_logic;
signal svp_ram1_a   : std_logic_vector(16 downto 1);
signal svp_ram1_d   : std_logic_vector(15 downto 0);
signal svp_ram1_q   : std_logic_vector(15 downto 0);

signal svp_ram2_req : std_logic;
signal svp_ram2_ack : std_logic;
signal svp_ram2_we  : std_logic;
signal svp_ram2_a   : std_logic_vector(16 downto 1);
signal svp_ram2_d   : std_logic_vector(15 downto 0);
signal svp_ram2_q   : std_logic_vector(15 downto 0);
signal svp_ram2_u_n : std_logic;
signal svp_ram2_l_n : std_logic;

signal svp_rom_req  : std_logic;
signal svp_rom_ack  : std_logic;
signal svp_rom_a    : std_logic_vector(20 downto 1);
signal svp_rom_q    : std_logic_vector(15 downto 0);

begin

-- -----------------------------------------------------------------------
-- SDRAM Controller
-- -----------------------------------------------------------------------
DRAM_BA_0 <= SDRAM_BA(0);
DRAM_BA_1 <= SDRAM_BA(1);
-- SDRAM
DRAM_CKE <= '1';
DRAM_CS_N <= '0';

sdc : sdram
port map(
	clk         => SDR_CLK,
	init_n      => FPGA_INIT_N,

	std_logic_vector(SDRAM_DQ) => DRAM_DQ,
	std_logic_vector(SDRAM_A)  => DRAM_ADDR,
	SDRAM_nWE                  => DRAM_WE_N,
	SDRAM_nRAS                 => DRAM_RAS_N,
	SDRAM_nCAS                 => DRAM_CAS_N,
	SDRAM_BA                   => SDRAM_BA,
	SDRAM_DQML                 => DRAM_LDQM,
	SDRAM_DQMH                 => DRAM_UDQM,

	romwr_req    => romwr_req,
	romwr_ack    => romwr_ack,
	romwr_a      => std_logic_vector(romwr_a),
	romwr_d      => romwr_d,

	romrd_req    => romrd_req,
	romrd_ack    => romrd_ack,
	romrd_a      => romrd_a,
	romrd_q      => romrd_q,

	ram68k_req   => ram68k_req,
	ram68k_ack   => ram68k_ack,
	ram68k_we    => ram68k_we,
	ram68k_a     => ram68k_a,
	ram68k_d     => ram68k_d,
	ram68k_q     => ram68k_q,
	ram68k_u_n   => ram68k_u_n,
	ram68k_l_n   => ram68k_l_n,

	sram_req     => sram_req,
	sram_ack     => sram_ack,
	sram_we      => sram_we,
	sram_a       => sram_a,
	sram_d       => sram_d,
	sram_q       => sram_q,
	sram_u_n     => sram_u_n,
	sram_l_n     => sram_l_n,

	vram_req     => vram_req,
	vram_ack     => vram_ack,
	vram_we      => vram_we,
	vram_a       => vram_a,
	vram_d       => vram_d,
	vram_q       => vram_q,
	vram_u_n     => vram_u_n,
	vram_l_n     => vram_l_n,

	vram32_req   => vram32_req,
	vram32_ack   => vram32_ack,
	vram32_a     => vram32_a,
	vram32_q     => vram32_q,

	svp_ram1_req => svp_ram1_req,
	svp_ram1_ack => svp_ram1_ack,
	svp_ram1_we  => svp_ram1_we,
	svp_ram1_a   => svp_ram1_a,
	svp_ram1_d   => svp_ram1_d,
	svp_ram1_q   => svp_ram1_q,

	svp_ram2_req => svp_ram2_req,
	svp_ram2_ack => svp_ram2_ack,
	svp_ram2_we  => svp_ram2_we,
	svp_ram2_a   => svp_ram2_a,
	svp_ram2_d   => svp_ram2_d,
	svp_ram2_q   => svp_ram2_q,
	svp_ram2_u_n => svp_ram2_u_n,
	svp_ram2_l_n => svp_ram2_l_n,

	svp_rom_req  => svp_rom_req,
	svp_rom_ack  => svp_rom_ack,
	svp_rom_a    => "000" & svp_rom_a,
	svp_rom_q    => svp_rom_q
);

-- Genesis Core
-- -----------------------------------------------------------------------
-- -----------------------------------------------------------------------
-- -----------------------------------------------------------------------
-- -----------------------------------------------------------------------
fpgagen : work.fpgagen_top
port map (
	reset_n      => reset_n,
	MCLK         => MCLK,     --  54MHz

	DAC_LDATA    => DAC_LDATA,
	DAC_RDATA    => DAC_RDATA,

	RED          => RED,
	GREEN        => GREEN,
	BLUE         => BLUE,
	VS           => VS,
	HS           => HS,
	VBL          => VBL,
	HBL          => HBL,
	IN_BORDER    => IN_BORDER,
	CE_PIX       => CE_PIX,

	LED          => LED,

	DINA         => DINA,
	DOUTA        => DOUTA,
	OEA          => OEA,

	DINB         => DINB,
	DOUTB        => DOUTB,
	OEB          => OEB,

	saveram_addr => saveram_addr,
	saveram_we   => saveram_we,
	saveram_din  => saveram_din,
	saveram_rd   => saveram_rd,
	saveram_dout => saveram_dout,

	-- ROM Loader / Host boot data
	ext_reset_n  => ext_reset_n,
	ext_bootdone => ext_bootdone,
	ext_data     => ext_data,
	ext_data_req => ext_data_req,
	ext_data_ack => ext_data_ack,

	-- DIP switches
	ext_sw       => ext_sw,

	-- RAM/ROM interface
	romwr_req    => romwr_req,
	romwr_ack    => romwr_ack,
	romwr_a      => romwr_a,
	romwr_d      => romwr_d,

	romrd_req    => romrd_req,
	romrd_ack    => romrd_ack,
	romrd_a      => romrd_a,
	romrd_q      => romrd_q,

	ram68k_req   => ram68k_req,
	ram68k_ack   => ram68k_ack,
	ram68k_we    => ram68k_we,
	ram68k_a     => ram68k_a,
	ram68k_d     => ram68k_d,
	ram68k_q     => ram68k_q,
	ram68k_u_n   => ram68k_u_n,
	ram68k_l_n   => ram68k_l_n,

	sram_req     => sram_req,
	sram_ack     => sram_ack,
	sram_we      => sram_we,
	sram_a       => sram_a,
	sram_d       => sram_d,
	sram_q       => sram_q,
	sram_u_n     => sram_u_n,
	sram_l_n     => sram_l_n,

	vram_req     => vram_req,
	vram_ack     => vram_ack,
	vram_we      => vram_we,
	vram_a       => vram_a,
	vram_d       => vram_d,
	vram_q       => vram_q,
	vram_u_n     => vram_u_n,
	vram_l_n     => vram_l_n,

	vram32_req   => vram32_req,
	vram32_ack   => vram32_ack,
	vram32_a     => vram32_a,
	vram32_q     => vram32_q,

	svp_ram1_req => svp_ram1_req,
	svp_ram1_ack => svp_ram1_ack,
	svp_ram1_we  => svp_ram1_we,
	svp_ram1_a   => svp_ram1_a,
	svp_ram1_d   => svp_ram1_d,
	svp_ram1_q   => svp_ram1_q,

	svp_ram2_req => svp_ram2_req,
	svp_ram2_ack => svp_ram2_ack,
	svp_ram2_we  => svp_ram2_we,
	svp_ram2_a   => svp_ram2_a,
	svp_ram2_d   => svp_ram2_d,
	svp_ram2_q   => svp_ram2_q,
	svp_ram2_u_n => svp_ram2_u_n,
	svp_ram2_l_n => svp_ram2_l_n,

	svp_rom_req  => svp_rom_req,
	svp_rom_ack  => svp_rom_ack,
	svp_rom_a    => svp_rom_a,
	svp_rom_q    => svp_rom_q
	);

end rtl;
