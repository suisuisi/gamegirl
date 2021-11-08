---------------------------------------------------------------------------
-- (c) 2013 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all; 
use IEEE.STD_LOGIC_MISC.all;
use ieee.numeric_std.all;

LIBRARY work;

-- There is a higher level that just wires up internal ROM/RAM/joysticks to demonstrate how to use this
-- Also see board specific top levels
ENTITY atari800xl IS 
	PORT
	(
		CLK :  IN  STD_LOGIC; -- cycle_length*1.79MHz
		RESET_N : IN STD_LOGIC;

		-- VIDEO OUT - PAL/NTSC, original Atari timings approx (may be higher res)
		VIDEO_VS :  OUT  STD_LOGIC;
		VIDEO_HS :  OUT  STD_LOGIC;
		VIDEO_CS :  OUT  STD_LOGIC;
		COLOUR :  OUT  STD_LOGIC_VECTOR(7 DOWNTO 0);
		VIDEO_BLANK : out std_logic;
		VIDEO_BURST : out std_logic;
		VIDEO_START_OF_FIELD : out std_logic;
		VIDEO_ODD_LINE : out std_logic;

		-- AUDIO OUT - Pokey/GTIA 1-bit and Covox all mixed
		AUDIO_L : OUT std_logic_vector(15 downto 0);
		AUDIO_R : OUT std_logic_vector(15 downto 0);
		SIO_AUDIO : IN std_logic_vector(7 downto 0);

		-- PIA
		CA1_IN : IN STD_LOGIC; -- SIO Proceed
		CB1_IN : IN STD_LOGIC; -- SIO IRQ
		CA2_IN : IN STD_LOGIC; -- SIO Motor control
		CA2_OUT : OUT STD_LOGIC; 
		CA2_DIR_OUT: OUT STD_LOGIC; -- 1=output mode
		CB2_IN: IN STD_LOGIC;
		CB2_OUT : OUT STD_LOGIC; -- SIO Command
		CB2_DIR_OUT: OUT STD_LOGIC; -- 1=output mode
		PORTA_IN : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- For joystick
		PORTA_OUT : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		PORTA_DIR_OUT : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		PORTB_IN : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- For bank switching on XL/XE, for joystick on 800
		PORTB_OUT : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		PORTB_DIR_OUT : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);

		-- Pokey keyboard matrix
		-- Standard component available to connect this to PS2
		KEYBOARD_RESPONSE : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
		KEYBOARD_SCAN : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);

		-- Pokey pots
		POT_IN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		POT_RESET : OUT STD_LOGIC;

		-- CARTRIDGE ACCESS
		-- (R/W/DO on PBI)
		CART_RD4 : in STD_LOGIC;
		CART_RD5 : in STD_LOGIC;
		CART_S4_n : out STD_LOGIC;
		CART_S5_N : out STD_LOGIC;
		CART_CCTL_N : out std_logic;

		-- PBI
		PBI_MPD_N : in STD_LOGIC;
		PBI_REF_N_IN : in STD_LOGIC;
		PBI_EXTSEL_N : in STD_LOGIC;
		PBI_CAS : out STD_LOGIC;
		PBI_RAS : out STD_LOGIC;
		PBI_CAS_INHIBIT : out STD_LOGIC;
		PBI_REF_N_OUT : out STD_LOGIC;
		PBI_IRQ_N : IN STD_LOGIC := '1';

		-- SIO
		SIO_RXD : in std_logic;
		SIO_TXD : out std_logic;
		SIO_CLOCKIN : in std_logic :='1';
		SIO_CLOCKOUT : out std_logic;
		-- SIO_COMMAND_TX - see PIA PB2
		-- TODO CLOCK IN/CLOCK OUT (unused almost everywhere...)

		-- GTIA consol
		CONSOL_OPTION : IN STD_LOGIC;
		CONSOL_SELECT : IN STD_LOGIC;
		CONSOL_START : IN STD_LOGIC;
		GTIA_TRIG : IN STD_LOGIC_VECTOR(3 downto 0);

		-- ANTIC lightpen
		ANTIC_LIGHTPEN : IN std_logic;
		ANTIC_REFRESH : out STD_LOGIC -- 1 'original' cycle high when antic doing refresh cycle...
	);
