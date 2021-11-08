library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;
  use ieee.std_logic_textio.all;

library std_developerskit ; -- used for to_string
--  use std_developerskit.std_iopak.all;

entity atari800xl_tb is
end;

architecture rtl of atari800xl_tb is

  constant CLK_A_PERIOD : time := 1 us / (1.79*32);

  signal reset_n : std_logic;
	signal clk_a : std_logic;

	-- VIDEO OUT - PAL/NTSC, original Atari timings approx (may be higher res)
	SIGNAL VIDEO_VS :   STD_LOGIC;
	SIGNAL VIDEO_HS :   STD_LOGIC;
	SIGNAL VIDEO_CS :   STD_LOGIC;
	SIGNAL VIDEO_COLOUR :   STD_LOGIC_VECTOR(7 DOWNTO 0);
	-- These ones are probably only needed for e.g. svideo
	SIGNAL VIDEO_BLANK :  std_logic;
	SIGNAL VIDEO_BURST :  std_logic;
	SIGNAL VIDEO_START_OF_FIELD :  std_logic;
	SIGNAL VIDEO_ODD_LINE :  std_logic;

	-- AUDIO - Pokey/GTIA 1-bit and Covox all mixed
	-- TODO - choose stereo/mono pokey
	SIGNAL AUDIO_L : std_logic_vector(15 downto 0);
	SIGNAL AUDIO_R : std_logic_vector(15 downto 0);

	-- JOYSTICK
	SIGNAL JOY1_n : std_logic_vector(4 downto 0); -- FRLDU, 0=pressed
	SIGNAL JOY2_n : std_logic_vector(4 downto 0); -- FRLDU, 0=pressed

	-- Pokey keyboard matrix
	-- Standard component available to connect this to PS2
	SIGNAL KEYBOARD_RESPONSE : STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL KEYBOARD_SCAN :  STD_LOGIC_VECTOR(5 DOWNTO 0);

	-- SIO
	SIGNAL SIO_COMMAND : std_logic;
	SIGNAL SIO_RXD : std_logic;
	SIGNAL SIO_TXD : std_logic;

	-- PIA
	SIGNAL	CA1_IN :  STD_LOGIC;
	SIGNAL	CB1_IN:  STD_LOGIC;
	SIGNAL	CA2_OUT :  STD_LOGIC;
	SIGNAL	CA2_DIR_OUT:  STD_LOGIC;
	SIGNAL	CB2_OUT :  STD_LOGIC;
	SIGNAL	CB2_DIR_OUT:  STD_LOGIC;
	SIGNAL	CA2_IN:  STD_LOGIC;
	SIGNAL	CB2_IN:  STD_LOGIC;
	SIGNAL	PORTA_IN :  STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL	PORTA_OUT :  STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL	PORTA_DIR_OUT :  STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL	PORTB_IN :  STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL	PORTB_OUT :  STD_LOGIC_VECTOR(7 DOWNTO 0);
	--SIGNAL	PORTB_DIR_OUT :  STD_LOGIC_VECTOR(7 DOWNTO 0);
	
	-- GTIA
	signal GTIA_TRIG : std_logic_vector(3 downto 0);
	
	-- ANTIC
	signal ANTIC_LIGHTPEN : std_logic;
	
	-- CARTRIDGE ACCESS
	SIGNAL	CART_RD4 :  STD_LOGIC;
	SIGNAL	CART_RD5 :  STD_LOGIC;
	
	-- PBI
	SIGNAL PBI_WRITE_DATA : std_logic_vector(31 downto 0);
	
	-- INTERNAL ROM/RAM
	SIGNAL	RAM_ADDR :  STD_LOGIC_VECTOR(18 DOWNTO 0);
	SIGNAL	RAM_DO :  STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL	RAM_REQUEST :  STD_LOGIC;
	SIGNAL	RAM_REQUEST_COMPLETE :  STD_LOGIC;
	SIGNAL	RAM_WRITE_ENABLE :  STD_LOGIC;
	
	SIGNAL	ROM_ADDR :  STD_LOGIC_VECTOR(21 DOWNTO 0);
	SIGNAL	ROM_DO :  STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL	ROM_REQUEST :  STD_LOGIC;
	SIGNAL	ROM_REQUEST_COMPLETE :  STD_LOGIC;
	
	-- CONFIG
	SIGNAL ROM_IN_RAM : STD_LOGIC;

	-- POTS
	SIGNAL POT_RESET : STD_LOGIC;
	SIGNAL POT_IN : STD_LOGIC_VECTOR(7 downto 0);

	SIGNAL CONSOL_OPTION : STD_LOGIC;
	SIGNAL CONSOL_SELECT : STD_LOGIC;
	SIGNAL CONSOL_START: STD_LOGIC;

