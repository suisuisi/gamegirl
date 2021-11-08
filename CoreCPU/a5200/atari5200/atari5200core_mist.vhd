--------------------------------------------------------------------------- -- (c) 2013 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

LIBRARY work;

ENTITY atari5200core_mist IS 
	GENERIC
	(
		CSYNC : IN integer := 0
	);
	PORT
	(
		CLOCK_27 :  IN  STD_LOGIC_VECTOR(1 downto 0);

		VGA_VS :  OUT  STD_LOGIC;
		VGA_HS :  OUT  STD_LOGIC;
		VGA_B :  OUT  STD_LOGIC_VECTOR(5 DOWNTO 0);
		VGA_G :  OUT  STD_LOGIC_VECTOR(5 DOWNTO 0);
		VGA_R :  OUT  STD_LOGIC_VECTOR(5 DOWNTO 0);
		
		AUDIO_L : OUT std_logic;
		AUDIO_R : OUT std_logic;

		SDRAM_BA :  OUT  STD_LOGIC_VECTOR(1 downto 0);
		SDRAM_nCS :  OUT  STD_LOGIC;
		SDRAM_nRAS :  OUT  STD_LOGIC;
		SDRAM_nCAS :  OUT  STD_LOGIC;
		SDRAM_nWE :  OUT  STD_LOGIC;
		SDRAM_DQMH :  OUT  STD_LOGIC;
		SDRAM_DQML :  OUT  STD_LOGIC;
		SDRAM_CLK :  OUT  STD_LOGIC;
		SDRAM_CKE :  OUT  STD_LOGIC;
		SDRAM_A :  OUT  STD_LOGIC_VECTOR(12 DOWNTO 0);
		SDRAM_DQ :  INOUT  STD_LOGIC_VECTOR(15 DOWNTO 0);

		LED : OUT std_logic;
		
		UART_TX :  OUT  STD_LOGIC;
		UART_RX :  IN  STD_LOGIC;
		
		SPI_DO :  INOUT  STD_LOGIC;
		SPI_DI :  IN  STD_LOGIC;
		SPI_SCK :  IN  STD_LOGIC;
		SPI_SS2 :  IN  STD_LOGIC;		
		SPI_SS3 :  IN  STD_LOGIC;		
		SPI_SS4 :  IN  STD_LOGIC;
		CONF_DATA0 :  IN  STD_LOGIC -- AKA SPI_SS5
	);
END atari5200core_mist;

ARCHITECTURE vhdl OF atari5200core_mist IS 

component hq_dac
port (
  reset :in std_logic;
  clk :in std_logic;
  clk_ena : in std_logic;
  pcm_in : in std_logic_vector(19 downto 0);
  dac_out : out std_logic
);
end component;

COMPONENT rgb2ypbpr
PORT (
        red     :        IN std_logic_vector(5 DOWNTO 0);
        green   :        IN std_logic_vector(5 DOWNTO 0);
        blue    :        IN std_logic_vector(5 DOWNTO 0);
        y       :        OUT std_logic_vector(5 DOWNTO 0);
        pb      :        OUT std_logic_vector(5 DOWNTO 0);
        pr      :        OUT std_logic_vector(5 DOWNTO 0)
        );
END COMPONENT;

component osd
generic ( OSD_COLOR : integer := 1 );  -- blue
port (
        clk_sys     : in std_logic;
        R_in        : in std_logic_vector(5 downto 0);
        G_in        : in std_logic_vector(5 downto 0);
        B_in        : in std_logic_vector(5 downto 0);
        HSync       : in std_logic;
        VSync       : in std_logic;

        R_out       : out std_logic_vector(5 downto 0);
        G_out       : out std_logic_vector(5 downto 0);
        B_out       : out std_logic_vector(5 downto 0);

        SPI_SCK     : in std_logic;
        SPI_SS3     : in std_logic;
        SPI_DI      : in std_logic
);
end component osd;