END atari800xl;

ARCHITECTURE bdf_type OF atari800xl IS 

-- BUS
SIGNAL BUS_ADDR : STD_LOGIC_VECTOR(15 downto 0);
SIGNAL BUS_DATA : STD_LOGIC_VECTOR(7 downto 0);

signal IO_DO : std_logic_vector(7 downto 0);
signal PBI_DO : std_logic_vector(7 downto 0);
signal BASIC_DO : std_logic_vector(7 downto 0);
signal OS_DO : std_logic_vector(7 downto 0);
signal RAM_DO : std_logic_vector(7 downto 0);

-- ANTIC
SIGNAL	ANTIC_ADDR :  STD_LOGIC_VECTOR(15 DOWNTO 0);
SIGNAL	ANTIC_AN :  STD_LOGIC_VECTOR(2 DOWNTO 0);
SIGNAL	ANTIC_COLOUR_CLOCK_OUT :  STD_LOGIC;
SIGNAL	ANTIC_DO :  STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL	ANTIC_FETCH :  STD_LOGIC;
SIGNAL	ANTIC_HIGHRES_COLOUR_CLOCK_OUT :  STD_LOGIC;
SIGNAL	ANTIC_ORIGINAL_COLOUR_CLOCK_OUT :  STD_LOGIC;
SIGNAL	ANTIC_RDY :  STD_LOGIC;
SIGNAL	BREAK_PRESSED :  STD_LOGIC;
signal hcount_temp : std_logic_vector(7 downto 0);
signal vcount_temp : std_logic_vector(8 downto 0);
signal ANTIC_REFRESH_CYCLE : STD_LOGIC;

-- GTIA
SIGNAL	GTIA_SOUND :  STD_LOGIC;
SIGNAL	CONSOL_OUT :  STD_LOGIC_VECTOR(3 downto 0);
SIGNAL	CONSOL_IN :  STD_LOGIC_VECTOR(3 downto 0);
SIGNAL  GTIA_TRIG_MERGED : STD_LOGIC_VECTOR(3 downto 0);

SIGNAL	GTIA_DO :  STD_LOGIC_VECTOR(7 DOWNTO 0);

-- CPU
SIGNAL	CPU_6502_RESET :  STD_LOGIC;
SIGNAL	CPU_ADDR :  STD_LOGIC_VECTOR(15 DOWNTO 0);
SIGNAL	CPU_DO :  STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL	CPU_FETCH :  STD_LOGIC;
SIGNAL	IRQ_n :  STD_LOGIC;
SIGNAL	NMI_n :  STD_LOGIC;
SIGNAL	R_W_N :  STD_LOGIC;

-- POKEY
SIGNAL	POKEY_IRQ :  STD_LOGIC;

SIGNAL	POKEY_DO :  STD_LOGIC_VECTOR(7 DOWNTO 0);
signal POKEY1_CHANNEL0 : std_logic_vector(3 downto 0);
signal POKEY1_CHANNEL1 : std_logic_vector(3 downto 0);
signal POKEY1_CHANNEL2 : std_logic_vector(3 downto 0);
signal POKEY1_CHANNEL3 : std_logic_vector(3 downto 0);

-- PIA
SIGNAL	PIA_DO :  STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL	PIA_IRQA :  STD_LOGIC;
SIGNAL	PIA_IRQB :  STD_LOGIC;
SIGNAL PORTB_OUT_INT : STD_LOGIC_VECTOR(7 downto 0);
SIGNAL PORTB_OPTIONS : STD_LOGIC_VECTOR(7 downto 0);

-- cart
signal cart_trig3_out: std_logic;

-- timing
signal shift_cpu_run_next : std_logic_vector(31 downto 0);
signal shift_cpu_run_reg : std_logic_vector(31 downto 0);
signal run_system : std_logic;
signal run_cpu : std_logic;

