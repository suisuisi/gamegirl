--
-- MA2601.vhd
--
-- Atari VCS 2600 toplevel for the MiST board
-- https://github.com/wsoltys/tca2601
--
-- Copyright (c) 2014 W. Soltys <wsoltys@gmail.com>
--
-- This source file is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published
-- by the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This source file is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use work.mist.ALL;
-- -----------------------------------------------------------------------

entity MA2601 is
    port (
    
-- Clock
      CLOCK_27 : in std_logic_vector(1 downto 0);

-- SPI
      SPI_SCK : in std_logic;
      SPI_DI : in std_logic;
      SPI_DO : out std_logic;
      SPI_SS2 : in std_logic;
      SPI_SS3 : in std_logic;
      CONF_DATA0 : in std_logic;

-- LED
      LED : out std_logic;

-- Video
      VGA_R : out std_logic_vector(5 downto 0);
      VGA_G : out std_logic_vector(5 downto 0);
      VGA_B : out std_logic_vector(5 downto 0);
      VGA_HS : out std_logic;
      VGA_VS : out std_logic;

-- Audio
      AUDIO_L : out std_logic;
      AUDIO_R : out std_logic;

-- SDRAM
      SDRAM_nCS : out std_logic
    );
end entity;

-- -----------------------------------------------------------------------

architecture rtl of MA2601 is

-- System clocks
  signal vid_clk: std_logic := '0'; -- 28 MHz
  signal clk : std_logic; -- 3.5 MHz

-- A2601
  signal audio: std_logic := '0';
  signal O_VSYNC: std_logic := '0';
  signal O_HSYNC: std_logic := '0';
  signal O_VIDEO_R: std_logic_vector(5 downto 0) := (others => '0');
  signal O_VIDEO_G: std_logic_vector(5 downto 0) := (others => '0');
  signal O_VIDEO_B: std_logic_vector(5 downto 0) := (others => '0');
  signal res: std_logic := '0';
  signal p_l: std_logic := '0';
  signal p_r: std_logic := '0';
  signal p_a: std_logic := '0';
  signal p_b: std_logic := '0';
  signal p_u: std_logic := '0';
  signal p_d: std_logic := '0';
  signal p2_l: std_logic := '0';
  signal p2_r: std_logic := '0';
  signal p2_a: std_logic := '0';
  signal p2_b: std_logic := '0';
  signal p2_u: std_logic := '0';
  signal p2_d: std_logic := '0';
  signal p_start: std_logic := '1';
  signal p_select: std_logic := '1';
  signal p_color: std_logic := '1';
  signal sc: std_logic := '0';
  signal force_bs: std_logic_vector(3 downto 0) := "0000";
  signal pal: std_logic := '0';
  signal p_dif: std_logic_vector(1 downto 0) := (others => '0');

-- User IO
  signal switches   : std_logic_vector(1 downto 0);
  signal buttons    : std_logic_vector(1 downto 0);
  signal joy0       : std_logic_vector(31 downto 0);
  signal joy1       : std_logic_vector(31 downto 0);
  signal joy_a_0    : std_logic_vector(15 downto 0);
  signal joy_a_1    : std_logic_vector(15 downto 0);
  signal joy_ana_0  : std_logic_vector(15 downto 0);
  signal joy_ana_1  : std_logic_vector(15 downto 0);
  signal status     : std_logic_vector(31 downto 0);
  signal ascii_new  : std_logic;
  signal ascii_code : STD_LOGIC_VECTOR(6 DOWNTO 0);
  signal ps2Clk     : std_logic;
  signal ps2Data    : std_logic;
  signal ps2_scancode : std_logic_vector(7 downto 0);
  signal scandoubler_disable : std_logic;
  signal ypbpr      : std_logic;
  signal no_csync   : std_logic;

-- Data IO
  signal downl      : std_logic;
  signal index      : std_logic_vector(7 downto 0);
  signal file_ext   : std_logic_vector(23 downto 0);
  signal rom_a      : std_logic_vector(14 downto 0);
  signal rom_do     : std_logic_vector(7 downto 0);
  signal rom_size   : std_logic_vector(15 downto 0);
  signal rom_wr_a   : std_logic_vector(24 downto 0);
  signal rom_wr     : std_logic;
  signal rom_di     : std_logic_vector(7 downto 0);

  -- config string used by the io controller to fill the OSD
  constant CONF_STR : string :=
    "MA2601;A26BIN???;"&
    "F,A26BIN???,Load SuperChip;"&
    "O3,Difficulty P1,A,B;"&
    "O4,Difficulty P2,A,B;"&
    "O5,Controller,Joystick,Paddle;"&
    "O6,Joystick Swap,Off,On;"&
    "O1,Video standard,NTSC,PAL;"&
    "O2,Video mode,Color,B&W;"&
    "O78,Scanlines,Off,25%,50%,75%;";

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

  component data_io
  generic
  (
    ROM_DIRECT_UPLOAD : boolean := false
  );
  port
  (
    clk_sys : in std_logic;
    SPI_SCK, SPI_SS2, SPI_DI :in std_logic;
    clkref_n          : in  std_logic := '0';
    ioctl_download    : out std_logic;
    ioctl_index       : out std_logic_vector(7 downto 0);
    ioctl_fileext     : out std_logic_vector(23 downto 0);
    ioctl_wr          : out std_logic;
    ioctl_addr        : out std_logic_vector(24 downto 0);
    ioctl_dout        : out std_logic_vector(7 downto 0)
  );
  end component;

