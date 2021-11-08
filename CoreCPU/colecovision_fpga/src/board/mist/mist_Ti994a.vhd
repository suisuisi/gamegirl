--
-- mist_Ti994a.vhd
--
-- TI994/A toplevel for the MiST board

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mist.all;
use work.vdp18_col_pack.all;
use work.build_id.all;

entity mist_ti994a is

  port (
    -- Clocks
    
    CLOCK_27    : in std_logic_vector(1 downto 0); -- 27 MHz


    -- SDRAM
    SDRAM_nCS : out std_logic; -- Chip Select
    SDRAM_DQ : inout std_logic_vector(15 downto 0); -- SDRAM Data bus 16 Bits
    SDRAM_A : out std_logic_vector(12 downto 0); -- SDRAM Address bus 13 Bits
    SDRAM_DQMH : out std_logic; -- SDRAM High Data Mask
    SDRAM_DQML : out std_logic; -- SDRAM Low-byte Data Mask
    SDRAM_nWE : out std_logic; -- SDRAM Write Enable
    SDRAM_nCAS : out std_logic; -- SDRAM Column Address Strobe
    SDRAM_nRAS : out std_logic; -- SDRAM Row Address Strobe
    SDRAM_BA : out std_logic_vector(1 downto 0); -- SDRAM Bank Address
    SDRAM_CLK : out std_logic; -- SDRAM Clock
    SDRAM_CKE: out std_logic; -- SDRAM Clock Enable

    -- SPI
    SPI_SCK : in std_logic;
    SPI_DI : in std_logic;
    SPI_DO : out std_logic;
    SPI_SS2 : in std_logic;
    SPI_SS3 : in std_logic;
    CONF_DATA0 : in std_logic;

    -- VGA output
    

    VGA_HS,                                             -- H_SYNC
    VGA_VS : out std_logic;                             -- V_SYNC
    VGA_R,                                              -- Red[5:0]
    VGA_G,                                              -- Green[5:0]
    VGA_B : out std_logic_vector(5 downto 0);           -- Blue[5:0]
    
    -- Audio
    AUDIO_L,
    AUDIO_R : out std_logic;
    
    -- LEDG
    LED : out std_logic;

    UART_RX : in std_logic;
    UART_TX : out std_logic

    );

end mist_ti994a;

architecture rtl of mist_ti994a is

  constant CONF_STR : string := "TI994A;;"&
                                "F,C  D  G  ,Load;"&
                                "F,BIN,Load Full or C.bin;"&
                                "F,BIN,Load D.bin;"&
                                "F,BIN,Load G.bin;"&
                                "S0U,DSK,Drive 1;"&
                                "S1U,DSK,Drive 2;"&