-- mmu
signal io_select : std_logic_vector(7 downto 0);
signal CS_GTIA : std_logic;
signal CS_D1 : std_logic;
signal CS_POKEY : std_logic;
signal CS_PIA : std_logic;
signal CS_ANTIC : std_logic;
signal CS_D5 : std_logic;
signal CS_D6 : std_logic;
signal CS_D7 : std_logic;

signal ANTIC_WRITE_ENABLE : std_logic;
signal POKEY_WRITE_ENABLE : std_logic;
signal PIA_WRITE_ENABLE   : std_logic;
signal PIA_READ_ENABLE    : std_logic;
signal GTIA_WRITE_ENABLE  : std_logic;
signal RAM_WRITE_ENABLE  : std_logic;


signal CS_BASIC : std_logic;
signal CS_IO : std_logic;
signal CS_OS : std_logic;
signal CAS_INHIBIT : std_logic;
signal REF_N : std_logic;

signal PAL : std_logic;

BEGIN 

PAL <= '1';

CPU_6502_RESET <= NOT(RESET_N); 
cpu6502 : entity work.cpu
PORT MAP(CLK => CLK,
		 RESET => CPU_6502_RESET,
		 ENABLE => RESET_N,
		 IRQ_n => IRQ_n,
		 NMI_n => NMI_n,
		 MEMORY_READY => '1',
		 THROTTLE => run_cpu,
		 RDY => ANTIC_RDY,
		 DI => BUS_DATA(7 DOWNTO 0),
		 R_W_n => R_W_N,
		 CPU_FETCH => CPU_FETCH,
		 A => CPU_ADDR,
		 DO => CPU_DO);

antic1 : entity work.antic
GENERIC MAP(cycle_length => 32)
PORT MAP(CLK => CLK,
		 WR_EN => ANTIC_WRITE_ENABLE,
		 RESET_N => RESET_N,
		 MEMORY_READY_ANTIC => RUN_CPU,
		 MEMORY_READY_CPU => RUN_CPU,
		 ANTIC_ENABLE_179 => RUN_CPU,
		 PAL => PAL,
		 lightpen => ANTIC_LIGHTPEN,
		 ADDR => BUS_ADDR(3 DOWNTO 0),
		 CPU_DATA_IN => BUS_DATA(7 DOWNTO 0),
		 MEMORY_DATA_IN => BUS_DATA(7 DOWNTO 0),
		 NMI_N_OUT => NMI_n,
		 ANTIC_READY => ANTIC_RDY,
		 COLOUR_CLOCK_ORIGINAL_OUT => ANTIC_ORIGINAL_COLOUR_CLOCK_OUT,
		 COLOUR_CLOCK_OUT => ANTIC_COLOUR_CLOCK_OUT,
		 HIGHRES_COLOUR_CLOCK_OUT => ANTIC_HIGHRES_COLOUR_CLOCK_OUT,
		 dma_fetch_out => ANTIC_FETCH,
		 hcount_out => hcount_temp,
		 vcount_out => vcount_temp,
		 refresh_out => ANTIC_REFRESH_CYCLE,
		 AN => ANTIC_AN,
		 DATA_OUT => ANTIC_DO,
		 dma_address_out => ANTIC_ADDR);

pokey_mixer_both : entity work.pokey_mixer_mux
PORT MAP(CLK => CLK,
		 GTIA_SOUND => GTIA_SOUND,
		 SIO_AUDIO => SIO_AUDIO,
		 CHANNEL_L_0 => POKEY1_CHANNEL0,
		 CHANNEL_L_1 => POKEY1_CHANNEL1,
		 CHANNEL_L_2 => POKEY1_CHANNEL2,
		 CHANNEL_L_3 => POKEY1_CHANNEL3,
		 COVOX_CHANNEL_L_0 => (others=>'0'),
		 COVOX_CHANNEL_L_1 => (others=>'0'),
		 CHANNEL_R_0 => POKEY1_CHANNEL0,
		 CHANNEL_R_1 => POKEY1_CHANNEL1,
		 CHANNEL_R_2 => POKEY1_CHANNEL2,
		 CHANNEL_R_3 => POKEY1_CHANNEL3,
		 COVOX_CHANNEL_R_0 => (others=>'0'),
		 COVOX_CHANNEL_R_1 => (others=>'0'),
		 VOLUME_OUT_L => AUDIO_L,
		 VOLUME_OUT_R => AUDIO_R);
		 