begin

-- -----------------------------------------------------------------------
-- MiST
-- -----------------------------------------------------------------------

  SDRAM_nCS <= '1'; -- disable ram
  res <= status(0) or buttons(1) or downl;
  p_color <= not status(2);
  pal <= status(1);
  p_dif(0) <= not status(3);
  p_dif(1) <= not status(4);
  joy_ana_0 <= joy_a_0 when status(6) = '0' else joy_a_1;
  joy_ana_1 <= joy_a_1 when status(6) = '0' else joy_a_0;
-- -----------------------------------------------------------------------
-- A2601 core
-- -----------------------------------------------------------------------
  a2601Instance : entity work.A2601NoFlash
    port map (
      vid_clk => vid_clk,
      clk => clk,
      audio => audio,
      O_VSYNC => O_VSYNC,
      O_HSYNC => O_HSYNC,
      O_VIDEO_R => O_VIDEO_R,
      O_VIDEO_G => O_VIDEO_G,
      O_VIDEO_B => O_VIDEO_B,
      res => res,
      p_l => p_l,
      p_r => p_r,
      p_a => p_a,
      p_b => p_b,
      p_u => p_u,
      p_d => p_d,
      p2_l => p2_l,
      p2_r => p2_r,
      p2_a => p2_a,
      p2_b => p2_b,
      p2_u => p2_u,
      p2_d => p2_d,
      paddle_0 => joy_ana_0(15 downto 8),
      paddle_1 => joy_ana_0(7 downto 0),
      paddle_2 => joy_ana_1(15 downto 8),
      paddle_3 => joy_ana_1(7 downto 0),
      paddle_ena => status(5),
      p_start => p_start,
      p_select => p_select,
      p_color => p_color,
      sc => sc,
      force_bs => force_bs,
      rom_a => rom_a,
      rom_do => rom_do,
      rom_size => rom_size,
      pal => pal,
      p_dif => p_dif,
      tv15khz => '1'
    );

  mist_video_inst : mist_video
    generic map (
        OSD_COLOR => "001"
    )
    port map (
        clk_sys     => vid_clk,
        scanlines   => status(8 downto 7),
        rotate      => "00",
        scandoubler_disable => scandoubler_disable,
        ypbpr       => ypbpr,
        no_csync => no_csync,

        SPI_SCK     => SPI_SCK,
        SPI_SS3     => SPI_SS3,
        SPI_DI      => SPI_DI,

        HSync       => not O_HSYNC,
        VSync       => not O_VSYNC,
        R           => O_VIDEO_R,
        G           => O_VIDEO_G,
        B           => O_VIDEO_B,

        VGA_HS      => VGA_HS,
        VGA_VS      => VGA_VS,
        VGA_R       => VGA_R,
        VGA_G       => VGA_G,
        VGA_B       => VGA_B
    );

  AUDIO_L <= audio;
  AUDIO_R <= audio;

  -- 9 pin d-sub joystick pinout:
  -- pin 1: up
  -- pin 2: down
  -- pin 3: left
  -- pin 4: right
  -- pin 6: fire

  -- Atari 2600, 6532 ports:
  -- PA0: right joystick, up
  -- PA1: right joystick, down
  -- PA2: right joystick, left
  -- PA3: right joystick, right
  -- PA4: left joystick, up
  -- PA5: left joystick, down
  -- PA6: left joystick, left
  -- PA7: left joystick, right
  -- PB0: start
  -- PB1: select
  -- PB3: B/W, color
  -- PB6: left difficulty
  -- PB7: right difficulty

  -- Atari 2600, TIA input:
  -- I5: right joystick, fire
  -- I6: left joystick, fire

  -- pinout docking station joystick 1/2:
  -- bit 0: up
  -- bit 1: down
  -- bit 2: left
  -- bit 3: right
  -- bit 4: fire
  -- bit 5: 2nd fire (required for paddle emulation)
  p_l <= not joy0(1) when status(6) = '0' else not joy1(1);
  p_r <= not joy0(0) when status(6) = '0' else not joy1(0);
  p_a <= not joy0(4) when status(6) = '0' else not joy1(4);
  p_b <= not joy0(5) when status(6) = '0' else not joy1(5);
  p_u <= not joy0(3) when status(6) = '0' else not joy1(3);
  p_d <= not joy0(2) when status(6) = '0' else not joy1(2);

  p2_l <= not joy1(1) when status(6) = '0' else not joy0(1);
  p2_r <= not joy1(0) when status(6) = '0' else not joy0(0);
  p2_a <= not joy1(4) when status(6) = '0' else not joy0(4);
  p2_b <= not joy1(5) when status(6) = '0' else not joy0(5);
  p2_u <= not joy1(3) when status(6) = '0' else not joy0(3);
  p2_d <= not joy1(2) when status(6) = '0' else not joy0(2);