component user_io
    generic (
        STRLEN : integer := 0;
        PS2DIV : integer := 1500 );
    port (
        clk_sys : in std_logic;
        clk_sd  : in std_logic;
        SPI_CLK, SPI_SS_IO, SPI_MOSI :in std_logic;
        SPI_MISO : out std_logic;
        conf_str : in std_logic_vector(8*STRLEN-1 downto 0);
        joystick_0 : out std_logic_vector(31 downto 0);
        joystick_1 : out std_logic_vector(31 downto 0);
        joystick_analog_0 : out std_logic_vector(15 downto 0);
        joystick_analog_1 : out std_logic_vector(15 downto 0);
        status: out std_logic_vector(31 downto 0);
        switches : out std_logic_vector(1 downto 0);
        buttons : out std_logic_vector(1 downto 0);
        scandoubler_disable: out std_logic;
        ypbpr: out std_logic;
        ps2_kbd_clk : out std_logic;
        ps2_kbd_data : out std_logic;
        ps2_mouse_clk : out std_logic;
        ps2_mouse_data : out std_logic;
        serial_data : in std_logic_vector(7 downto 0);
        serial_strobe : in std_logic
      );
end component user_io;

component data_io
    port (
        clk_sys : in std_logic;

        SPI_SCK : in std_logic;
        SPI_SS2 : in std_logic;
        SPI_DI  : in std_logic;

        ioctl_wait     : in std_logic;
        ioctl_download : out std_logic;
        ioctl_index    : out std_logic_vector(7 downto 0);
        ioctl_wr       : out std_logic;
        ioctl_addr     : out std_logic_vector(24 downto 0);
        ioctl_dout     : out std_logic_vector(15 downto 0)
      );
end component data_io;

signal AUDIO_L_PCM : std_logic_vector(15 downto 0);
signal AUDIO_R_PCM : std_logic_vector(15 downto 0);

signal VGA_VS_RAW : std_logic;
signal VGA_HS_RAW : std_logic;
signal VGA_CS_RAW : std_logic;

signal RESET_n : std_logic;
signal PLL_LOCKED : std_logic;
signal CLK : std_logic;
signal CLK_SDRAM : std_logic;

SIGNAL PS2_CLK : std_logic;
SIGNAL PS2_DAT : std_logic;
SIGNAL FKEYS : std_logic_vector(11 downto 0);

signal capslock_pressed : std_logic;
signal capsheld_next : std_logic;
signal capsheld_reg : std_logic;
  
signal spi_miso_io : std_logic;

signal mist_buttons : std_logic_vector(1 downto 0);
signal mist_switches : std_logic_vector(1 downto 0);
signal mist_status : std_logic_vector(31 downto 0);
signal mist_JOY1X : std_logic_vector(7 downto 0);
signal mist_JOY1Y : std_logic_vector(7 downto 0);
signal mist_JOY2X : std_logic_vector(7 downto 0);
signal mist_JOY2Y : std_logic_vector(7 downto 0);

signal JOY1 :  STD_LOGIC_VECTOR(31 DOWNTO 0);
signal JOY2 :  STD_LOGIC_VECTOR(31 DOWNTO 0);
signal JOY1X : std_logic_vector(7 downto 0);
signal JOY1Y : std_logic_vector(7 downto 0);
signal JOY2X : std_logic_vector(7 downto 0);
signal JOY2Y : std_logic_vector(7 downto 0);
signal JOY1_n :  STD_LOGIC_VECTOR(4 DOWNTO 0);
signal JOY2_n :  STD_LOGIC_VECTOR(4 DOWNTO 0);
signal joy_still : std_logic;
signal FIRE2: std_logic_vector(3 downto 0);

SIGNAL KEYBOARD_RESPONSE :  STD_LOGIC_VECTOR(1 DOWNTO 0);
SIGNAL KEYBOARD_SCAN :  STD_LOGIC_VECTOR(5 DOWNTO 0);
signal controller_select : std_logic_vector(1 downto 0);

SIGNAL PAL : std_logic;
SIGNAL COMPOSITE_ON_HSYNC : std_logic;
SIGNAL VGA : std_logic;