--                                "OD,Cart Type,Normal,MBX;"&
                                "OE,Scratchpad RAM,256B,1KB;"&
                                "OA,Turbo,Off,On;"&
                                "OGH,Speech,Off,5220,5200;"&
                                "O6,Joystick swap,Off,On;"&
                                "O23,Scanlines,Off,25%,50%,75%;"&
                                "O5,Blend,Off,On;"&
                                "T0,Reset;"&
                                "V,v"&BUILD_DATE;

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
        clk_sys                   : in std_logic;
        SPI_SCK, SPI_SS2, SPI_SS4, SPI_DI, SPI_DO :in std_logic;
        clkref_n          : in  std_logic := '0';
        ioctl_download    : out std_logic;
        ioctl_index       : out std_logic_vector(7 downto 0);
        ioctl_wr          : out std_logic;
        ioctl_addr        : out std_logic_vector(24 downto 0);
        ioctl_dout        : out std_logic_vector(7 downto 0)
    );
  end component data_io;

  component sdram
    generic ( MHZ: integer := 84 );
    port (
        SDRAM_DQ    : inout std_logic_vector(15 downto 0);
        SDRAM_A     : out std_logic_vector(12 downto 0);
        SDRAM_DQML  : out std_logic;
        SDRAM_DQMH  : out std_logic;
        SDRAM_BA    : out std_logic_vector( 1 downto 0);
        SDRAM_nCS   : out std_logic;
        SDRAM_nWE   : out std_logic;
        SDRAM_nRAS  : out std_logic;
        SDRAM_nCAS  : out std_logic;

        init_n      : in  std_logic;
        clk         : in  std_logic;

        port1_req   : in  std_logic;
        port1_ack   : out std_logic;
        port1_we    : in  std_logic;
        port1_a     : in  std_logic_vector(23 downto 1);
        port1_ds    : in  std_logic_vector( 1 downto 0);
        port1_d     : in  std_logic_vector(15 downto 0);
        port1_q     : out std_logic_vector(15 downto 0)
    );
  end component sdram;

  component TI994A_keyboard
    port (
      clk_sys           : in  std_logic;
      key_strobe        : in  std_logic;
      key_pressed       : in  std_logic;
      key_code          : in  std_logic_vector( 7 downto 0);
      joy_swap          : in  std_logic;
      joy0              : in  std_logic_vector(15 downto 0);
      joy1              : in  std_logic_vector(15 downto 0);
      keyboardSignals_i : in  std_logic_vector( 8 downto 0);
      keyboardSignals_o : out std_logic_vector( 7 downto 0)
    );
  end component TI994A_keyboard;

  signal clk21m3 : std_logic;
  signal clkref  : std_logic;
  signal rom_en  : std_logic;
  signal force_reset : std_logic := '0';
  signal reset_n_s : std_logic;
  
  signal switches   : std_logic_vector(1 downto 0);
  signal buttons    : std_logic_vector(1 downto 0);
  signal joy        : std_logic_vector(5 downto 0);
  signal joy0       : std_logic_vector(31 downto 0);
  signal joy1       : std_logic_vector(31 downto 0);
  signal joy_an0    : std_logic_vector(15 downto 0);
  signal joy_an1    : std_logic_vector(15 downto 0);
  signal joy_an     : std_logic_vector(15 downto 0);
  signal status     : std_logic_vector(63 downto 0);
  signal scandoubler_disable : std_logic;
  signal ypbpr      : std_logic;
  signal no_csync   : std_logic;
  signal key_strobe : std_logic;
  signal key_pressed: std_logic;
  signal key_code   : std_logic_vector(7 downto 0);
  signal audio      : std_logic;
  signal pll_locked : std_logic;
  signal joya       : std_logic_vector(7 downto 0);
  signal joyb       : std_logic_vector(7 downto 0);

  -- sd io
  signal sd_lba         : std_logic_vector(31 downto 0);
  signal sd_rd          : std_logic_vector(1 downto 0) := "00";
  signal sd_wr          : std_logic_vector(1 downto 0) := "00";
  signal sd_ack         : std_logic;
  signal sd_conf        : std_logic;
  signal sd_sdhc        : std_logic;
  signal sd_din         : std_logic_vector(7 downto 0);
  signal sd_dout        : std_logic_vector(7 downto 0);
  signal sd_dout_strobe : std_logic;
  signal sd_buff_addr   : std_logic_vector(8 downto 0);
  signal img_mounted    : std_logic_vector(1 downto 0);
  signal img_size       : std_logic_vector(63 downto 0);

  signal red        : std_logic_vector(7 downto 0);
  signal green      : std_logic_vector(7 downto 0);
  signal blue       : std_logic_vector(7 downto 0);
  signal hs         : std_logic;
  signal vs         : std_logic;
    
  signal index          : std_logic_vector(7 downto 0);
  signal downl          : std_logic := '0';
  signal old_downl      : std_logic;
  
  signal clk_cnt_q            : unsigned(1 downto 0);
  signal clk_sys_s      : std_logic;
  signal clk_mem_s      : std_logic;
  signal clk_mem_cnt    : unsigned(2 downto 0);
  signal clk_en_10m7_q			  : std_logic;
  signal por_n_s              : std_logic;

  signal cpu_ram_a_s         : std_logic_vector(18 downto 0);
  signal cpu_ram_ce_n_s      : std_logic;
  signal cpu_ram_we_n_s      : std_logic;
  signal cpu_ram_d_to_ti_s,
         cpu_ram_d_from_ti_s : std_logic_vector(15 downto 0);
  signal cpu_ram_we_s        : std_logic;
  signal cpu_ram_be_n_s      : std_logic_vector( 1 downto 0);

  signal vram_a_s            : std_logic_vector(13 downto 0);
  signal vram_we_s           : std_logic;
  signal vram_d_to_cv_s,
         vram_d_from_cv_s    : std_logic_vector( 7 downto 0);

  signal speech_rom_a_s      : std_logic_vector(14 downto 0);
  signal speech_rom_d_s      : std_logic_vector( 7 downto 0);

  signal unsigned_audio_s    : std_logic_vector(10 downto 0);
  signal audio_s             : std_logic;

  signal kbd_i_s             : std_logic_vector( 8 downto 0);
  signal kbd_o_s             : std_logic_vector( 7 downto 0);

  signal rommask_s          : std_logic_vector(6 downto 1);
  signal romwr_a            : std_logic_vector(24 downto 0);
  signal ioctl_dout         : std_logic_vector(7 downto 0);
  signal rom_wr             : std_logic;
  signal sd_wrack           : std_logic;
  signal uart_rx_d          : std_logic;
  signal uart_rx_d2         : std_logic;

  signal sdram_addr         : std_logic_vector(24 downto 0);
  signal sdram_bs           : std_logic_vector( 1 downto 0);
  signal sdram_dout         : std_logic_vector(15 downto 0);
  signal sdram_din          : std_logic_vector(15 downto 0);
  signal ram_rd             : std_logic;
  signal ram_rdD            : std_logic;
  signal ram_we             : std_logic;
  signal ram_weD            : std_logic;
  signal sdram_req          : std_logic;
  signal sdram_we           : std_logic;

