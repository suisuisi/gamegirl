library work;
use work.vram.all;
use work.vram32.all;
use work.video.all;
use work.cpu.all;

library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.textio.all;

-- `timescale 1us/1ns
    
entity vdp_tb is
end;

architecture vdp_tb of vdp_tb is

  -- include vdp
component vdp
       port(
                RST_N           : in std_logic;
                CLK                     : in std_logic;

                SEL                     : in std_logic;
                A                       : in std_logic_vector(4 downto 0);
                RNW                     : in std_logic;
                DI                      : in std_logic_vector(15 downto 0);
                DO                      : out std_logic_vector(15 downto 0);
                DTACK_N         : out std_logic;

                vram_req : out std_logic;
                vram_ack : in std_logic;
                vram_we : out std_logic;
                vram_a : out std_logic_vector(15 downto 1);
                vram_d : out std_logic_vector(15 downto 0);
                vram_q : in std_logic_vector(15 downto 0);
                vram_u_n : out std_logic;
                vram_l_n : out std_logic;

                vram32_req : out std_logic;
                vram32_ack : in std_logic;
                vram32_a : out std_logic_vector(15 downto 1);
                vram32_q : in std_logic_vector(31 downto 0);

                HINT            : out std_logic;
                INTACK          : in std_logic;
                VINT_TG68       : out std_logic;
                VINT_T80        : out std_logic;

                BR_N_I          : in std_logic := '1';
                BR_N_O          : out std_logic;
                BG_N            : in std_logic := '1';
                BGACK_N_I       : in std_logic := '1';
                BGACK_N_O       : out std_logic;
                AS_N            : in std_logic := '1';

                VBUS_ADDR       : out std_logic_vector(23 downto 1);
                VBUS_DATA       : in std_logic_vector(15 downto 0);

                VBUS_SEL        : out std_logic;
                VBUS_DTACK_N    : in std_logic;

                PAL             : in std_logic := '0';

                CE_PIX          : buffer std_logic;
                FIELD_OUT       : out std_logic;
                INTERLACE       : out std_logic;
                RESOLUTION      : out std_logic_vector(1 downto 0);
                HBL             : out std_logic;
                VBL             : out std_logic;

                R               : out std_logic_vector(3 downto 0);
                G               : out std_logic_vector(3 downto 0);
                B               : out std_logic_vector(3 downto 0);
                HS              : out std_logic;
                VS              : out std_logic;

                VRAM_SPEED      : in std_logic := '1';
                VSCROLL_BUG     : in std_logic := '0';
                BORDER_EN       : in std_logic := '1';
                CRAM_DOTS       : in std_logic := '0'

        );
end component ;

signal   clk      : std_logic := '0';
signal   memclk   : std_logic := '0';
signal   reset_n  : std_logic := '1';

signal vram_req_loop: std_logic;
signal vram_we: std_logic;
signal vram_a: std_logic_vector(15 downto 1);
signal vram_q: std_logic_vector(15 downto 0);
signal vram_d: std_logic_vector(15 downto 0);

signal vram32_req: std_logic;
signal vram32_ack: std_logic;
signal vram32_we: std_logic;
signal vram32_a: std_logic_vector(15 downto 1);
signal vram32_q: std_logic_vector(31 downto 0);

signal CPU_SEL: std_logic;
signal CPU_A: std_logic_vector(4 downto 0);
signal CPU_RNW: std_logic;
signal CPU_UDS_N: std_logic;
signal CPU_LDS_N: std_logic;
signal CPU_DI: std_logic_vector(15 downto 0);
signal CPU_DTACK_N: std_logic;

signal VIDEO_R: std_logic_vector(3 downto 0);
signal VIDEO_G: std_logic_vector(3 downto 0);
signal VIDEO_B: std_logic_vector(3 downto 0);
signal VIDEO_HS: std_logic;
signal VIDEO_VS: std_logic;
    
begin
  -- wire up vdp
  vdp_i : vdp 
    port map (
      RST_N => reset_n,
      CLK => clk,

      -- CPU bus interface
      SEL => CPU_SEL,
      A => CPU_A,
      RNW => CPU_RNW,
      DI => CPU_DI,
      DTACK_N => CPU_DTACK_N,
      
      vram_a => vram_a,
      vram_req => vram_req_loop,
      vram_ack => vram_req_loop,
      vram_q => vram_q,
      vram_we => vram_we,
      vram_d => vram_d,

      vram32_a => vram32_a,
      vram32_req => vram32_req,
      vram32_ack => vram32_ack,
      vram32_q => vram32_q,

      INTACK => '0',
      BG_N => '0',
      BR_N_I => '1',
      BGACK_N_I => '1',
      AS_N => '1',

      VBUS_DATA => "0000000000000000",

      VBUS_DTACK_N => '0',

      PAL => '0',
      R => VIDEO_R,
      G => VIDEO_G,
      B => VIDEO_B,
      HS => VIDEO_HS,
      VS => VIDEO_VS
  );

-- generate a 50mhz clock
  memory_clock : process
  begin
    wait for 5 ns; memclk  <= not memclk;
  end process memory_clock;

  clock : process(memclk)
  begin
    if (memclk = '1' and memclk'event) then
      clk <= not clk;    
    end if;   
  end process clock;

  stimulus : process
  begin
    report "start";

    reset_n <= '0';
    wait for 5 ns; reset_n <= '1';
    
    assert false report "vdp out of reset"
      severity note;

    wait;
  end process stimulus;
  
  memory : process (memclk)
    variable c : std_logic;
    variable we : std_logic;
    variable a : std_logic_vector(15 downto 1);
    variable q : std_logic_vector(15 downto 0);
    variable d : std_logic_vector(15 downto 0);
  begin
    -- wire memory
    c := memclk;
    a := vram_a;
    we := vram_we;
    d := vram_d;
    vram_c(c,we,d,a,q);
    
    if (memclk = '0' and memclk'event) then
      vram_q <= q;    
    end if;   
 end process memory;

  memory32 : process (memclk)
    variable c : std_logic;
    variable a : std_logic_vector(15 downto 1);
    variable q : std_logic_vector(31 downto 0);
  begin
    -- wire memory

    if (memclk = '0' and memclk'event) then
      if vram32_req /= vram32_ack then
        vram32_ack <= vram32_req;
        c := memclk;
        a := vram32_a;
        vram32_c(c,a,q);
        vram32_q <= q;
      end if;
    end if;
 end process memory32;

 video : process (clk)
    variable c : std_logic;
    variable hs : std_logic;
    variable vs : std_logic;
    variable r : std_logic_vector(3 downto 0);
    variable g : std_logic_vector(3 downto 0);
    variable b : std_logic_vector(3 downto 0);
  begin
    -- wire memory
    c := clk;
    hs := VIDEO_HS; vs := VIDEO_VS;
    r := VIDEO_R; g := VIDEO_G; b := VIDEO_B;
    video_c(c,r,g,b,hs,vs);
 end process video;

 cpu : process (clk, reset_n)
    variable c : std_logic;
    variable r_n : std_logic;
    variable sel : std_logic;
    variable dtack_n : std_logic;
    variable rnw : std_logic;
    variable ds_n : std_logic_vector(1 downto 0);
    variable a : std_logic_vector(4 downto 0);
    variable d : std_logic_vector(15 downto 0);
  begin
    c := clk;
    r_n := reset_n;
    dtack_n := CPU_DTACK_N;
    
    cpu_c(c,r_n,sel,dtack_n,rnw,ds_n,a,d);

    CPU_SEL <= sel;
    CPU_RNW <= rnw;
    CPU_UDS_N <= ds_n(0);
    CPU_LDS_N <= ds_n(1);
    CPU_A <= a;
    CPU_DI <= d;
 end process cpu;

end vdp_tb;