signal SDRAM_REQUEST : std_logic;
signal SDRAM_REQUEST_COMPLETE : std_logic;
signal SDRAM_READ_ENABLE :  STD_LOGIC;
signal SDRAM_WRITE_ENABLE : std_logic;
signal SDRAM_ADDR_OUT : STD_LOGIC_VECTOR(22 DOWNTO 0);
signal SDRAM_ADDR_IN : STD_LOGIC_VECTOR(22 DOWNTO 0);
signal SDRAM_DO : STD_LOGIC_VECTOR(31 DOWNTO 0);
signal SDRAM_DI : STD_LOGIC_VECTOR(31 DOWNTO 0);
signal SDRAM_WIDTH_8bit_ACCESS : std_logic;
signal SDRAM_WIDTH_16bit_ACCESS : std_logic;
signal SDRAM_WIDTH_32bit_ACCESS : std_logic;

signal SDRAM_REFRESH : std_logic;
signal SDRAM_RESET_N : std_logic;

-- dma/virtual drive
signal DMA_ADDR_FETCH : std_logic_vector(23 downto 0);
signal DMA_WRITE_DATA : std_logic_vector(31 downto 0);
signal DMA_FETCH : std_logic;
signal DMA_32BIT_WRITE_ENABLE : std_logic;
signal DMA_16BIT_WRITE_ENABLE : std_logic;
signal DMA_8BIT_WRITE_ENABLE : std_logic;
signal DMA_READ_ENABLE : std_logic;
signal DMA_MEMORY_READY : std_logic;

signal pause_btnD  : std_logic;
signal pause_state : std_logic;
signal reset_atari : std_logic;
signal pause_atari : std_logic;
SIGNAL speed_6502 : std_logic_vector(5 downto 0);

-- data io
type ioctl_t is (
    IOCTL_IDLE,
    IOCTL_WRITE,
    IOCTL_ACK);
signal ioctl_state     : ioctl_t;
signal ioctl_download  : std_logic;
signal ioctl_download_D: std_logic;
signal ioctl_index     : std_logic_vector(7 downto 0);
signal ioctl_wr        : std_logic;
signal ioctl_addr      : std_logic_vector(24 downto 0);
signal ioctl_dout      : std_logic_vector(15 downto 0);
signal reset_load      : std_logic;

type cart_t is (
    CART_32k,
    CART_16k_1,
    CART_16k_2,
    CART_8k,
    CART_4k);
signal cart_type : cart_t;

-- ps2
signal PS2_KEYS : STD_LOGIC_VECTOR(511 downto 0);
signal PS2_KEYS_NEXT : STD_LOGIC_VECTOR(511 downto 0);

-- scandoubler
signal half_scandouble_enable_reg : std_logic;
signal half_scandouble_enable_next : std_logic;
signal scanlines_reg : std_logic;
signal VIDEO_B : std_logic_vector(7 downto 0);
signal scandoubler_disable : std_logic;
signal ypbpr : std_logic;

signal sd_hs        : std_logic;
signal sd_vs        : std_logic;
signal osd_red_i    : std_logic_vector(5 downto 0);
signal osd_green_i  : std_logic_vector(5 downto 0);
signal osd_blue_i   : std_logic_vector(5 downto 0);
signal osd_vs_i     : std_logic;
signal osd_hs_i     : std_logic;
signal osd_red_o    : std_logic_vector(5 downto 0);
signal osd_green_o  : std_logic_vector(5 downto 0);
signal osd_blue_o   : std_logic_vector(5 downto 0);
signal vga_y_o      : std_logic_vector(5 downto 0);
signal vga_pb_o     : std_logic_vector(5 downto 0);
signal vga_pr_o     : std_logic_vector(5 downto 0);

constant CONF_STR : string :=
    "A5200;A52BIN;"&
    "O3,16k Cart,1 Chip,2 Chips;"&
    "O2,Joystick swap,Off,On;"&
    "O46,CPU Speed,1x,2x,4x,8x,16x;"&
    "O1,Scanlines,Off,On;"&
    "T0,Reset;";