pia1 : entity work.pia
PORT MAP(CLK => CLK,
		 EN => PIA_READ_ENABLE,
		 WR_EN => PIA_WRITE_ENABLE,
		 RESET_N => RESET_N,
		 CA1 => CA1_IN,
		 CB1 => CB1_IN,
		 CA2_DIR_OUT => CA2_DIR_OUT,
		 CA2_IN => CA2_IN,
		 CA2_OUT => CA2_OUT,
		 CB2_DIR_OUT => CB2_DIR_OUT,
		 CB2_IN => CB2_IN,
		 CB2_OUT => CB2_OUT,
		 ADDR => BUS_ADDR(1 DOWNTO 0),
		 CPU_DATA_IN => BUS_DATA(7 DOWNTO 0),
		 IRQA_N => PIA_IRQA,
		 IRQB_N => PIA_IRQB,
		 DATA_OUT => PIA_DO,
		 PORTA_IN => PORTA_IN,
		 PORTA_DIR_OUT => PORTA_DIR_OUT,
		 PORTA_OUT => PORTA_OUT,
		 PORTB_IN => PORTB_IN,
		 PORTB_DIR_OUT => PORTB_DIR_OUT,
		 PORTB_OUT => PORTB_OUT_INT);

	PORTB_OPTIONS <= PORTB_OUT_INT;
	PORTB_OUT <= PORTB_OUT_INT;
	GTIA_TRIG_MERGED <= cart_trig3_out & GTIA_TRIG(2 downto 0); -- NOTE, inputs ignored, careful when adding 4 joystick support

pokey1 : entity work.pokey
PORT MAP(CLK => CLK,
		 ENABLE_179 => run_system,
		 WR_EN => POKEY_WRITE_ENABLE,
		 RESET_N => RESET_N,
		 SIO_IN1 => SIO_RXD,
		 SIO_IN2 => '1',
		 SIO_IN3 => '1',
		 SIO_CLOCKIN => SIO_CLOCKIN,
		 ADDR => BUS_ADDR(3 DOWNTO 0),
		 DATA_IN => BUS_DATA(7 DOWNTO 0),
		 keyboard_response => KEYBOARD_RESPONSE,
		 POT_IN => POT_IN,
		 IRQ_N_OUT => POKEY_IRQ,
		 SIO_OUT1 => SIO_TXD,
		 SIO_OUT2 => open,
		 SIO_OUT3 => open,
		 SIO_CLOCKOUT => SIO_CLOCKOUT,
		 POT_RESET => POT_RESET,
		 CHANNEL_0_OUT => POKEY1_CHANNEL0,
		 CHANNEL_1_OUT => POKEY1_CHANNEL1,
		 CHANNEL_2_OUT => POKEY1_CHANNEL2,
		 CHANNEL_3_OUT => POKEY1_CHANNEL3,
		 DATA_OUT => POKEY_DO,
		 keyboard_scan => KEYBOARD_SCAN);

CONSOL_IN <= '1'&CONSOL_OPTION&CONSOL_SELECT&CONSOL_START;
		 	 