begin
	p_clk_gen_a : process
	begin
	clk_a <= '1';
	wait for CLK_A_PERIOD/2;
	clk_a <= '0';
	wait for CLK_A_PERIOD - (CLK_A_PERIOD/2 );
	end process;

	reset_n <= '0', '1' after 1000ns;

JOY1_N <= (others=>'1');
JOY2_N <= (others=>'1');
KEYBOARD_RESPONSE <= "11";
CONSOL_OPTION <= '1';
CONSOL_SELECT <= '1';
CONSOL_OPTION <= '1';

-- PIA mapping
CA1_IN <= '1';
CB1_IN <= '1';
CA2_IN <= CA2_OUT when CA2_DIR_OUT='1' else '1';
CB2_IN <= CB2_OUT when CB2_DIR_OUT='1' else '1';
SIO_COMMAND <= CB2_OUT;
PORTA_IN <= ((JOY2_n(3)&JOY2_n(2)&JOY2_n(1)&JOY2_n(0)&JOY1_n(3)&JOY1_n(2)&JOY1_n(1)&JOY1_n(0)) and not (porta_dir_out)) or (porta_dir_out and porta_out);
PORTB_IN <= PORTB_OUT;

-- ANTIC lightpen
ANTIC_LIGHTPEN <= JOY2_n(4) and JOY1_n(4);

-- GTIA triggers
GTIA_TRIG <= "11"&JOY2_n(4)&JOY1_n(4);

-- Cartridge not inserted
CART_RD4 <= '0';
CART_RD5 <= '0';

POT_IN(7 downto 4) <= (others=>'0');

atari800xlinst : entity work.atari800xl
	PORT MAP
	(
		CLK => CLK_A,
		RESET_N => RESET_N,

		VIDEO_VS => VIDEO_VS,
		VIDEO_HS => VIDEO_HS,
		VIDEO_CS => VIDEO_CS,
		COLOUR => VIDEO_COLOUR,
		VIDEO_BLANK => VIDEO_BLANK,
		VIDEO_BURST => VIDEO_BURST,
		VIDEO_START_OF_FIELD => VIDEO_START_OF_FIELD,
		VIDEO_ODD_LINE => VIDEO_ODD_LINE,

		AUDIO_L => AUDIO_L,
		AUDIO_R => AUDIO_R,
		SIO_AUDIO => "00000000",

		CA1_IN => CA1_IN,
		CB1_IN => CB1_IN,
		CA2_IN => CA2_IN,
		CA2_OUT => CA2_OUT,
		CA2_DIR_OUT => CA2_DIR_OUT,
		CB2_IN => CB2_IN,
		CB2_OUT => CB2_OUT,
		CB2_DIR_OUT => CB2_DIR_OUT,
		PORTA_IN => PORTA_IN,
		PORTA_DIR_OUT => PORTA_DIR_OUT,
		PORTA_OUT => PORTA_OUT,
		PORTB_IN => PORTB_IN,
		PORTB_DIR_OUT => open,--PORTB_DIR_OUT,
		PORTB_OUT => PORTB_OUT,

		KEYBOARD_RESPONSE => KEYBOARD_RESPONSE,
		KEYBOARD_SCAN => KEYBOARD_SCAN,

		POT_IN => POT_IN,
		POT_RESET => POT_RESET,
		
		-- PBI
		CART_RD4 => CART_RD4,
		CART_RD5 => CART_RD5,
		CART_S4_n => open,
		CART_S5_N => open,
		CART_CCTL_N => open,

		PBI_MPD_N => '1',
		PBI_REF_N_IN => '1',
		PBI_EXTSEL_N => '1',

		SIO_RXD => SIO_RXD,
		SIO_TXD => SIO_TXD,

		CONSOL_OPTION => CONSOL_OPTION,
		CONSOL_SELECT => CONSOL_SELECT,
		CONSOL_START=> CONSOL_START,
		GTIA_TRIG => GTIA_TRIG,
		
		ANTIC_LIGHTPEN => ANTIC_LIGHTPEN,
		ANTIC_REFRESH => open
	);

end rtl;