-- convert string to std_logic_vector to be given to user_io
   function to_slv(s: string) return std_logic_vector is
        constant ss: string(1 to s'length) := s;
        variable rval: std_logic_vector(1 to 8 * s'length);
        variable p: integer;
        variable c: integer;
    begin
        for i in ss'range loop
            p := 8 * i;
            c := character'pos(ss(i));
            rval(p - 7 to p) := std_logic_vector(to_unsigned(c,8));
        end loop;
        return rval;
    end function;

    CONSTANT V01 : std_logic_vector(0 TO 1):="01";

BEGIN

pal <= '1';
vga <= not scandoubler_disable;

-- mist spi io
spi_do <= spi_miso_io when CONF_DATA0 ='0' else 'Z';

mist_user_io : user_io
    generic map (STRLEN => CONF_STR'length)
    PORT map(
        clk_sys => CLK,
        clk_sd  => CLK,
        SPI_CLK => SPI_SCK,
        SPI_SS_IO => CONF_DATA0,
        SPI_MISO => SPI_miso_io,
        SPI_MOSI => SPI_DI,
        conf_str => to_slv(CONF_STR),
        JOYSTICK_0 => joy1,
        JOYSTICK_1 => joy2,
        JOYSTICK_ANALOG_0(15 downto 8) => mist_joy1x,
        JOYSTICK_ANALOG_0(7 downto 0) => mist_joy1y,
        JOYSTICK_ANALOG_1(15 downto 8) => mist_joy2x,
        JOYSTICK_ANALOG_1(7 downto 0) => mist_joy2y,
        BUTTONS => mist_buttons,
        SWITCHES => mist_switches,
        STATUS => mist_status,
		scandoubler_disable => scandoubler_disable,
        ypbpr => ypbpr,

        PS2_KBD_CLK => ps2_clk,
        PS2_KBD_DATA => ps2_dat,

        SERIAL_DATA => (others=>'0'),
        SERIAL_STROBE => '0'
    );

joy1_n <= not(joy1(4 downto 0)) when mist_status(2) = '0' else not(joy2(4 downto 0));
joy2_n <= not(joy2(4 downto 0)) when mist_status(2) = '0' else not(joy1(4 downto 0));
joy1x <= mist_joy1x when mist_status(2) = '0' else mist_joy2x;
joy1y <= mist_joy1y when mist_status(2) = '0' else mist_joy2y;
joy2x <= mist_joy2x when mist_status(2) = '0' else mist_joy1x;
joy2y <= mist_joy2y when mist_status(2) = '0' else mist_joy1y;

FIRE2 <= "00" & joy2(5)&joy1(5) when mist_status(2) = '0' else "00"&joy1(5)&joy2(5);

-- PS2 to pokey
keyboard_map1 : entity work.ps2_to_atari5200
	PORT MAP
	( 
		CLK => clk,
		RESET_N => reset_n,
		PS2_CLK => ps2_clk,
		PS2_DAT => ps2_dat,

		FIRE2 => FIRE2,
		CONTROLLER_SELECT => CONTROLLER_SELECT, -- selected stick keyboard/shift button
		
		KEYBOARD_SCAN => KEYBOARD_SCAN,
		KEYBOARD_RESPONSE => KEYBOARD_RESPONSE,

		FKEYS => FKEYS,

		PS2_KEYS => PS2_KEYS,
		PS2_KEYS_NEXT_OUT => PS2_KEYS_NEXT
	);
-- stick 0: consol(1 downto 0)="00"

joy_still <= joy1_n(3) and joy1_n(2) and joy1_n(1) and joy1_n(0); -- TODO, need something better here I think! e.g. keypad? 5200 not centreing

dac_left : hq_dac
port map
(
    reset => not(reset_n),
    clk => clk,
    clk_ena => '1',
    pcm_in => AUDIO_L_PCM&"0000",
    dac_out => audio_l
);

dac_right : hq_dac
port map
(
    reset => not(reset_n),
    clk => clk,
    clk_ena => '1',
    pcm_in => AUDIO_R_PCM&"0000",
    dac_out => audio_r
);

mist_pll : entity work.pll_ntsc
PORT MAP(inclk0 => CLOCK_27(0),
    c0 => CLK_SDRAM,
    c1 => CLK,
    c2 => SDRAM_CLK,
    locked => PLL_LOCKED);

reset_n <= PLL_LOCKED;

atari5200 : entity work.atari5200core_simplesdram
    GENERIC MAP
    (
        cycle_length => 32,
--      internal_rom => 4, --5200 rom...
--      internal_rom => 0, --5200 rom...
--      internal_ram => 16384 -- only 1 option for 5200...
        video_bits => 8,
        palette => 0
    )
    PORT MAP
	(
        CLK => CLK,
        RESET_N => RESET_N and SDRAM_RESET_N and not(reset_atari),

        VIDEO_VS => VGA_VS_RAW,
        VIDEO_HS => VGA_HS_RAW,
        VIDEO_CS => VGA_CS_RAW,
        VIDEO_B => VIDEO_B,
        VIDEO_G => open,
        VIDEO_R => open,

        AUDIO_L => AUDIO_L_PCM,
        AUDIO_R => AUDIO_R_PCM,

		-- JOYSTICK
        JOY1_X => signed(joy1x),
        JOY1_Y => signed(joy1y),
        JOY2_X => signed(joy2x),
        JOY2_Y => signed(joy2y),

        JOY1_n => JOY1_n(4)&JOY1_n(0)&JOY1_n(1)&JOY1_n(2)&JOY1_n(3),
        JOY2_n => JOY2_n(4)&JOY2_n(0)&JOY2_n(1)&JOY2_n(2)&JOY2_n(3),

        KEYBOARD_RESPONSE => KEYBOARD_RESPONSE,
        KEYBOARD_SCAN => KEYBOARD_SCAN,

        SDRAM_REQUEST => SDRAM_REQUEST,
        SDRAM_REQUEST_COMPLETE => SDRAM_REQUEST_COMPLETE,
        SDRAM_READ_ENABLE => SDRAM_READ_ENABLE,
        SDRAM_WRITE_ENABLE => SDRAM_WRITE_ENABLE,
        SDRAM_ADDR => SDRAM_ADDR_OUT,
        SDRAM_DO => SDRAM_DO,
        SDRAM_DI => SDRAM_DI,
        SDRAM_32BIT_WRITE_ENABLE => SDRAM_WIDTH_32bit_ACCESS,
        SDRAM_16BIT_WRITE_ENABLE => SDRAM_WIDTH_16bit_ACCESS,
        SDRAM_8BIT_WRITE_ENABLE => SDRAM_WIDTH_8bit_ACCESS,
        SDRAM_REFRESH => SDRAM_REFRESH,

        DMA_FETCH => dma_fetch, -- in
        DMA_READ_ENABLE => dma_read_enable, -- in
        DMA_32BIT_WRITE_ENABLE => dma_32bit_write_enable, -- in
        DMA_16BIT_WRITE_ENABLE => dma_16bit_write_enable, -- in
        DMA_8BIT_WRITE_ENABLE => dma_8bit_write_enable, -- in
        DMA_ADDR => dma_addr_fetch, -- in
        DMA_WRITE_DATA => dma_write_data,	-- in
        MEMORY_READY_DMA => dma_memory_ready,	-- out
        DMA_MEMORY_DATA => open, -- out

        --PAL => PAL,
        HALT => pause_atari,
        THROTTLE_COUNT_6502 => speed_6502,
        --emulated_cartridge_select => emulated_cartridge_select,
        --freezer_enable => freezer_enable,
        --freezer_activate => freezer_activate,

        CONTROLLER_SELECT => CONTROLLER_SELECT
	);
sdram_adaptor : entity work.sdram_statemachine
GENERIC MAP(ADDRESS_WIDTH => 22,
        AP_BIT => 10,
        COLUMN_WIDTH => 8,
        ROW_WIDTH => 12
)
PORT MAP(CLK_SYSTEM => CLK,
        CLK_SDRAM => CLK_SDRAM,
        RESET_N =>  RESET_N,
        READ_EN => SDRAM_READ_ENABLE,
        WRITE_EN => SDRAM_WRITE_ENABLE,
        REQUEST => SDRAM_REQUEST,
        BYTE_ACCESS => SDRAM_WIDTH_8BIT_ACCESS,
        WORD_ACCESS => SDRAM_WIDTH_16BIT_ACCESS,
        LONGWORD_ACCESS => SDRAM_WIDTH_32BIT_ACCESS,
        REFRESH => SDRAM_REFRESH,
        ADDRESS_IN => SDRAM_ADDR_IN,
        DATA_IN => SDRAM_DI,
        SDRAM_DQ => SDRAM_DQ,
        COMPLETE => SDRAM_REQUEST_COMPLETE,
        SDRAM_BA0 => SDRAM_BA(0),
        SDRAM_BA1 => SDRAM_BA(1),
        SDRAM_CKE => SDRAM_CKE,
        SDRAM_CS_N => SDRAM_nCS,
        SDRAM_RAS_N => SDRAM_nRAS,
        SDRAM_CAS_N => SDRAM_nCAS,
        SDRAM_WE_N => SDRAM_nWE,
        SDRAM_ldqm => SDRAM_DQML,
        SDRAM_udqm => SDRAM_DQMH,
        DATA_OUT => SDRAM_DO,
        SDRAM_ADDR => SDRAM_A(11 downto 0),
        reset_client_n => SDRAM_RESET_N
);

SDRAM_A(12) <= '0';

LED <= not ioctl_download;

process(clk,RESET_N,SDRAM_RESET_N,reset_atari)
begin
	if ((RESET_N and SDRAM_RESET_N and not(reset_atari))='0') then
		half_scandouble_enable_reg <= '0';
		scanlines_reg <= '0';
	elsif (clk'event and clk='1') then
		half_scandouble_enable_reg <= half_scandouble_enable_next;
		scanlines_reg <= mist_status(1);
	end if;
end process;

half_scandouble_enable_next <= not(half_scandouble_enable_reg);

scandoubler1: entity work.scandoubler
GENERIC MAP
	(
		video_bits=>6
	)
PORT MAP
	( 
		CLK => CLK,
		RESET_N => RESET_N and SDRAM_RESET_N and not(reset_atari),

		VGA => vga,
		COMPOSITE_ON_HSYNC => V01(csync),
		colour_enable => half_scandouble_enable_reg,
		doubled_enable => '1',
		scanlines_on => scanlines_reg,

		-- GTIA interface
		pal => PAL,
		colour_in => VIDEO_B,
		vsync_in => VGA_VS_RAW,
		hsync_in => VGA_HS_RAW,
		csync_in => VGA_CS_RAW,

        -- TO OSD
        R => osd_red_i,
        G => osd_green_i,
        B => osd_blue_i,

        VSYNC => sd_vs,
        HSYNC => sd_hs
);

osd_inst: osd
port map (
        clk_sys     => CLK,
        SPI_SCK     => SPI_SCK,
        SPI_SS3     => SPI_SS3,
        SPI_DI      => SPI_DI,

        R_in        => osd_red_i,
        G_in        => osd_green_i,
        B_in        => osd_blue_i,
        HSync       => sd_hs,
        VSync       => sd_vs,

        R_out       => osd_red_o,
        G_out       => osd_green_o,
        B_out       => osd_blue_o
);

rgb2component: rgb2ypbpr
port map (
        red => osd_red_o,
        green => osd_green_o,
        blue => osd_blue_o,
        y => vga_y_o,
        pb => vga_pb_o,
        pr => vga_pr_o
);

 -- If 15kHz Video - composite sync to VGA_HS and VGA_VS high for MiST RGB cable
VGA_HS <= not (sd_hs xor sd_vs) when scandoubler_disable='1' or ypbpr='1' else sd_hs;
VGA_VS <= '1' when scandoubler_disable='1' or ypbpr='1' else sd_vs;
VGA_R <= vga_pr_o when ypbpr='1' else osd_red_o;
VGA_G <= vga_y_o  when ypbpr='1' else osd_green_o;
VGA_B <= vga_pb_o when ypbpr='1' else osd_blue_o;

pause_atari <= ioctl_download or pause_state;
process (CLK, RESET_N) begin
    if RESET_N = '0' then
        pause_state <= '0';
    elsif rising_edge(CLK) then
        pause_btnD <= joy1(6) or joy2(6);
        if (joy1(6) or joy2(6)) = '1' and pause_btnD = '0' then
            pause_state <= not pause_state;
        end if;
    end if;
end process;

reset_atari <= mist_status(0) or mist_buttons(1) or reset_load;
speed_6502 <= "000001" when mist_status(6 downto 4) = "000" else
              "000010" when mist_status(6 downto 4) = "001" else
              "000100" when mist_status(6 downto 4) = "010" else
              "001000" when mist_status(6 downto 4) = "011" else
              "010000";

dma_read_enable <= '0'; -- in
dma_32bit_write_enable <= '0'; -- in
dma_8bit_write_enable <= '0'; -- in

mist_data_io: data_io
    port map (
        clk_sys => CLK,

        SPI_SCK => SPI_SCK,
        SPI_SS2 => SPI_SS2,
        SPI_DI  => SPI_DI,

        ioctl_wait     => '0',
        ioctl_download => ioctl_download,
        ioctl_index    => ioctl_index,
        ioctl_wr       => ioctl_wr,
        ioctl_addr     => ioctl_addr,
        ioctl_dout     => ioctl_dout
      );

process (CLK, RESET_N) begin
    if RESET_N = '0' then
        ioctl_state <= IOCTL_IDLE;
        reset_load <= '0';
    elsif rising_edge(CLK) then
        ioctl_download_D <= ioctl_download;
        case ioctl_state is
        when IOCTL_IDLE =>
            reset_load <= '0';
            dma_fetch <= '0';
            dma_16bit_write_enable <= '0';
            if ioctl_download_D = '0' and ioctl_download = '1' then
                cart_type <= CART_32k;
                ioctl_state <= IOCTL_WRITE;
            end if;
        when IOCTL_WRITE =>
            if ioctl_download = '0' then
                if ioctl_addr(15 downto 12) = x"5" then cart_type <= CART_4k;
                elsif ioctl_addr(15 downto 12) = x"6" then cart_type <= CART_8k;
                elsif ioctl_addr(15 downto 12) = x"8" then
                    if mist_status(3) = '0' then cart_type <= CART_16k_1; else cart_type <= CART_16k_2; end if;
                end if;
                ioctl_state <= IOCTL_IDLE;
                reset_load <= '1';
            elsif ioctl_wr = '1' then
                dma_fetch <= '1';
                dma_16bit_write_enable <= '1';
                dma_write_data <= ioctl_dout & ioctl_dout;
                dma_addr_fetch <= ioctl_addr(23 downto 0);
                ioctl_state <= IOCTL_ACK;
            end if;
        when IOCTL_ACK =>
            if dma_memory_ready = '1' then
                dma_fetch <= '0';
                dma_16bit_write_enable <= '0';
                ioctl_state <= IOCTL_WRITE;
            end if;
        when others => null;
        end case;
    end if;
end process;

process (SDRAM_ADDR_OUT, cart_type) begin
    SDRAM_ADDR_IN <= SDRAM_ADDR_OUT;
    case cart_type is
    when CART_16k_1 =>
    -- one chip 16k
        case SDRAM_ADDR_OUT(15 downto 14) is
            when "10" => SDRAM_ADDR_IN(15 downto 14) <= "01";
            when others => null;
        end case;

    when CART_16k_2 =>
    -- two chip 16k
        case SDRAM_ADDR_OUT(15 downto 13) is
            when "011" => SDRAM_ADDR_IN(15 downto 13) <= "010";
            when "100" => SDRAM_ADDR_IN(15 downto 13) <= "011";
            when "101" => SDRAM_ADDR_IN(15 downto 13) <= "011";
        when others => null;
        end case;

    when CART_8k =>
    -- 8k
        SDRAM_ADDR_IN(15 downto 13) <= "010";

    when CART_4k =>
    -- 4k
        SDRAM_ADDR_IN(15 downto 12) <= "0100";
    
    when others => null;
    end case;

end process;

END vhdl;
