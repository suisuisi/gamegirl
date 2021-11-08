----------------------------------------------------------------------------------
-- ep994a.vhd
--
-- Toplevel module. The design is intended for the Saanlima electronics Pepino
-- FPGA board. The extension pins on that board are connected to an external
-- board (prototype board as of 2016-10-30) housing a TMS99105 microprocessor,
-- it's clock oscillator and a 74LVC245 buffer chip. See schematics for details.
--
-- This file is part of the ep994a design, a TI-99/4A clone 
-- designed by Erik Piehl in October 2016.
-- Erik Piehl, Kauniainen, Finland, speccery@gmail.com
--
-- This is copyrighted software.
-- Please see the file LICENSE for license terms. 
--
-- NO WARRANTY, THE SOURCE CODE IS PROVIDED "AS IS".
-- THE SOURCE IS PROVIDED WITHOUT ANY GUARANTEE THAT IT WILL WORK 
-- FOR ANY PARTICULAR USE. IN NO EVENT IS THE AUTHOR LIABLE FOR ANY 
-- DIRECT OR INDIRECT DAMAGE CAUSED BY THE USE OF THE SOFTWARE.
--
-- Synthesized with Xilinx ISE 14.7.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.STD_LOGIC_UNSIGNED.ALL;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

--0000..1FFF     Console ROM
--2000..3FFF     (8K, part of 32K RAM expansion)
--4000..5FFF     (Peripheral cards ROM)
--6000..7FFF     Cartridge ROM (module port)
--8000..83FF     Scratchpad RAM (256 bytes, mirrored (partially decoded) across 8000..83FF)
--8400..87FF     Sound chip write
--8800..8BFF     VDP Read (8800 read, 8802 status)
--8C00..8FFF     VDP Write (8C00 write, 8C02 set address)
--9800..9BFF     GROM Read (9800 read, 9802 read addr+1)
--9C00..9FFF     GROM Write (9C00 write data, 9C02 write address)
--A000..FFFF     (24K, part of 32K RAM expansion)
----------------------------------------------------------------------------------
-- CRU map of the TI-99/4A
--0000..0FFE	  Internal use
--1000..10FE	  Unassigned
--1100..11FE	  Disk controller card
--1200..12FE	  Modems
--1300..13FE     RS232 (primary)
--1400..14FE     Unassigned
--1500..15FE     RS232 (secondary)
--1600..16FE     Unassigned
--...
----------------------------------------------------------------------------------
entity ep994a is
  generic (
    is_pal_g        : integer := 0;
    compat_rgb_g    : integer := 0
  );
  port (
    -- Global Interface -------------------------------------------------------
    clk_i           : in  std_logic;
    clk_en_10m7_i   : in  std_logic;
    reset_n_i       : in  std_logic;
    por_n_o         : out std_logic;
    -- Controller Interface ---------------------------------------------------
    -- GPIO port
    epGPIO_i        : in std_logic_vector(7 downto 0);
    epGPIO_o        : out std_logic_vector(8 downto 0);
    -- GPIO 0..7  = IO1P..IO8P - these are the keyboard row strobes.
    -- GPIO 8..15 = IO1N..IO8N - these are key input signals.
    -- CPU RAM Interface ------------------------------------------------------
    cpu_ram_a_o     : out std_logic_vector(18 downto 0);
    cpu_ram_ce_n_o  : out std_logic;
    cpu_ram_we_n_o  : out std_logic;
    cpu_ram_be_n_o  : out std_logic_vector( 1 downto 0);
    cpu_ram_d_i     : in  std_logic_vector(15 downto 0);
    cpu_ram_d_o     : out std_logic_vector(15 downto 0);
    -- Video RAM Interface ----------------------------------------------------
    vram_a_o        : out std_logic_vector(13 downto 0);
    vram_we_o       : out std_logic;
    vram_d_o        : out std_logic_vector( 7 downto 0);
    vram_d_i        : in  std_logic_vector( 7 downto 0);
    -- RGB Video Interface ----------------------------------------------------
    col_o           : out std_logic_vector( 3 downto 0);
    rgb_r_o         : out std_logic_vector( 7 downto 0);
    rgb_g_o         : out std_logic_vector( 7 downto 0);
    rgb_b_o         : out std_logic_vector( 7 downto 0);
    hsync_n_o       : out std_logic;
    vsync_n_o       : out std_logic;
    blank_n_o       : out std_logic;
    hblank_o        : out std_logic;
    vblank_o        : out std_logic;
    comp_sync_n_o   : out std_logic;
    -- Disk interface
    img_mounted     : in  std_logic_vector( 1 downto 0);
    img_wp          : in  std_logic_vector( 1 downto 0);
    img_size        : in  std_logic_vector(31 downto 0); -- in bytes

    sd_lba          : out std_logic_vector(31 downto 0);
    sd_rd           : out std_logic_vector( 1 downto 0);
    sd_wr           : out std_logic_vector( 1 downto 0);
    sd_ack          : in  std_logic;
    sd_buff_addr    : in  std_logic_vector( 8 downto 0);
    sd_dout         : in  std_logic_vector( 7 downto 0);
    sd_din          : out std_logic_vector( 7 downto 0);
    sd_dout_strobe  : in  std_logic;

    -- Audio Interface --------------------------------------------------------
    audio_total_o   : out std_logic_vector(10 downto 0);
    -- DEBUG (PS2 KBD port)
    --DEBUG1        : out std_logic;
    --DEBUG2        : out std_logic;

    -- SWITCHES (in reverse order compared to the markings)
    --SWI       : in std_logic_vector(7 downto 0);
    -- SWI 0: when set, CPU will automatically be taken out of reset after copying FLASH to RAM.

    speech_model     : in  std_logic_vector( 1 downto 0);
    sr_re_o          : out std_logic;
    sr_addr_o        : out std_logic_vector(14 downto 0);
    sr_data_i        : in  std_logic_vector( 7 downto 0);

    rommask_i        : in std_logic_vector(6 downto 1) := "111111";
    scratch_1k_i     : in std_logic;
    mbx_i            : in std_logic;
    flashloading_i   : in std_logic;
    turbo_i          : in std_logic
);

