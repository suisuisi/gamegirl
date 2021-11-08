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
USE ieee.math_real.ceil;
USE ieee.math_real.log2;
use IEEE.STD_LOGIC_MISC.all;

ENTITY svideo_gtia IS
PORT 
( 
	CLK : IN STD_LOGIC; -- 56.75MHz PAL, 57.272727... NTSC
	RESET_N : IN STD_LOGIC;

	brightness : in std_logic_vector(3 downto 0);
	hue : in std_logic_vector(3 downto 0);
	burst : in std_logic;
	blank : in std_logic;
	sof : in std_logic;
	csync_n : in std_logic;
	vpos_lsb : in std_logic;
	pal : in std_logic;

	composite : in std_logic;
	
	chroma : out std_logic_vector(7 downto 0);
	luma : out std_logic_vector(7 downto 0); -- or composite
	luma_sync_n : out std_logic
);
END svideo_gtia;

ARCHITECTURE vhdl OF svideo_gtia IS
	signal chroma_next : std_logic_vector(7 downto 0);
	signal chroma_reg : std_logic_vector(7 downto 0);
	signal luma_next : std_logic_vector(7 downto 0);
	signal luma_reg : std_logic_vector(7 downto 0);
	signal phase_count_next : std_logic_vector(7 downto 0);
	signal phase_count_reg : std_logic_vector(7 downto 0);

	signal sin_phase : std_logic_vector(7 downto 0);
	--signal sin_phase_real :real;
	signal sin_moving_phase : std_logic_vector(7 downto 0);
	signal sin_on : std_logic;

	signal hue_adj : std_logic_vector(3 downto 0);
	signal hue_delay : std_logic_vector(3 downto 0);
	signal brightness_scaled : std_logic_vector(7 downto 0);
	signal sin_shifted : signed(7 downto 0);
	signal colour_shift : std_logic_vector(7 downto 0);
	signal base_shift : std_logic_vector(7 downto 0);