gtia1 : entity work.gtia
PORT MAP(CLK => CLK,
		 WR_EN => GTIA_WRITE_ENABLE,
		 ANTIC_FETCH => ANTIC_FETCH, -- for first pmg fetch
		 CPU_ENABLE_ORIGINAL => run_system, -- for subsequent pmg fetches
		 RESET_N => RESET_N,
		 PAL => PAL,
		 COLOUR_CLOCK_ORIGINAL => ANTIC_ORIGINAL_COLOUR_CLOCK_OUT,
		 COLOUR_CLOCK => ANTIC_COLOUR_CLOCK_OUT,
		 COLOUR_CLOCK_HIGHRES => ANTIC_HIGHRES_COLOUR_CLOCK_OUT,
		 CONSOL_OUT => CONSOL_OUT,
		 CONSOL_IN => CONSOL_IN,
		 TRIG => GTIA_TRIG_MERGED,
		 ADDR => BUS_ADDR(4 DOWNTO 0),
		 AN => ANTIC_AN,
		 CPU_DATA_IN => BUS_DATA(7 DOWNTO 0),
		 MEMORY_DATA_IN => BUS_DATA(7 DOWNTO 0),
		 VSYNC => VIDEO_VS,
		 HSYNC => VIDEO_HS,
		 CSYNC => VIDEO_CS,
		 BLANK => VIDEO_BLANK,
		 BURST => VIDEO_BURST,
		 START_OF_FIELD => VIDEO_START_OF_FIELD,
		 ODD_LINE => VIDEO_ODD_LINE,
		 COLOUR_out => COLOUR,
		 DATA_OUT => GTIA_DO);

GTIA_SOUND <= CONSOL_OUT(3);

irq_glue1 : entity work.irq_glue
PORT MAP(pokey_irq => POKEY_IRQ,
		 pia_irqa => PIA_IRQA,
		 pia_irqb => PIA_IRQB,
		 pbi_irq => PBI_IRQ_N,
		 combined_irq => IRQ_n);

process(ANTIC_FETCH, ANTIC_ADDR, CPU_ADDR)
begin
	BUS_ADDR <= CPU_ADDR;
	if (ANTIC_FETCH = '1') then
		BUS_ADDR <= ANTIC_ADDR;
	end if;
end process;

PBI_REF_N_OUT <= not(ANTIC_REFRESH_CYCLE);
REF_N <= PBI_REF_N_IN and not(ANTIC_REFRESH_CYCLE);
PBI_CAS_INHIBIT <= CAS_INHIBIT;


-- TODO
-- implement in timing_6502, along with driving bus every cycle (for snoopers)
--PBI_CAS : out STD_LOGIC; -- high with RAS, low (unless extsel/inhibited) depends on read write. phi2 low-> cas low (read)=300-370, write=425-?
--PBI_RAS : out STD_LOGIC; -- high slightly after PHI2 high, low slight before phi low. phi2 low -> raw low 210-305

mmu1: entity work.mmu
PORT MAP
(
	ADDR => BUS_ADDR(15 downto 11),
	REF_N => REF_N,
	RD4 => CART_RD4,
	RD5 => CART_RD5,
	MPD_N => PBI_MPD_N,
	REN => PORTB_OUT_INT(0), 
	BE_N => PORTB_OUT_INT(1),
	MAP_N => PORTB_OUT_INT(7),
	S4_N => CART_S4_N,
	S5_N => CART_S5_N,
	BASIC => CS_BASIC,
	IO => CS_IO,
	OS => CS_OS,
	CI => CAS_INHIBIT --Disable RAM
);

--74ls138
decode_addr1 : entity work.complete_address_decoder
	generic map(width=>3)
	port map (addr_in=>BUS_ADDR(10 downto 8), addr_decoded=>io_select);

CS_GTIA <= CS_IO and io_select(0);
CS_D1 <= CS_IO and io_select(1);    -- PBI regs
CS_POKEY <= CS_IO and io_select(2);
CS_PIA <= CS_IO and io_select(3);
CS_ANTIC <= CS_IO and io_select(4); -- Antic decodes bus itself
CS_D5 <= CS_IO and io_select(5);    -- CART CTRL
CS_D6 <= CS_IO and io_select(6);    -- PBI RAM?
CS_D7 <= CS_IO and io_select(7);    -- PBI RAM?

ANTIC_WRITE_ENABLE <= CS_ANTIC AND NOT(R_W_N) and run_cpu;
POKEY_WRITE_ENABLE <= CS_POKEY AND NOT(R_W_N) and run_cpu;
PIA_WRITE_ENABLE   <= CS_PIA AND NOT(R_W_N) and run_cpu;
PIA_READ_ENABLE    <= CS_PIA AND R_W_N and run_system;
GTIA_WRITE_ENABLE  <= CS_GTIA AND NOT(R_W_N) and run_cpu;