end ep994a;

-- pragma translate_off
use std.textio.all;
-- pragma translate_on

architecture Behavioral of ep994a is

	component fdc1772 is
		generic (
			MODEL            : integer := 1;
			CLK_EN           : integer := 2031;
			INVERT_HEAD_RA   : boolean := true;
			EXT_MOTOR        : boolean := true;
			IMG_TYPE         : integer := 3
		);
		port (
			clkcpu           : in  std_logic;
			clk8m_en         : in  std_logic;

			floppy_drive     : in  std_logic_vector( 3 downto 0);
			floppy_side      : in  std_logic;
			floppy_reset     : in  std_logic;
			floppy_motor     : in  std_logic;

			irq              : out std_logic;
			drq              : out std_logic;

			cpu_addr         : in  std_logic_vector( 1 downto 0);
			cpu_sel          : in  std_logic;
			cpu_rw           : in  std_logic;
			cpu_din          : in  std_logic_vector( 7 downto 0);
			cpu_dout         : out std_logic_vector( 7 downto 0);

			img_mounted      : in  std_logic_vector( 1 downto 0);
			img_wp           : in  std_logic_vector( 1 downto 0);
			img_ds           : in  std_logic;
			img_size         : in  std_logic_vector(31 downto 0); -- in bytes

			sd_lba           : out std_logic_vector(31 downto 0);
			sd_rd            : out std_logic_vector( 1 downto 0);
			sd_wr            : out std_logic_vector( 1 downto 0);
			sd_ack           : in  std_logic;
			sd_buff_addr     : in  std_logic_vector( 8 downto 0);
			sd_dout          : in  std_logic_vector( 7 downto 0);
			sd_din           : out std_logic_vector( 7 downto 0);
			sd_dout_strobe   : in  std_logic
		);
	end component ;

	--signal optSWI	 		: std_logic_vector(7 downto 0) := b"11111111";
	signal optSWI	 		: std_logic_vector(7 downto 0) := b"01111111";
	signal funky_reset 		: std_logic_vector(15 downto 0) := (others => '0');
	signal real_reset			: std_logic;
	signal real_reset_n		: std_logic;

	signal sram_addr_bus  : std_logic_vector(18 downto 0); 
	signal sram_16bit_read_bus : std_logic_vector(15 downto 0);	-- choose between (31..16) and (15..0) during reads.

	signal por_n_s          : std_logic;
	signal reset_n_s        : std_logic;
	signal switch           : std_logic;

	signal clk 					: std_logic;				-- output primary clock
	signal clk_en_3m58_s    : std_logic;
	signal clk_en_cpu_s     : std_logic;

	-- TMS99105 control signals
	signal cpu_addr			: std_logic_vector(15 downto 0);
	signal data_to_cpu		: std_logic_vector(15 downto 0);	-- data to CPU
	signal data_from_cpu		: std_logic_vector(15 downto 0);	-- data from CPU
	signal wr_sampler			: std_logic_vector(3 downto 0);
	signal rd_sampler			: std_logic_vector(3 downto 0);
	signal cruclk_sampler   : std_logic_vector(3 downto 0);
	signal cpu_access			: std_logic;		-- when '1' CPU owns the SRAM memory bus	
	signal mem_to_cpu   		: std_logic_vector(15 downto 0);

	-- VDP read and write signals
	signal vdp_wr 				: std_logic;
	signal vdp_rd 				: std_logic;
	signal vdp_data_out		: std_logic_vector(15 downto 0);
	signal vdp_interrupt		: std_logic; --low true

	-- GROM signals
	signal grom_data_out		: std_logic_vector(7 downto 0);
	signal grom_rd_inc		: std_logic;
	signal grom_we				: std_logic;
	signal grom_ram_addr		: std_logic_vector(19 downto 0);
	signal grom_selected		: std_logic;
	signal grom_rd				: std_logic;

	-- Keyboard control
	signal cru9901			: std_logic_vector(31 downto 0) := x"00000000";	-- 32 write bits to 9901, when cru9901(0)='0'
	signal cru9901_timer	: std_logic_vector(15 downto 0) := x"0000";	-- 15 write bits of 9901 when cru9901(0)='1' (bit 0 not used here)
	
	type keyboard_array is array (7 downto 0, 7 downto 0) of std_logic;
	signal keyboard : keyboard_array;
	
	signal cru_read_bit		: std_logic;

	-- Reset control
	signal cpu_reset_ctrl	: std_logic_vector(7 downto 0);	-- 8 control signals, bit 0 = reset, bit 1=rom bank reset, bit 2=mask interrupts when cleared
	signal cpu_single_step  : std_logic_vector(7 downto 0) := x"00";	-- single stepping. bit 0=1 single step mode, bit 1=1 advance one instruction	

	-- Module port banking
	signal basic_rom_bank : std_logic_vector(6 downto 1) := "000000";	-- latch ROM selection, 512K ROM support
	signal cartridge_cs	 : std_logic;	-- 0x6000..0x7FFF
	signal mbx_rom_bank : std_logic_vector(1 downto 0);

	-- SN76489 signal
	signal psg_ready_s      : std_logic;
	signal tms9919_we		: std_logic;		-- write enable pulse for the audio "chip"
	signal audio_data_out: std_logic_vector(7 downto 0);
	signal audio_o      : std_logic_vector( 7 downto 0);

	-- disk subsystem
	signal cru1100_regs  : std_logic_vector(7 downto 0); -- disk controller CRU select
	alias disk_page_ena  : std_logic is cru1100_regs(0);
	alias disk_motor_clk : std_logic is cru1100_regs(1);
	alias disk_wait_en   : std_logic is cru1100_regs(2);
	alias disk_hlt       : std_logic is cru1100_regs(3);
	alias disk_sel       : std_logic_vector(2 downto 0) is cru1100_regs(6 downto 4);
	alias disk_side      : std_logic is cru1100_regs(7);
	signal disk_ds       : std_logic;
	signal disk_motor_clk_d : std_logic;
	signal disk_motor    : std_logic;
	signal disk_motor_cnt: integer;
	signal disk_clk_en   : std_logic;
	signal disk_clk_cnt  : unsigned(4 downto 0);
	signal disk_cs       : std_logic;
	signal disk_rw       : std_logic;
	signal disk_rd       : std_logic;
	signal disk_wr       : std_logic;
	signal disk_rdy      : std_logic;
	signal disk_proceed  : std_logic;
	signal disk_irq      : std_logic;
	signal disk_drq      : std_logic;
	signal disk_atn      : std_logic;
	signal disk_din      : std_logic_vector(7 downto 0);
	signal disk_dout     : std_logic_vector(7 downto 0);

	-- Speech signals
	signal speech_data_out	: std_logic_vector(7 downto 0);
	signal speech_o       : signed(7 downto 0);
	signal speech_conv    : unsigned(10 downto 0);
	signal speech_i       : std_logic;
	
	-- SAMS memory extension
	signal sams_regs			: std_logic_vector(7 downto 0) := x"00";
	signal pager_data_in		: std_logic_vector(15 downto 0);
	signal pager_data_out   : std_logic_vector(15 downto 0);
	signal translated_addr  : std_logic_vector(15 downto 0);
	signal paging_enable    : std_logic := '0';
	signal paging_registers : std_logic;
	signal paging_wr_enable : std_logic;
	signal page_reg_read		: std_logic;
	signal paging_enable_cs : std_logic;	-- access to some registers to enable paging etc.
	signal paging_regs_visible : std_logic;	-- when 1 page registers can be accessed
	-- signal pager_extended   : std_logic;
	
	-- TMS99105 Shield control latch signals (written to control latch during control cycle)