begin

  LED <= not downl;
  reset_n_s <= not(status(0) or buttons(1) or force_reset or not pll_locked);

  pll : entity work.mist_pll
    port map (
      inclk0 => CLOCK_27(0),
      c0     => clk_mem_s, -- 84 MHz
      c1     => clk_sys_s, -- 42 MHz
      locked => pll_locked
      );

  SDRAM_CLK <= clk_mem_s;
  SDRAM_CKE <= '1';

  UART_TX <= '1';
  uart: process (clk_sys_s)
  begin
    if clk_sys_s'event and clk_sys_s = '1' then
        uart_rx_d <= UART_RX;
        uart_rx_d2 <= uart_rx_d;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Process clk_cnt
  --
  -- Purpose:
  --   Counts the base clock and derives the clock enables.
  --
  clk_cnt: process (clk_sys_s, reset_n_s)
  begin
    if reset_n_s = '0' then
      clk_cnt_q     <= (others => '0');
      clk_en_10m7_q <= '0';

    elsif clk_sys_s'event and clk_sys_s = '1' then
      -- Clock counter --------------------------------------------------------
      if clk_cnt_q = 3 then
        clk_cnt_q <= (others => '0');
      else
        clk_cnt_q <= clk_cnt_q + 1;
      end if;

      -- 10.7 MHz clock enable ------------------------------------------------
      case clk_cnt_q is
        when "01" =>
          clk_en_10m7_q <= '1';
        when others =>
          clk_en_10m7_q <= '0';
      end case;

    end if;
  end process clk_cnt;

  -----------------------------------------------------------------------------
  -- The TI99/4A module
  -----------------------------------------------------------------------------

  ti994a : entity work.ep994a
    generic map (
      is_pal_g        => 0,
      compat_rgb_g    => 0
    )
    port map (
      clk_i           => clk_sys_s,
      clk_en_10m7_i   => clk_en_10m7_q,
      reset_n_i       => reset_n_s,
      por_n_o         => por_n_s,

      epGPIO_i        => kbd_o_s,
      epGPIO_o        => kbd_i_s,

      cpu_ram_a_o     => cpu_ram_a_s,
      cpu_ram_ce_n_o  => cpu_ram_ce_n_s,
      cpu_ram_we_n_o  => cpu_ram_we_n_s,
      cpu_ram_be_n_o  => cpu_ram_be_n_s,
      cpu_ram_d_i     => cpu_ram_d_to_ti_s,
      cpu_ram_d_o     => cpu_ram_d_from_ti_s,

      vram_a_o        => vram_a_s,
      vram_we_o       => vram_we_s,
      vram_d_o        => vram_d_from_cv_s,
      vram_d_i        => vram_d_to_cv_s,

      rgb_r_o         => red,
      rgb_g_o         => green,
      rgb_b_o         => blue,
      hsync_n_o       => hs,
      vsync_n_o       => vs,
      audio_total_o   => unsigned_audio_s,

      speech_model    => not status(17 downto 16),
      sr_re_o         => open,
      sr_addr_o       => speech_rom_a_s,
      sr_data_i       => speech_rom_d_s,

      sd_lba          => sd_lba,
      sd_rd           => sd_rd,
      sd_wr           => sd_wr,
      sd_ack          => sd_ack,
      sd_dout         => sd_dout,
      sd_dout_strobe  => sd_dout_strobe,
      sd_din          => sd_din,
      sd_buff_addr    => sd_buff_addr,
      img_mounted     => img_mounted,
      img_size        => img_size(31 downto 0),
      img_wp          => "00",

      rommask_i       => rommask_s,
      scratch_1k_i    => status(14),
      mbx_i           => '0',--status(13),
      flashloading_i  => downl,
      turbo_i         => status(10)
    );

  keyboard : TI994A_keyboard
    port map (
      clk_sys           => clk_sys_s,
      key_strobe        => key_strobe,
      key_pressed       => key_pressed,
      key_code          => key_code,
      joy_swap          => status(6),
      joy0              => joy0(15 downto 0),
      joy1              => joy1(15 downto 0),
      keyboardSignals_i => kbd_i_s,
      keyboardSignals_o => kbd_o_s
    );

  -----------------------------------------------------------------------------
  -- SPEECH ROM
  -----------------------------------------------------------------------------
  speech_rom : entity work.sprom
    generic map
    (
      widthad_a   => 15,
      init_file   => "../../../roms/hex/spchrom.hex"
    )
    port map
    (
      clock       => clk_sys_s,
      address     => speech_rom_a_s,
      q           => speech_rom_d_s
    );

  -----------------------------------------------------------------------------
  -- VRAM
  -----------------------------------------------------------------------------
  
  vram_b : entity work.spram
    generic map (
      widthad_a      => 14
    )
    port map (
      wren      => vram_we_s,
      address   => vram_a_s,
      clock     => clk_sys_s,
      data      => vram_d_from_cv_s,
      q         => vram_d_to_cv_s
    );

  -----------------------------------------------------------------------------
  -- Video output
  -----------------------------------------------------------------------------
  
  mist_video : work.mist.mist_video
    generic map (
      SD_HCNT_WIDTH => 11,
      COLOR_DEPTH => 6,
      OSD_COLOR => "011",
      OSD_X_OFFSET => "00"&x"10"
    )
    port map (
      clk_sys     => clk_sys_s,
      scanlines   => status(3 downto 2),
      scandoubler_disable => scandoubler_disable,
      ypbpr       => ypbpr,
      no_csync    => no_csync,
      rotate      => "00",
      blend       => status(5),
      ce_divider  => '1',

      SPI_SCK     => SPI_SCK,
      SPI_SS3     => SPI_SS3,
      SPI_DI      => SPI_DI,

      HSync       => hs,
      VSync       => vs,
      R           => red(7 downto 2),
      G           => green(7 downto 2),
      B           => blue(7 downto 2),      

      VGA_HS      => VGA_HS,
      VGA_VS      => VGA_VS,
      VGA_R       => VGA_R,
      VGA_G       => VGA_G,
      VGA_B       => VGA_B
    );
   
  -----------------------------------------------------------------------------

  dac : entity work.dac
    generic map (11)
    port map (
      clk_i     => clk_sys_s,
      res_n_i   => reset_n_s,
      dac_i     => std_logic_vector(unsigned_audio_s),
      dac_o     => audio_s
    ); 
    