RAM_WRITE_ENABLE  <= NOT(R_W_N) and NOT(CAS_INHIBIT) and run_cpu;

process(BUS_ADDR, GTIA_DO, POKEY_DO, PIA_DO, ANTIC_DO, PBI_DO)
begin
	case (BUS_ADDR(10 downto 8)) is
	when "000" =>
		IO_DO <= GTIA_DO;
	when "010" =>
		IO_DO <= POKEY_DO;
	when "011" =>
		IO_DO <= PIA_DO;
	when "100" =>
		IO_DO <= ANTIC_DO;
	when others =>
		IO_DO <= PBI_DO; -- D1,D5,D6,D7
	end case;
	
end process;

-- CAS_INHIBIT -> RAM disabled. e.g. IO, ROM etc.
-- So PBI can reply if its IO and there is no chip selected - D1,D6,D7
process(R_W_N, CS_BASIC, CS_IO, CS_OS, CAS_INHIBIT, PBI_EXTSEL_N, IO_DO, RAM_DO, OS_DO, BASIC_DO, PBI_DO, CPU_DO)
  variable casesig : std_logic_vector(5 downto 0);
begin
	BUS_DATA <= (others=>'1');
	casesig :=  R_W_N&CS_BASIC&CS_IO&CS_OS&CAS_INHIBIT&PBI_EXTSEL_N;
	case casesig is
		when 
			"000000"|"000001"|"000010"|"000011"|"000100"|"000101"|"000110"|"000111"|
			"001000"|"001001"|"001010"|"001011"|"001100"|"001101"|"001110"|"001111"|
			"010000"|"010001"|"010010"|"010011"|"010100"|"010101"|"010110"|"010111"|
			"011000"|"011001"|"011010"|"011011"|"011100"|"011101"|"011110"|"011111"
			=>
			BUS_DATA <= CPU_DO;
		when "110010"|"110011" =>
			BUS_DATA <= BASIC_DO;
		when "101010"|"101011" =>
			BUS_DATA <= IO_DO;
		when "100110"|"100111" =>
			BUS_DATA <= OS_DO;
		when "100010"|"100011" =>
			BUS_DATA <= PBI_DO; -- i.e. CAS inhibited, nothing selected (e.g. REF_N is low)
		when "100001" =>
			BUS_DATA <= RAM_DO; -- i.e. RAM access, no EXTSEL
		when "100000" =>
			BUS_DATA <= PBI_DO; -- i.e. RAM access, but EXTSEL asserted
		when others =>
			BUS_DATA <= (others=>'1');
	end case;
end process;

-- 00000000001111111111122222222233
-- 01234567890123456789012345678901
-- 00000000000000000000000000000001 run antic and CPU and kick off pbi/cart cycle
-- simple shift reg will do it
process(clk, reset_n)
begin
	if (reset_n='0') then
		shift_cpu_run_reg     <= "00000000000000000000000000000001";
	elsif (clk'event and clk='1') then
		shift_cpu_run_reg     <= shift_cpu_run_next;
	end if;
end process;
shift_cpu_run_next <= shift_cpu_run_reg(30 downto 0)&shift_cpu_run_reg(31);
run_system <= shift_cpu_run_reg(31);
run_cpu <= run_system and not(ANTIC_FETCH or ANTIC_REFRESH_CYCLE);

-- Internal rom/ram
internalromram1 : entity work.internalromram_simple
	PORT MAP (
 		clock   => CLK,
		reset_n => RESET_N,

		ROM_ADDR => "000000"&BUS_ADDR,
		ROM_REQUEST_COMPLETE => open,
		ROM_REQUEST => '1',
		BASIC_DATA => BASIC_DO,
		OS_DATA => OS_DO,
		
		RAM_ADDR => "000"&BUS_ADDR,
		RAM_WR_ENABLE => RAM_WRITE_ENABLE, 
		RAM_DATA_IN => BUS_DATA(7 downto 0),
		RAM_REQUEST_COMPLETE => open,
		RAM_REQUEST => '1',
		RAM_DATA => RAM_DO(7 downto 0)
	);

END bdf_type;