--	signal conl_led1  : std_logic;	-- IO8P - indata[7]
--	signal conl_led2  : std_logic;	-- IO7P - indata[6]
	signal conl_app_n : std_logic;
	signal conl_ready : std_logic;
	signal conl_hold  : std_logic;
	signal conl_nmi   : std_logic;
	signal conl_int   : std_logic;	-- IO2P - indata[1]
	signal conl_reset : std_logic;	-- IO1P - indata[0]
	-- TMS99105 Shield control signal buffer read signals (read during control control cycle)
	signal WE_n			: std_logic;	-- IO1N - indata[8]
	signal MEM_n		: std_logic;	-- IO2N - indata[9]
	signal BST1			: std_logic;	-- IO6N - indata[13]
	signal BST2			: std_logic;	-- IO7N - indata[14]
	signal BST3			: std_logic;	-- IO8N - indata[15]
--	signal bus_oe_n_internal : std_logic;
	-- when to write to places
	signal go_write   : std_logic;
	
	signal go_cruclk : std_logic;	-- CRUCLK write pulses from the soft TMS9900 core

-------------------------------------------------------------------------------	
-- Signals from FPGA CPU
-------------------------------------------------------------------------------	
	signal RD_n   : std_logic;
	signal cpu_rd : std_logic;
	signal cpu_wr : std_logic;	
	signal cpu_ready : std_logic;
	signal cpu_iaq : std_logic;
	signal cpu_as : std_logic;
	
	signal cpu_cruin : std_logic;
	signal cpu_cruout : std_logic;
	signal cpu_cruclk : std_logic;
	signal cpu_stuck : std_logic;
	
	signal cpu_hold : std_logic;
	signal cpu_holda : std_logic;
	
	signal cpu_reset : std_logic;
	signal cpu_debug_out : STD_LOGIC_VECTOR (95 downto 0);
	signal alu_debug_arg1 : STD_LOGIC_VECTOR (15 downto 0);
	signal alu_debug_arg2 : STD_LOGIC_VECTOR (15 downto 0);
	
	signal cpu_int_req : std_logic;
	signal cpu_ic03    : std_logic_vector(3 downto 0) := "0001";
	signal cpu_int_ack : std_logic;
	
	signal waits : std_logic_vector(7 downto 0);
-------------------------------------------------------------------------------	
-- Signals for SPI Flash controller
-------------------------------------------------------------------------------	
	signal flashLoading : std_logic;
	signal lastFlashLoading : std_logic;	-- last state of flashLoading

-------------------------------------------------------------------------------