-- MiST interfaces

  sd_sdhc <= '1';
  sd_conf <= '0';

  user_io_d : user_io
    generic map (STRLEN => CONF_STR'length)
    
    port map ( 
      clk_sys => clk_sys_s,
      clk_sd => clk_sys_s,
      SPI_CLK => SPI_SCK,
      SPI_SS_IO => CONF_DATA0,    
      SPI_MISO => SPI_DO,    
      SPI_MOSI => SPI_DI,       
      conf_str => to_slv(CONF_STR),
      status => status,
      joystick_0 => joy0,
      joystick_1 => joy1,
      joystick_analog_0 => joy_an0,
      joystick_analog_1 => joy_an1,
      scandoubler_disable => scandoubler_disable,
      ypbpr =>ypbpr,
      no_csync => no_csync,
      SWITCHES => switches,   
      BUTTONS => buttons,
      key_strobe => key_strobe,
      key_pressed => key_pressed,
      key_code => key_code,

      sd_lba  => sd_lba,
      sd_rd   => sd_rd,
      sd_wr   => sd_wr,
      sd_ack  => sd_ack,
      sd_sdhc => sd_sdhc,
      sd_conf => sd_conf,
      sd_dout => sd_dout,
      sd_dout_strobe => sd_dout_strobe,
      sd_din => sd_din,
      sd_buff_addr => sd_buff_addr,
      img_mounted => img_mounted,
      img_size => img_size
    );

  data_io_inst: data_io
    port map(clk_mem_s, SPI_SCK, SPI_SS2, '1', SPI_DI, '1', not clkref, downl, index, rom_wr, romwr_a, ioctl_dout);

  ---------------------------------------------------------
  -- 00000..7FFFF - Cartridge module port, paged, 512K, to support the TI megademo :)
  -- 80000..8FFFF - GROM mapped to this area, 64K (was at 30000)
  -- 90000..AFFFF - Not used currently
  -- B0000..B7FFF - DSR area, 32K reserved	(was at 60000)
  -- B8000..B8FFF - Scratchpad 	(was at 68000)
  -- BA000..BCFFF - Boot ROM remapped (was at 0)   
  -- C0000..FFFFF - SAMS SRAM 256K (i.e. the "normal" CPU RAM paged with the SAMS system)
  ---------------------------------------------------------

  ext_ram_rom: sdram
  port map (
        SDRAM_DQ    => SDRAM_DQ,
        SDRAM_A     => SDRAM_A,
        SDRAM_DQML  => SDRAM_DQML,
        SDRAM_DQMH  => SDRAM_DQMH,
        SDRAM_BA    => SDRAM_BA,
        SDRAM_nCS   => SDRAM_nCS,
        SDRAM_nWE   => SDRAM_nWE,
        SDRAM_nRAS  => SDRAM_nRAS,
        SDRAM_nCAS  => SDRAM_nCAS,

        init_n      => pll_locked,
        clk         => clk_mem_s,

        port1_req   => sdram_req,
        port1_ack   => open,
        port1_we    => sdram_we,
        port1_a     => sdram_addr(23 downto 1),
        port1_ds    => sdram_bs,
        port1_d     => sdram_din,
        port1_q     => sdram_dout
  );

  -- apply some mask when .D was loaded last
  rommask_s <= "111111" when index /= x"03" and index /= x"41" else -- not .D
               "000001" when romwr_a(24 downto 14) = "00000000000" else
               "000011" when romwr_a(24 downto 15) = "0000000000" else
               "000111" when romwr_a(24 downto 16) = "000000000" else
               "001111" when romwr_a(24 downto 17) = "00000000" else
               "011111" when romwr_a(24 downto 18) = "0000000" else
               "111111";

  cpu_ram_d_to_ti_s <= sdram_dout;
  sdram_addr <= "00000" & cpu_ram_a_s & '0' when downl = '0' else
                romwr_a when index = x"02" or index = x"01" else -- .c
                std_logic_vector(unsigned(romwr_a) + x"2000")  when index = x"03" or index = x"41" else -- .d
                std_logic_vector(unsigned(romwr_a) + x"86000") when index = x"04" or index = x"81" else -- .g
                std_logic_vector(unsigned(romwr_a) + x"80000"); -- .rom

  ram_we <= not (cpu_ram_ce_n_s or cpu_ram_we_n_s) when downl = '0' else rom_wr;
  ram_rd <= not (cpu_ram_ce_n_s or not cpu_ram_we_n_s) when downl = '0' else '0';
  sdram_din <= cpu_ram_d_from_ti_s when downl = '0' else ioctl_dout & ioctl_dout;
  sdram_bs <= not cpu_ram_be_n_s when downl = '0' else not romwr_a(0) & romwr_a(0);

  clkref <= '1' when clk_mem_cnt = "000" else '0';
  force_reset <= downl;

  process(clk_mem_s)
  begin
    if rising_edge (clk_mem_s) then
        clk_mem_cnt <= clk_mem_cnt + 1;
        ram_weD <= ram_we;
        ram_rdD <= ram_rd;
        if (ram_we = '1' and ram_weD = '0') or (ram_rd = '1' and ram_rdD = '0') then
          sdram_req <= not sdram_req;
          sdram_we <= ram_we;
        end if;
    end if;
  end process;

  AUDIO_L     <= audio_s;
  AUDIO_R     <= audio_s;

end rtl;