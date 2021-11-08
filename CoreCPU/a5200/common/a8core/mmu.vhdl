---------------------------------------------------------------------------
-- (c) 2013 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_MISC.all;


ENTITY mmu IS
GENERIC
(
	system : integer := 0 -- 0=Atari XL,1=Atari 800, 10=Atari5200 (space left for more systems)
);
PORT 
( 
	ADDR : IN STD_LOGIC_VECTOR(15 DOWNTO 11);
	REF_N : IN STD_LOGIC;
	RD4 : IN STD_LOGIC;
	RD5 : IN STD_LOGIC;
	MPD_N : IN STD_LOGIC;
	REN : IN STD_LOGIC; --ROM ON on/off
	BE_N: IN STD_LOGIC;  --BASIC ON on/off
	MAP_N : IN STD_LOGIC; 
	S4_N : OUT STD_LOGIC;
	S5_N : OUT STD_LOGIC;
	BASIC : OUT STD_LOGIC;
	IO : OUT STD_LOGIC;
	OS : OUT STD_LOGIC;
	CI : OUT STD_LOGIC
);

END mmu;

ARCHITECTURE vhdl of mmu is
	signal S4 : std_logic;
	signal S5 : std_logic;
	signal OSEN : std_logic;

	signal BASIC_INT : std_logic;
	signal OS_INT : std_logic;
	signal IO_INT : std_logic;
BEGIN
	
--CHIP MMU800XL GAL16V8 COMPLEX_MODE 
--
--A11 A12 A13 A14 A15 MAP RD4 RD5 REN GND 
--REF S5 BASIC MPD OS CI IO BE S4 VCC 
--
--/S4 = /A13 & /A14 & A15 & RD4 & REF; 
--/S5 = A13 & /A14 & A15 & RD5 & REF; 
--
--/IO = A12 & /A11 & /A13 & A14 & A15 & REF; 
--
--/OS = A13 & A14 & A15 & REN & REF 
--+ /A12 & /A13 & A14 & A15 & REN & REF 
--+ A12 & A11 & /A13 & A14 & A15 & MPD & REN & REF 
--+ A12 & /A11 & /A13 & A14 & /A15 & /MAP & REN & REF; 
--
--/CI = /A13 & /A14 & A15 & RD4 & REF 
--+ A13 & /A14 & A15 & RD5 & REF 
--+ A13 & /BE & /A14 & A15 & /RD5 & REF 
--+ /OS 
--+ A12 & /A11 & /A13 & A14 & A15 & REF 
--+ /REF; 
--
--/BASIC = A13 & /BE & /A14 & A15 & /RD5 & REF;

S4 <= not(ADDR(13)) and NOT(ADDR(14)) and ADDR(15) and RD4 and REF_N;                                        --100X (8000-9fff)
S5 <= ADDR(13) and NOT(ADDR(14)) and ADDR(15) and RD5 and REF_N;                                             --101x (A000-Bfff)
IO_INT <= ADDR(12) and NOT(ADDR(11)) and NOT(ADDR(13)) and ADDR(14) and ADDR(15) and REF_N;                      --11010 (D000-D7ff)

OSEN <= REN and REF_N;
OS_INT <=  (ADDR(13) and ADDR(14) and ADDR(15) and OSEN)                                                         --111x (E000-Ffff)
    or (not(ADDR(12)) and not(ADDR(13)) and ADDR(14) and ADDR(15) and OSEN)                                  --1100 (C000-Cfff)
    or (ADDR(12) and ADDR(11) and not(ADDR(13)) and ADDR(14) and ADDR(15) and MPD_N and OSEN)                --11011(D800-Dfff)
    or (ADDR(12) and NOT(ADDR(11)) and not(ADDR(13)) and ADDR(14) and NOT(ADDR(15)) and NOT(MAP_N) and OSEN);  --01010(5000-5fff) self test

CI <= S4
   or S5
   or BASIC_INT
   or OS_INT
   or IO_INT
   or not(REF_N);                                                                                                 --Refresh cycle

BASIC_INT <= ADDR(13) and not(BE_N) and not(ADDR(14)) and ADDR(15) and NOT(RD5) and REF_N;                       --101x (A000-Bfff) when no cart and basic on

S4_N <= not(S4);
S5_N <= not(S5);

BASIC <= BASIC_INT;
OS <= OS_INT;
IO <= IO_INT;

END vhdl;