begin

	-----------------------------------------------------------------------------
	-- Reset generation
	-----------------------------------------------------------------------------
	por_b : work.cv_por
	port map (
		clk_i   => clk_i,
		por_n_o => por_n_s
	);
	por_n_o   <= por_n_s;
	reset_n_s <= reset_n_i;--por_n_s and reset_n_i;


	-----------------------------------------------------------------------------
	-- Clock generation
	-----------------------------------------------------------------------------
	clock_b : work.cv_clock
	port map (
		clk_i         => clk_i,
		clk_en_10m7_i => clk_en_10m7_i,
		reset_n_i     => reset_n_s,
		clk_en_3m58_p_o => clk_en_3m58_s
	);

	clk <= clk_i;

	-------------------------------------

	cpu_ram_be_n_o <= "00"; -- TMS99105 is always 16-bit, use CE 
	cpu_ram_a_o    <= sram_addr_bus;
	cpu_ram_d_o    <= data_from_cpu;

	sram_16bit_read_bus <= cpu_ram_d_i;

	process(clk, switch)
	begin
		if rising_edge(clk) then
			if cpu_access = '0' then
				cpu_ram_ce_n_o <= '1';
				cpu_ram_we_n_o <= '1';
			else
				cpu_ram_ce_n_o	<= MEM_n;
				if MEM_n = '0' and WE_n = '0'
					and cpu_addr(15 downto 12) /= x"9"        -- 9XXX addresses don't go to RAM
					and cpu_addr(15 downto 11) /= x"8" & '1'  -- 8800-8FFF don't go to RAM
					and cpu_addr(15 downto 13) /= "000"       -- 0000-1FFF don't go to RAM
					and cpu_addr(15 downto 13) /= "010"       -- 4000-5FFF don't go to RAM
					and (cartridge_cs='0'                     -- writes to cartridge region do not go to RAM
						or (mbx_i='1' and cpu_addr(15 downto 10) = "011011"))
				then
					cpu_ram_we_n_o <= '0';
				else
					cpu_ram_we_n_o <= '1';
				end if;
			end if;
		end if;
	end process;

	-------------------------------------size

	-- CPU reset out. If either cpu_reset_ctrl(0) or funky_reset(MSB) is zero, put CPU to reset.
	real_reset <= funky_reset(funky_reset'length-1);
	real_reset_n <= not real_reset;
	conl_reset <= cpu_reset_ctrl(0) and real_reset;

	cpu_access <= not cpu_holda;	-- CPU owns the bus except when in hold

	-------------------------------------
	-- vdp interrupt
	-- INTERRUPT <=  vdp_interrupt when cru9901(2)='1' else '1';	-- TMS9901 interrupt mask bit
	conl_int <= vdp_interrupt when cru9901(2)='1' else '1';	-- TMS9901 interrupt mask bit
	-- cartridge memory select
	cartridge_cs 	<= '1' when MEM_n = '0' and cpu_addr(15 downto 13) = "011" else '0'; -- cartridge_cs >6000..>7FFF

	-------------------------------------
	-- key matrix support
	--epGPIO(15 downto 8) <= "ZZZZZZZZ";	-- IO1N..IO8N are inputs
	-- KBD connector signals
	-- 15 | IO8P | col#3
	-- 14 | IO7P | col#2	
	-- 13 | IO6P | col#1	
	-- 12 | IO5P | col#0	
	--  9 | IO4P | col#4	
	--  8 | IO3P | col#5
	--epGPIO(1 downto 0) <= "ZZ";	-- unused
	-- For the column decoder, rely on pull-ups to bring the row selectors high
	epGPIO_o(8) <= cru9901(21); 	-- alpha-lock
	epGPIO_o(7) <= '0' when cru9901(20 downto 18) = "011" else '1'; 	-- col#3
	epGPIO_o(6) <= '0' when cru9901(20 downto 18) = "010" else '1'; 	-- col#2
	epGPIO_o(5) <= '0' when cru9901(20 downto 18) = "001" else '1'; 	-- col#1
	epGPIO_o(4) <= '0' when cru9901(20 downto 18) = "000" else '1'; 	-- col#0
	epGPIO_o(3) <= '0' when cru9901(20 downto 18) = "100" else '1'; 	-- col#4
	epGPIO_o(2) <= '0' when cru9901(20 downto 18) = "101" else '1'; 	-- col#5
	epGPIO_o(1) <= '0' when cru9901(20 downto 18) = "110" else '1'; 	-- col#6
	epGPIO_o(0) <= '0' when cru9901(20 downto 18) = "111" else '1'; 	-- col#7
	-------------------------------------
	speech_i <= '0' when speech_model = "11" else '1';

	switch <= not reset_n_s;
	flashloading <= flashloading_i;--'0';

	process(clk, switch)
	begin
		if rising_edge(clk) then 	-- our 100 MHz clock
			-- If SWI(0) is set then automatically bring CPU out of reset once FPGA has moved
			-- data from flash memory to SRAM.
			cpu_reset <= not (cpu_reset_ctrl(0) and real_reset and not flashLoading);
			lastFlashLoading <= flashLoading;
			if optSWI(0) = '1' then 
				if flashLoading='1' then
					cpu_reset_ctrl <= x"FC";	-- during flash loading force reset on
				end if;
				if flashLoading='0' and lastFlashLoading='1' then
					-- flash loading just stopped. Bring CPU out of reset.
					cpu_reset_ctrl <= x"FF";
				end if;
			end if;
		end if;
	end process;

	process(clk, switch)
	variable ki : integer range 0 to 7;
	begin
		if rising_edge(clk) then 	-- our 100 MHz clock
			-- reset generation
			if switch = '1' then
				funky_reset <= (others => '0');	-- button on the FPGA board pressed
			else
				funky_reset <= funky_reset(funky_reset'length-2 downto 0) & '1';
			end if;

			if optSWI(0) = '1' then 
				if flashLoading='1' then
					basic_rom_bank <= (others => '0');
					mbx_rom_bank <= (others => '0');
					sams_regs <= x"00";
				end if;
			end if;

			-- reset processing
			if funky_reset(funky_reset'length-1) = '0' then
				-- reset activity here
				cru9901 <= x"00000000";
				cru1100_regs <= (others => '0');
				sams_regs <= (others => '0');
				
				conl_app_n  <= '1';
				conl_ready  <= '1';
				conl_hold 	<= '1';
				conl_nmi 	<= '1';

				cpu_single_step <= x"00";
				
				waits <= (others => '0');
			else
				-- processing of normal clocks here. We run at 100MHz.

				-- First manage CPU wait states
				-- if switch 1 (SWI[7]) is set we run at 63 wait states
				-- if switch 2 (SWI[6]) is set we run at 31 wait states
				-- if switch 2 (SWI[5]) is set we run at 8 wait states
				-- else we run at zero wait states
				if optSWI(7)='1' then
					if cpu_as='1' then
						-- setup number of wait states depending on address accessed
						case cpu_addr(15 downto 12) is
							when x"0" => waits <= x"60"; -- ROM an scratchpad 640 ns
							when x"1" => waits <= x"60";
							when x"8" => waits <= x"60"; -- scratchpad and I/O
							when others =>
								waits <= x"F0";	-- 196, i.e. 200, i.e. 2000ns
						end case;
					end if;
				elsif optSWI(6)='1' then
					waits <= x"1F";
				elsif optSWI(5)='1' then
					waits <= x"08";
				else
					waits <= (others => '0');
				end if;

				---------------------------------------------------------
				-- SRAM map (1 mega byte, 0..FFFFF, 20 bit address space)
				---------------------------------------------------------
				-- 00000..7FFFF - Cartridge module port, paged, 512K, to support the TI megademo :)
				-- 80000..8FFFF - GROM mapped to this area, 64K (was at 30000)
				-- 90000..AFFFF - Not used currently
				-- B0000..B7FFF - DSR area, 32K reserved	(was at 60000)
				-- B8000..B8FFF - Scratchpad 	(was at 68000)
				-- BA000..BCFFF - Boot ROM remapped (was at 0)   
				-- C0000..FFFFF - SAMS SRAM 256K (i.e. the "normal" CPU RAM paged with the SAMS system)
				---------------------------------------------------------
				-- The SAMS control bits are set to zero on reset.
				-- sams_regs(0) CRU 1E00: when set, paging registers appear at DSR space >4000..
				-- sams_regs(1) CRU 1E02: when set, paging is enabled
				-- sams_regs(2) CRU 1E04: unused
				-- sams_regs(3) CRU 1E06: unused
				-- The memory paging CRU register control bits can be used
				-- to remove devices from the CPU's address space, revealing the
				-- underlying pageable RAM:
				-- sams_regs(4) CRU 1E08: when set, ROM is out and pageable RAM instead is available
				-- sams_regs(5) CRU 1E0A: when set, cartridge is out and pageable RAM instead is available
				--								  Also writes to cartridge area do not change the cartridge page during this time.
				-- sams_regs(6) CRU 1E0C: when set I/O devices are out and pageable RAM instead is available
				-- sams_regs(7) CRU 1E0E: unused
				-- Also, when disk DSR ROM are not mapped (CRU >1100=0) or SAMS page registers visible (>1E00=0)
				--	the pageable RAM "under" the DSR space is available.
				-- Thus the entire 64K is pageable.
				---------------------------------------------------------

				-- Drive SRAM addresses outputs synchronously 
				if cpu_access = '1' then
					if cpu_addr(15 downto 8) = x"98" and cpu_addr(1)='0' then
						sram_addr_bus <= x"8" & grom_ram_addr(15 downto 1);	-- 0x80000 GROM
					elsif cartridge_cs = '1' and mbx_i = '1' and cpu_addr(12 downto 10) = "011" then
						-- MBX 6c00-6FFF - RAM
						sram_addr_bus <= "0000010" & cpu_addr(12 downto 1);
					elsif cartridge_cs = '1' and mbx_i = '1' and cpu_addr(12) = '1' then
						-- MBX 7000-7FFF - bank switched area
						sram_addr_bus <= "000000" & mbx_rom_bank & cpu_addr(11 downto 1);
					elsif cartridge_cs = '1' and sams_regs(5) = '0' then
						-- Handle paging of module port at 0x6000 unless sams_regs(5) is set (1E0A)
						sram_addr_bus <= '0' & (basic_rom_bank and rommask_i) & cpu_addr(12 downto 1);	-- mapped to 0x00000..0x7FFFF
					elsif disk_page_ena='1' and cpu_addr(15 downto 13) = "010" then	
						-- DSR's for disk system
						sram_addr_bus <= x"B" & "000" & cpu_addr(12 downto 1);	-- mapped to 0xB0000
					elsif cpu_addr(15 downto 13) = "000" and sams_regs(4) = '0' then
						-- ROM at the bottom of address space not paged unless sams_regs(4) is set (1E08)
						sram_addr_bus <= x"B" & "101" & cpu_addr(12 downto 1);	-- mapped to 0xBA000
					elsif cpu_addr(15 downto 10) = "100000" then
						-- now that paging is introduced we need to move scratchpad (1k here)
						-- out of harm's way. Scartchpad at B8000 to keep it safe from paging.
						if scratch_1k_i='1' then
							sram_addr_bus <= x"B8" & "00" & cpu_addr(9 downto 1);
						else
							sram_addr_bus <= x"B8" & X"3" & cpu_addr(7 downto 1);
						end if;
					else
						-- regular RAM access
						-- Top 256K is CPU SAMS RAM for now, so we have 18 bit memory addresses for RAM
						sram_addr_bus <= "11" & translated_addr(5 downto 0) & cpu_addr(11 downto 1);
					end if;
				end if;

				if cpu_single_step(1 downto 0)="11" and cpu_holda = '0' then
					-- CPU single step is desired, and CPU is out of hold despite cpu_singe_step(0) being '1'.
					-- This must mean that the CPU is started to execute an instruction, so zero out bit 1
					-- which controls the stepping.
					cpu_single_step(1) <= '0';	
				end if;

				if cpu_reset_ctrl(1)='0' then
					basic_rom_bank <= "000000";	-- Reset ROM bank selection
					mbx_rom_bank <= "00";
				end if;

				-- CPU signal samplers
				wr_sampler <= wr_sampler(wr_sampler'length-2 downto 0) & WE_n;
				rd_sampler <= rd_sampler(rd_sampler'length-2 downto 0) & RD_n;
				cruclk_sampler <= cruclk_sampler(cruclk_sampler'length-2 downto 0) & cpu_cruclk;

				vdp_wr <= '0';
				vdp_rd <= '0';
				grom_we <= '0';
				if (psg_ready_s = '1') then
					tms9919_we <= '0';
				end if;				
				paging_wr_enable <= '0';
				if sams_regs(6)='0' then	-- if sams_regs(6) is set I/O is out and paged RAM is there instead
					if cpu_wr = '1' then
						if cpu_addr(15 downto 8) = x"8C" then
							vdp_wr <= '1';
						elsif cpu_addr(15 downto 8) = x"9C" then
							grom_we <= go_write;			-- GROM writes
						elsif cartridge_cs='1' and sams_regs(5)='0' and mbx_i = '0' then
							basic_rom_bank <= cpu_addr(6 downto 1);	-- capture ROM bank select
						elsif cartridge_cs='1' and cpu_addr(12 downto 1)='0'&x"FF"&"111" and mbx_i = '1' then -- mbx bank switch (>6FFE)
							mbx_rom_bank <= data_from_cpu(9 downto 8);
						elsif cpu_addr(15 downto 8) = x"84" then	
							tms9919_we <= '1';		-- Audio chip write
							audio_data_out <= data_from_cpu(15 downto 8);
						elsif paging_registers = '1' then 
							paging_wr_enable <= go_write;
						end if;
					end if;	
					if cpu_rd = '1' and cpu_addr(15 downto 8)=x"88" then
						vdp_rd <= '1';
					end if;
					grom_rd <= '0';
					if MEM_n='0' and rd_sampler(1 downto 0)="00" and cpu_addr(15 downto 8) = x"98" then
						grom_rd <= '1';
					end if;
				end if;

				-- CRU cycle to TMS9901
				if MEM_n='1' and cpu_addr(15 downto 8)=x"00" and go_cruclk = '1' then

					if cru9901(0) = '1' and cpu_addr(5)='0' and cpu_addr(4 downto 1) /= "0000" then
						-- write to timer bits (not bit 0)
						cru9901_timer(to_integer(unsigned(cpu_addr(4 downto 1)))) <= cpu_cruout;
					else
						-- write to main register
						cru9901(to_integer(unsigned(cpu_addr(5 downto 1)))) <= cpu_cruout;
					end if;

				end if;

				-- CRU write cycle to disk control system
				if MEM_n='1' and cpu_addr(15 downto 4)= x"110" and go_cruclk = '1' then
					cru1100_regs(to_integer(unsigned(cpu_addr(3 downto 1)))) <= cpu_cruout;
				end if;
				-- SAMS register writes. 
				if MEM_n='1' and cpu_addr(15 downto 4) = x"1E0" and go_cruclk = '1' then
					sams_regs(to_integer(unsigned(cpu_addr(3 downto 1)))) <= cpu_cruout;
				end if;				

				-- Precompute cru_read_bit in case this cycle is a CRU read 
				cru_read_bit <= '1';
--				if cru9901(20 downto 18)="101" and cpu_addr(15 downto 1) & '0' = x"000E" then
--					-- key "1" CRU is connected to switch
--					cru_read_bit <= '1';
--					if switch = '1' or keyboard(5, 4)='0' then
--						cru_read_bit <= '0';
--					end if;
--				els
				if cpu_addr(15 downto 1) & '0' >= 6 and cpu_addr(15 downto 1) & '0' < 22 then
					-- 6 = 0110
					--	8 = 1000
					-- A = 1010 
					ki := to_integer(unsigned(cpu_addr(3 downto 1))) - 3; -- row select on address
--					cru_read_bit <= keyboard(to_integer(unsigned(cru9901(20 downto 18))), ki); -- column select on multiplexor select
					case ki is
						when 0 => cru_read_bit <= epGPIO_i(0);
						when 1 => cru_read_bit <= epGPIO_i(1);
						when 2 => cru_read_bit <= epGPIO_i(2);
						when 3 => cru_read_bit <= epGPIO_i(3);
						when 4 => cru_read_bit <= epGPIO_i(4);
						when 5 => cru_read_bit <= epGPIO_i(5);
						when 6 => cru_read_bit <= epGPIO_i(6);
						when 7 => cru_read_bit <= epGPIO_i(7);
						when others => null;
					end case;

				elsif cpu_addr(15 downto 1) & '0' = x"0004" then
					cru_read_bit <= vdp_interrupt; -- VDP interrupt status (read with TB 2 instruction)
				elsif cpu_addr(15 downto 1) & '0' = x"0000" then
					cru_read_bit <= cru9901(0);
				elsif cpu_addr(15 downto 5) = "00000000001" then
					-- TMS9901 bits 16..31, addresses 20..3E
					cru_read_bit <= cru9901(to_integer(unsigned('1' & cpu_addr(4 downto 1))));
				elsif cpu_addr(15 downto 4) = x"110" then
					case to_integer(unsigned(cpu_addr(3 downto 1))) is
						when 0 => cru_read_bit <= disk_hlt; -- HLD
						when 1 => cru_read_bit <= cru1100_regs(4) and disk_motor; -- DS1
						when 2 => cru_read_bit <= cru1100_regs(5) and disk_motor; -- DS2
						when 3 => cru_read_bit <= cru1100_regs(6) and disk_motor; -- DS3
						when 4 => cru_read_bit <= not disk_motor;
						when 5 => cru_read_bit <= '0';
						when 6 => cru_read_bit <= '1';
						when 7 => cru_read_bit <= disk_side;
						when others => null;
					end case;
				elsif cpu_addr(15 downto 4) = x"1E0" then
					cru_read_bit <= sams_regs(to_integer(unsigned(cpu_addr(3 downto 1))));
				end if;
			end if;
		end if;	-- rising_edge
	end process;

	cpu_hold <= '1' when (cpu_single_step(0)='1' and cpu_single_step(1)='0') 
							or flashLoading = '1' else '0'; -- issue DMA request

	go_write <= '1' when wr_sampler = "1000" else '0'; -- wr_sampler = "1110" else '0';
	go_cruclk <= '1' when cruclk_sampler(1 downto 0) = "01" else '0';

	vdp_data_out(7 downto 0) <= x"00";
	data_to_cpu <= 
		vdp_data_out         			when sams_regs(6)='0' and cpu_addr(15 downto 10) = "100010" else	-- 10001000..10001011 (8800..8BFF)
		speech_data_out & x"00"       when sams_regs(6)='0' and cpu_addr(15 downto 10) = "100100" and speech_i='1' else	-- speech address read (9000..93FF)
		x"6000"                       when sams_regs(6)='0' and cpu_addr(15 downto 10) = "100100" and speech_i='0' else	-- speech address read (9000..93FF)
		grom_data_out & x"00" 			when sams_regs(6)='0' and cpu_addr(15 downto 8) = x"98" and cpu_addr(1)='1' else	-- GROM address read
		pager_data_out(7 downto 0) & pager_data_out(7 downto 0) when paging_registers = '1' else	-- replicate pager values on both hi and lo bytes
		sram_16bit_read_bus(15 downto 8) & x"00" when sams_regs(6)='0' and cpu_addr(15 downto 8) = x"98" and cpu_addr(1)='0' and grom_ram_addr(0)='0' and grom_selected='1' else
		sram_16bit_read_bus(7 downto 0)  & x"00" when sams_regs(6)='0' and cpu_addr(15 downto 8) = x"98" and cpu_addr(1)='0' and grom_ram_addr(0)='1' and grom_selected='1' else
		x"FF00"                       when sams_regs(6)='0' and cpu_addr(15 downto 8) = x"98" and cpu_addr(1)='0' and grom_selected='0' else
		-- CRU space signal reads
		cru_read_bit & "000" & x"000"	when MEM_n='1' else
		x"FFF0"								when MEM_n='1' else -- other CRU
		-- line below commented, paged memory repeated in the address range as opposed to returning zeros outside valid range
		--	x"0000"							when translated_addr(15 downto 6) /= "0000000000" else -- paged memory limited to 256K for now
		not disk_dout&not disk_dout when disk_cs = '1' else
		sram_16bit_read_bus(15 downto 0);		-- data to CPU

	-----------------------------------------------------------------------------
	-- TMS9928A Video Display Processor
	-----------------------------------------------------------------------------
	vdp18_b : work.vdp18_core
	generic map (
		is_pal_g      => is_pal_g,
		compat_rgb_g  => compat_rgb_g
	)
	port map (
		clk_i         => clk_i,
		clk_en_10m7_i => clk_en_10m7_i,
		reset_n_i     => real_reset,--
		csr_n_i       => not vdp_rd,--
		csw_n_i       => not vdp_wr,--
		mode_i        => cpu_addr(1),
		int_n_o       => vdp_interrupt,--
		cd_i          => data_from_cpu(15 downto 8),--
		cd_o          => vdp_data_out(15 downto 8),--
		vram_we_o     => vram_we_o,
		vram_a_o      => vram_a_o,
		vram_d_o      => vram_d_o,
		vram_d_i      => vram_d_i,
		col_o         => col_o,
		rgb_r_o       => rgb_r_o,
		rgb_g_o       => rgb_g_o,
		rgb_b_o       => rgb_b_o,
		hsync_n_o     => hsync_n_o,
		vsync_n_o     => vsync_n_o,
		--blank_n_o     => blank_n_o,
		--hblank_o      => hblank_o,
		--vblank_o      => vblank_o,
		comp_sync_n_o => comp_sync_n_o
	);

	-- GROM implementation - GROM's are mapped to external RAM
	extbasgrom : entity work.gromext port map (
		clk 		=> clk,
		din 		=> data_from_cpu(15 downto 8),
		dout		=> grom_data_out,
		we 		=> grom_we,
		rd 		=> grom_rd,
		selected => grom_selected,	-- output from GROM available, i.e. GROM address is ours
		mode 		=> cpu_addr(5 downto 1),
		reset 	=> real_reset_n,
		addr 		=> grom_ram_addr
	);

	-----------------------------------------------------------------------------
	-- SN76489 Programmable Sound Generator
	-----------------------------------------------------------------------------
	psg_b : work.sn76489_top
	generic map (
		clock_div_16_g => 1
	)
	port map (
		clock_i    => clk_i,
		clock_en_i => clk_en_3m58_s,
		res_n_i    => real_reset,--
		ce_n_i     => not tms9919_we,--
		we_n_i     => not tms9919_we,--
		ready_o    => psg_ready_s,--
		d_i        => audio_data_out,--
		aout_o     => audio_o
	);

	-- memory paging unit implementation
	paging_regs_visible 	<= sams_regs(0);			-- 1E00 in CRU space
	paging_enable 			<= sams_regs(1);			-- 1E02 in CRU space

	-- the pager registers can be accessed at >4000 to >5FFF when paging_regs_visible is set
	paging_registers <= '1' when paging_regs_visible = '1' and (cpu_rd='1' or cpu_wr='1') and cpu_addr(15 downto 13) = "010" else '0';
	page_reg_read <= '1' when paging_registers = '1' and cpu_rd ='1' else '0';	

	pager_data_in <= x"00" & data_from_cpu(15 downto 8);	-- my own extended mode not supported here

	pager : work.pager612 port map (
		clk		 => clk,
		abus_high => cpu_addr(15 downto 12),
		abus_low  => cpu_addr(4 downto 1),
		dbus_in   => pager_data_in,
		dbus_out  => pager_data_out,
		mapen 	 => paging_enable,
		write_enable	 => paging_wr_enable,
		page_reg_read   => page_reg_read,
		translated_addr => translated_addr,
		access_regs     => paging_registers
		);

	MEM_n <= not (cpu_rd or cpu_wr);
	WE_n <= not cpu_wr;
	RD_n <= not cpu_rd;
	cpu_cruin <= cru_read_bit;
	cpu_int_req <= not conl_int and cpu_reset_ctrl(2);	-- cpu_reset_ctrl(2), when cleared, allows us to mask interrupts

	cpu : work.tms9900
		generic map (
			cycle_clks_g => 14
		)
	PORT MAP (
		clk => clk,
		reset => cpu_reset,
		addr_out => cpu_addr,
		data_in => data_to_cpu,
		data_out => data_from_cpu,
		rd => cpu_rd,
		wr => cpu_wr,
		ready => cpu_ready,
		iaq => cpu_iaq,
		as => cpu_as,
--		test_out => test_out,
--		alu_debug_out => alu_debug_out,
--		alu_debug_oper => alu_debug_oper,
		alu_debug_arg1 => alu_debug_arg1,
		alu_debug_arg2 => alu_debug_arg2,
		int_req => cpu_int_req,
		ic03 => cpu_ic03,
		int_ack => cpu_int_ack,
		cpu_debug_out => cpu_debug_out,
		cruin => cpu_cruin,
		cruout => cpu_cruout,
		cruclk => cpu_cruclk,
		hold => cpu_hold,
		holda => cpu_holda,
		waits => waits,
		scratch_en => '0',
		stuck => cpu_stuck,
		turbo => turbo_i
	);

	speech : work.tispeechsyn
	PORT MAP (
		clk_i => clk,
		reset_n_i => not cpu_reset,
		addr_i => cpu_addr,
		data_o => speech_data_out,
		data_i => data_from_cpu(15 downto 8),
		MEM_n_i => MEM_n,
		dbin_i => cpu_rd,
		ready_o => open, --could use this
		aout_o => speech_o,
		sr_re_o => sr_re_o,
		sr_addr_o => sr_addr_o,
		sr_data_i => sr_data_i,
		model => speech_model
	);

	speech_conv <= unsigned(resize(speech_o,speech_conv'length)) + to_unsigned(128,11) when speech_i = '1' else to_unsigned(0,speech_conv'length);
	audio_total_o <= std_logic_vector(unsigned("0" & audio_o & "00") + speech_conv);

	-----------------------------------------------------------------------------
	-- Disk subsystem (PHP1240)
	-----------------------------------------------------------------------------
	disk_ds <= '1' when unsigned(img_size(19 downto 8)) > 360 else '0';
	disk_cs <= '1' when disk_page_ena = '1' and cpu_addr(15 downto 4) = x"5FF" and (disk_rd = '1' or disk_wr = '1') else '0';
	disk_rd <= not cpu_addr(3) and cpu_rd;
	disk_wr <= cpu_addr(3) and cpu_wr;
	disk_rw <= not disk_wr;
	disk_din <= not data_from_cpu(15 downto 8);

	fdc : fdc1772
	port map
	(
		clkcpu  => clk,
		clk8m_en => disk_clk_en,

		floppy_drive => "11"&not disk_sel(1 downto 0),
		floppy_side => not disk_side,
		floppy_reset => reset_n_s,
		floppy_motor => disk_motor,

		irq => disk_irq,
		drq => disk_drq,

		cpu_addr => cpu_addr(2 downto 1),
		cpu_sel => disk_cs,
		cpu_rw => disk_rw,
		cpu_din => disk_din,
		cpu_dout => disk_dout,

		-- The following signals are all passed in from the Top module
		img_mounted => img_mounted,
		img_wp => img_wp,
		img_size => img_size,
		img_ds => disk_ds,

		sd_lba => sd_lba,
		sd_rd => sd_rd,
		sd_wr => sd_wr,
		sd_ack => sd_ack,
		sd_buff_addr => sd_buff_addr,
		sd_dout => sd_dout,
		sd_din => sd_din,
		sd_dout_strobe => sd_dout_strobe
	);

	process(clk, reset_n_s)
	begin
		if reset_n_s = '0' then
			disk_clk_en <= '0';
		elsif rising_edge(clk) then
			disk_clk_cnt <= disk_clk_cnt + 1;
			disk_clk_en <= '0';
			if disk_clk_cnt = 20 then
				disk_clk_en <= '1';
				disk_clk_cnt <= (others => '0');
			end if;
		end if;
	end process;

	-- LS123 monostable, 4.5 sec pulse
	process(clk, reset_n_s)
	begin
		if reset_n_s = '0' then
			disk_motor <= '0';
			disk_motor_cnt <= 0;
		elsif rising_edge(clk) then
			disk_motor_clk_d <= disk_motor_clk;
			if disk_motor_clk_d = '0' and disk_motor_clk = '1' then
				disk_motor <= '1';
				disk_motor_cnt <= 191970000;
			elsif disk_motor_cnt /= 0 then
				disk_motor_cnt <= disk_motor_cnt - 1;
			else
				disk_motor <= '0';
			end if;
		end if;
	end process;

	cpu_ready <= disk_rdy;
	disk_rdy <= '1' when disk_wait_en = '0' or disk_proceed = '1' or disk_cs = '0' else '0';
	-- disk wait generation
	process(clk, reset_n_s)
	begin
		if reset_n_s = '0' then
			disk_proceed <= '0';
		elsif rising_edge(clk) then
			disk_atn <= disk_irq or disk_drq;
			if disk_cs = '0' then
				disk_proceed <= '0';
			elsif disk_atn = '0' and (disk_irq or disk_drq) = '1' then
				disk_proceed <= '1';
			end if;
		end if;
	end process;

end Behavioral;