-- -----------------------------------------------------------------------
-- Clocks and PLL
-- -----------------------------------------------------------------------
  pllInstance : entity work.pll27
    port map (
      inclk0 => CLOCK_27(0),
      c0 => vid_clk,
      c1 => clk,
      locked => open
    );

-- ------------------------------------------------------------------------
-- User IO
-- ------------------------------------------------------------------------

  user_io_inst : user_io
 	generic map (STRLEN => CONF_STR'length)
   port map (
      clk_sys => vid_clk,
      SPI_CLK => SPI_SCK,
      SPI_SS_IO => CONF_DATA0,
      SPI_MOSI => SPI_DI,
      SPI_MISO => SPI_DO,
      conf_str => to_slv(CONF_STR),
      switches => switches,
      buttons  => buttons,
      scandoubler_disable => scandoubler_disable,
      ypbpr => ypbpr,
      no_csync => no_csync,
      joystick_1 => joy0,
      joystick_0 => joy1,
      joystick_analog_1 => joy_a_0,
      joystick_analog_0 => joy_a_1,
      status => status,
      sd_sdhc => '1',
      ps2_kbd_clk => ps2Clk,
      ps2_kbd_data => ps2Data
    );

  data_io_inst: data_io
    port map (
      clk_sys => vid_clk,
      SPI_SCK => SPI_SCK,
      SPI_SS2 => SPI_SS2,
      SPI_DI => SPI_DI,
      ioctl_download => downl,
      ioctl_index    => index,
      ioctl_fileext  => file_ext,
      ioctl_wr       => rom_wr,
      ioctl_addr     => rom_wr_a,
      ioctl_dout     => rom_di
    );

  rom_inst: entity work.data_io_ram
    port map (
      -- wire up cpu port
      rdaddress => rom_a,
      rdclock => clk,
      q => rom_do,

      -- io controller port
      wraddress => rom_wr_a(14 downto 0),
      wrclock => vid_clk,
      data => rom_di,
      wren => rom_wr
    );

  rom_size <= std_logic_vector(unsigned('0'&rom_wr_a(14 downto 0)) + 1);

  -- 2nd menu index - load with SuperChip support OR 3rd character in extension is 's'
  sc <= '1' when index(1) = '1' or file_ext(7 downto 0) = x"53" or file_ext(7 downto 0) = x"73" else '0';

  -- force bank switch type by file extension
  process (file_ext) begin
    force_bs <= "0000";
    if    file_ext(23 downto 8) = x"4530" or file_ext(23 downto 8) = x"6530" then force_bs <= "0100"; -- E0
    elsif file_ext(23 downto 8) = x"4645" or file_ext(23 downto 8) = x"6665" then force_bs <= "0011"; -- FE
    elsif file_ext(23 downto 8) = x"3346" or file_ext(23 downto 8) = x"3366" then force_bs <= "0101"; -- 3F
    elsif file_ext(23 downto 8) = x"5032" or file_ext(23 downto 8) = x"7032" then force_bs <= "0111"; -- P2 (Pitfall II)
    elsif file_ext(23 downto 8) = x"4641" or file_ext(23 downto 8) = x"6661" then force_bs <= "1000"; -- FA
    elsif file_ext(23 downto 8) = x"4356" or file_ext(23 downto 8) = x"6376" then force_bs <= "1001"; -- CV
    elsif file_ext(23 downto 8) = x"4537" or file_ext(23 downto 8) = x"6537" then force_bs <= "1010"; -- E7
    elsif file_ext(23 downto 8) = x"5541" or file_ext(23 downto 8) = x"7561" then force_bs <= "1011"; -- UA
    end if;
  end process;

  keyboard : entity work.ps2Keyboard
    port map (vid_clk, '0', ps2Clk, ps2data, ps2_scancode);

  -- if a gamepad has 4 buttons then buttons 3 and 4 are mapped to start and select
  p_start  <= '0' when (ps2_scancode = X"01" or joy0(7) = '1' or joy1(7) = '1' ) else '1'; -- F9 or MiST right button
  p_select <= '0' when (ps2_scancode = X"09" or joy0(6) = '1' or joy1(6) = '1' ) else '1'; -- F10

  LED <= not downl; -- yellow led is bright when downloading ROM

end architecture;