BEGIN
	-- regs
	process(clk,reset_n)
	begin
		if (reset_n='0') then
			chroma_reg <= (others=>'0');
			luma_reg <= (others=>'0');
			phase_count_reg <= (others=>'0');
		elsif (clk'event and clk='1') then
			chroma_reg <= chroma_next;
			luma_reg <= luma_next;
			phase_count_reg <= phase_count_next;
		end if;
	end process;

	-- next state
	-- 4.43361875MHz - PAL carrier  - i.e. 12.8 clock cycles per sin wave! so if we have 256 sine entries,+5*16/4 per cycle, +20 per cycle
	-- 3.579545MHz   - NTSC carrier - i.e. 16 clock cycles per sin wave. so if we have 256 sine entries,+16 per cycle
	-- NTSC:hue1=same phase as colour carrier, each next has 24 degree shift (adjustable) ... 17.066/256? Will 17 do?
	-- PAL:hue1=same phase as colour burst, each next has 22.5 degree shift (adjustable). adjust phase each line. 135/225 degrees for burst/hue1... 16/256, nice!

	process(sof,pal,phase_count_reg)
	begin
		phase_count_next <= (others=>'0');

		if (sof = '1') then
			phase_count_next <= (others=>'0');
		else
			if (pal = '1') then
				phase_count_next <= std_logic_vector(unsigned(phase_count_reg) + 20);
			else
				phase_count_next <= std_logic_vector(unsigned(phase_count_reg) + 16);
			end if;
		end if;
	end process;

	process(hue,hue_adj,vpos_lsb,burst,pal)
		variable hue_use : std_logic_vector(3 downto 0);
	begin
		hue_adj <= "0000";

		hue_use := hue;

		if (burst = '1') then
			hue_use := x"1";
		end if;

		if pal='1' then
			-- pal has some gaps...
			if (unsigned(hue_use)>6) then
				hue_adj <= "000"&pal;
			end if;

			if (unsigned(hue_use)>10) then
				hue_adj <= "00"&pal&"0";
			end if;

			if vpos_lsb='1' then
				hue_delay <= std_logic_vector(to_unsigned(0,4)-unsigned(hue_use)-unsigned(hue_adj)); 
			else
				hue_delay <= std_logic_vector(to_unsigned(2,4)+unsigned(hue_use)+unsigned(hue_adj)); 
			end if;
		else
			hue_delay <= std_logic_vector(to_unsigned(0,4)-unsigned(hue_use));
		end if;
	end process;

	process(hue_delay,pal)
	begin
		colour_shift <= hue_delay&"0000";
		if pal='0' then
			colour_shift <= std_logic_vector(unsigned(hue_delay&"0000") + unsigned("000"&hue_delay&"0"));
		end if;
	end process;

	process(pal)
	begin
		if (pal = '1') then
			base_shift <= std_logic_vector(to_unsigned(112,8)); -- 157.5 degrees (256*157.5/360)
		else
			base_shift <= std_logic_vector(to_unsigned(248,8)); -- -12 degrees (256*348/360)
		end if;
	end process;

	process(blank,burst,colour_shift,hue,phase_count_reg,sin_phase,base_shift)
	begin
		sin_on <= '0';

		sin_phase <=std_logic_vector(unsigned(base_shift)+unsigned(colour_shift));
		--sin_phase_real <= real(to_integer(unsigned(sin_phase)))*real(360)/real(256);
		sin_moving_phase <=std_logic_vector(unsigned(phase_count_reg) + unsigned(sin_phase));

		if (blank='1') then
			sin_on <= burst;
		else
			sin_on <= or_reduce(hue);
		end if;
	end process;

	-- we use 0.25v/0.7v for the colour sin - i.e. 90/256, leaving 166/256 spare for luma. Here we output signed -44 to 44
 	process (sin_on, sin_moving_phase)
		type LOOKUP_TYPE is array (0 to 63) of std_logic_vector(7 downto 0);
		variable lookup : LOOKUP_TYPE;
		variable sin_x : std_logic_vector(5 downto 0);
		variable sin_y : std_logic_vector(7 downto 0);
	begin
		sin_shifted <= x"00";

		-- make use of symmetry
		-- sin_moving_phase)(6) = flipx
		-- sin_moving_phase)(7) = flipy
		if sin_moving_phase(6)='0' then
			sin_x := sin_moving_phase(5 downto 0);
		else
			sin_x := std_logic_vector(to_unsigned(63,6)-unsigned(sin_moving_phase(5 downto 0)));
		end if;

		lookup := (
x"01",x"02",x"03",x"04",x"05",x"06",x"08",x"09",x"0a",x"0b",x"0c",x"0d",x"0e",x"0f",x"10",x"11",x"12",x"13",x"14",x"15",x"16",x"17",x"18",x"18",x"19",x"1a",x"1b",x"1c",x"1d",x"1e",x"1e",x"1f",x"20",x"21",x"21",x"22",x"23",x"23",x"24",x"25",x"25",x"26",x"26",x"27",x"27",x"28",x"28",x"29",x"29",x"29",x"2a",x"2a",x"2a",x"2b",x"2b",x"2b",x"2b",x"2c",x"2c",x"2c",x"2c",x"2c",x"2c",x"2c");

		sin_y := lookup(to_integer(unsigned(sin_x)));
		if (sin_on = '1') then
			if sin_moving_phase(7)='0' then
				sin_shifted <= signed(sin_y);
			else
				sin_shifted <= -signed(sin_y);
			end if;
		end if;
        end process;

	process(brightness,blank)
	begin
		brightness_scaled <= (others=>'0');
		if (blank='0') then
			brightness_scaled <= std_logic_vector(unsigned("0000"&brightness) + unsigned("000"&brightness&"0") + unsigned("0"&brightness&"000")); -- multiply by 11
		end if;
	end process;

	process(sin_shifted,brightness_scaled,composite,chroma_next)
	begin

		if (composite = '0') then
			luma_next <= brightness_scaled;
		else
			luma_next <= std_logic_vector(unsigned(brightness_scaled) + unsigned(chroma_next));
		end if;

		chroma_next <= std_logic_vector(sin_shifted + x"2c");
	end process;

	-- outputs
	luma_sync_n <= csync_n;
	luma <= luma_reg;
	chroma <= chroma_reg;

END vhdl;

