---------------------------------------------------------------------------------
-- lpc speech synthetizer - Dar - Feb 2014
---------------------------------------------------------------------------------
-- Main part of the TMS5110 simulation - algorithm is from MAME source
-- Job here includes parsing the bit stream from PROM data and computes speech 
-- samples
---------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity lpc10_speech_synthetizer is
--generic (
--  Model  : integer := 0
--);
port(
  Clk512kHz   : in std_logic;
  StartSpeak  : in std_logic;
  RomData     : in std_logic;
  RomAdr      : out std_logic_vector(11 downto 0);
  SampleData  : out integer range -512 to 511;
  Speaking    : out std_logic;
  Model       : in std_logic_vector(1 downto 0) -- 0 = default, -- 1 = 5200, --2 = 5220

--Resultats Intermediaires pour les essais
--E_Out       : out integer range -512 to 511;
--P_Out       : out integer range -512 to 511;
--KBus_Out    : out integer range -512 to 511;
--XBus_Out    : out integer range -512 to 511;
--Valeur_Out  : out integer range -512 to 511;
--YNext_Out   : out integer range -512 to 511;
--Ope1_Out    : out integer range -262144 to 262143;
--Ope2_Out    : out integer range -262144 to 262143;
--Ope3_Out    : out integer range -262144 to 262143;
--Ope4_Out    : out integer range -262144 to 262143
);

end lpc10_speech_synthetizer;

architecture struct of lpc10_speech_synthetizer is

signal Cnt_8k      : std_logic_vector(5 downto 0);
signal CntSegment  : std_logic_vector(4 downto 0);
signal CntSample   : std_logic_vector(7 downto 0);
signal RomAdrIn    : std_logic_vector(11 downto 0) := "000000000001";
signal ReadRom     : std_logic;
signal Speak       : std_logic := '0';
signal CodeEnergy  : std_logic_vector(3 downto 0); 
signal CodeRepeat  : std_logic; 
--signal CodePitch   : std_logic_vector(4 downto 0); 
signal CodePitch   : std_logic_vector(5 downto 0); 
signal CodeK1K4    : std_logic_vector(17 downto 0);  -- 5, 5, 4, 4 
signal CodeK5K10   : std_logic_vector(20 downto 0);  -- 4, 4, 4, 3, 3, 3 
signal GetEnergy   : std_logic := '0';
signal GetRepeat   : std_logic := '0';
signal GetPitch    : std_logic := '0'; 
signal GetK1K4     : std_logic := '0';
signal GetK5K10    : std_logic := '0';
signal Silence     : std_logic := '0';
signal LastFrame   : std_logic := '0';
signal NoK5K10     : std_logic := '0';

subtype int10b is integer range   -512 to   511;

type Chirp_ARRAY is array(0 to 51) of int10b;
constant TabChirp_default : Chirp_ARRAY := (
  0,  42, -44,  50, -78,  18,  37, 20,  2, -31, -59,  2,  95, 90,  5,  15,
 38,  -4, -91, -91, -42, -35, -36, -4, 37,  43,  34, 33,  15, -1, -8, -18,
-19, -17,  -9, -10,  -6,   0,   3,  2,  1,   0,   0,  0,   0,  0,  0,   0,
  0,   0,   0,   0);
constant TabChirp_5200 : Chirp_ARRAY := (
  0,   3,  15,  40,  76, 108, 113, 80, 37,  38,  76, 68,  26, 50, 59,  19,
  55, 26,  37,  31,  29,   0,   0,  0,  0,   0,   0,  0,   0,  0,  0,   0,
  0,   0,   0,   0,   0,   0,   0,  0,  0,   0,   0,  0,   0,  0,  0,   0,
  0,   0,   0,   0);
-- CInterp = [ 3, 3, 3, 2, 2, 1, 1, 0, 0];

type Energy_ARRAY is array(0 to 15) of int10b;
constant TabEnergy_default : Energy_ARRAY := (
 0, 0, 1, 1, 2, 3, 5,  7, 10, 15, 21, 30, 43, 61,  86, 0 );
constant TabEnergy_5200 : Energy_ARRAY := (
 0, 1, 2, 3, 4, 6, 8, 11, 16, 23, 33, 47, 63, 85, 114, 0 );
 
--% value #20 may be 95; value #29 may be 140
--type Pitch_ARRAY is array(0 to 31) of int10b;
type Pitch_ARRAY is array(0 to 63) of int10b;
constant TabPitch_default : Pitch_ARRAY := (
  0,  41,  43,  45,  47,  49,  51,  53,  55,  58,  60,  63,  66,  70,  73,  76,
 79,  83,  87,  90,  94,  99, 103, 107, 112, 118, 123, 129, 134, 141, 147, 153,-- );
  0,  41,  43,  45,  47,  49,  51,  53,  55,  58,  60,  63,  66,  70,  73,  76,
 79,  83,  87,  90,  94,  99, 103, 107, 112, 118, 123, 129, 134, 141, 147, 153 );
constant TabPitch_5200 : Pitch_ARRAY := (
  0,  14,  15,  16,  17,  18,  19,  20,  21,  22,  23,  24,  25,  26,  27,  28,
 29,  30,  31,  32,  34,  36,  38,  40,  41,  43,  45,  48,  49,  51,  54,  55,
 57,  60,  62,  64,  68,  72,  74,  76,  81,  85,  87,  90,  96,  99, 103, 107,
112, 117, 122, 127, 133, 139, 145, 151, 157, 164, 171, 178, 186, 194, 202, 211 );
constant TabPitch_5220 : Pitch_ARRAY := (
  0,  15,  16,  17,  18,  19,  20,  21,  22,  23,  24,  25,  26,  27,  28,  29,
 30,  31,  32,  33,  34,  35,  36,  37,  38,  39,  40,  41,  42,  44,  46,  48,
 50,  52,  53,  56,  58,  60,  62,  65,  68,  70,  72,  76,  78,  80,  84,  86,
 91,  94,  98, 101, 105, 109, 114, 118, 122, 127, 132, 137, 142, 148, 153, 159 );

type K32x10b_ARRAY is array(0 to 31) of int10b;
type K16x10b_ARRAY is array(0 to 15) of int10b;
type K8x10b_ARRAY  is array(0 to  7) of int10b;

constant TabK1_default  : K32x10b_ARRAY := (
 -501, -497, -493, -488, -480, -471, -460, -446, -427, -405, -378, -344, -305, -259, -206, -148,
  -86,  -21,   45,  110,  171,  227,  277,  320,  357,  388,  413,  434,  451,  464,  474,  482 );
constant TabK1_5200  : K32x10b_ARRAY := (
 -501, -498, -495, -490, -485, -478, -469, -459, -446, -431, -412, -389, -362, -331, -295, -253,
 -207, -156, -102,  -45,   13,   70,  126,  179,  228,  272,  311,  345,  374,  399,  420,  437 );
constant TabK1_5220  : K32x10b_ARRAY := (
 -501, -498, -497, -495, -493, -491, -488, -482, -478, -474, -469, -464, -459, -452, -445, -437,
 -412, -380, -339, -288, -227, -158,  -81,   -1,	80,  157,  226,  287,  337,  379,  411,  436 );
  
constant TabK2_default  : K32x10b_ARRAY := (
 -349, -328, -305, -280, -252, -223, -192, -158, -124,  -88,  -51,  -14,  23,    60,   97,  133,
  167,  199,  230,  259,  286,  310,  333,  354,  372,  389,  404,  417,  429,  439,  449,  490 );
constant TabK2_5200  : K32x10b_ARRAY := (
 -376, -357, -335, -312, -286, -258, -227, -195, -161, -124,  -87,  -49,  -10,   29,   68,  106,
  143,  178,  212,  243,  272,  299,  324,  346,  366,  384,  400,  414,  427,  438,  448,  506 );
constant TabK2_5220  : K32x10b_ARRAY := (
 -328, -303, -274, -244, -211, -175, -138,  -99,  -59,  -18,   24,   64,  105,  143,  180,  215,
  248,  278,  306,  331,  354,  374,  392,  408,  422,  435,  445,  455,  463,  470,  476,  506 );

constant TabK3_default  : K16x10b_ARRAY := (
 -397, -365, -327, -282, -229, -170, -104, -36,  35,  104,  169,  228,  281,  326, 364, 396 );
constant TabK3_5200  : K16x10b_ARRAY := (
 -407, -381, -349, -311, -268, -218, -162,-102, -39,   25,   89,  149,  206,  257, 302, 341 );
constant TabK3_5220  : K16x10b_ARRAY := (
 -441, -387, -333, -279, -225, -171, -117,  -63, -9,   45,   98,  152,  206,  260, 314, 368 );

constant TabK4_default  : K16x10b_ARRAY := (
 -373, -334, -293, -245, -191, -131,  -67,  -1,  64,  128,  188,  243,  291,  332, 367, 397 );
constant TabK4_5200  : K16x10b_ARRAY := (
 -290, -252, -209, -163, -114,  -62,   -9,  44,  97,  147,  194,  238,  278,  313, 344, 371 );
constant TabK4_5220  : K16x10b_ARRAY := (
 -328, -273, -217, -161, -106,  -50,    5,  61, 116,  172,  228,  283,  339,  394, 450, 506 );

constant TabK5_default  : K16x10b_ARRAY := (
 -319, -286, -250, -211, -168, -122,  -74, -25,  24,   73,  121,  167,  210,  249, 285, 319 );
constant TabK5_5200  : K16x10b_ARRAY := (
 -318, -283, -245, -202, -156, -107,  -56,  -3,  49,  101,  150,  196,  239,  278, 313, 344 );
constant TabK5_5220  : K16x10b_ARRAY := (
 -328, -282, -235, -189, -142,  -96,  -50,  -3,  43,   90,  136,  182,  229,  275, 322, 368 );

constant TabK6_default  : K16x10b_ARRAY := (
 -290, -252, -209, -163, -114,  -62,   -9,  44,  97,  147,  194,  239,  278,  313, 344, 371 );
constant TabK6_5200  : K16x10b_ARRAY := (
 -193, -152, -109,  -65,  -20,   26,   71, 115, 158,  198,  235,  270,  301,  330, 355, 377 );
constant TabK6_5220  : K16x10b_ARRAY := (
 -256, -212, -168, -123,  -79,  -35,   10,  54,  98,  143,  187,  232,  276,  320, 365, 409 );

constant TabK7_default  : K16x10b_ARRAY := (
 -291, -256, -216, -174, -128,  -80, -31,  19,  69,  117,  163,  206,  246,  283, 316, 345 );
constant TabK7_5200  : K16x10b_ARRAY := (
 -254, -218, -180, -140,  -97,  -53,  -8,  36,  81,  124,  165,  204,  240,  274, 304, 332 );
constant TabK7_5220  : K16x10b_ARRAY := (
 -308, -260, -212, -164, -117,  -69, -21,  27,  75,  122,  170,  218,  266,  314, 361, 409 );

constant TabK8_default  : K8x10b_ARRAY  := (
 -219, -133,  -38,   59,  152,  235,  305, 361 );
constant TabK8_5200  : K8x10b_ARRAY  := (
 -205, -112,  -10,   92,  187,  269,  336, 387 );
constant TabK8_5220  : K8x10b_ARRAY  := (
 -256, -161,  -66,   29,  124,  219,  314, 409 );

constant TabK9_default  : K8x10b_ARRAY  := (
 -225, -157,  -82,   -3,   76,  151,  220, 280 );
constant TabK9_5200  : K8x10b_ARRAY  := (
 -249, -183, -110,  -32,   48,  126,  198, 261 );
constant TabK9_5220  : K8x10b_ARRAY  := (
 -256, -176,  -96,  -15,   65,  146,  226, 307 );

constant TabK10_default : K8x10b_ARRAY  := (
 -179, -122,  -61,    1,   63,  123,  179, 231 );
constant TabK10_5200 : K8x10b_ARRAY  := (
 -190, -133,  -73,  -10,   53,  115,  173, 227 );
constant TabK10_5220 : K8x10b_ARRAY  := (
 -205, -132,  -59,   14,   87,  160,  234, 307 );

signal ET   : int10b := 0;
signal PT   : int10b := 0;
signal K1T  : int10b := 0;
signal K2T  : int10b := 0;
signal K3T  : int10b := 0;
signal K4T  : int10b := 0;
signal K5T  : int10b := 0;
signal K6T  : int10b := 0;
signal K7T  : int10b := 0;
signal K8T  : int10b := 0;
signal K9T  : int10b := 0;
signal K10T : int10b := 0;

signal EC   : int10b := 0;
signal PC   : int10b := 0;
signal K1C  : int10b := 0;
signal K2C  : int10b := 0;
signal K3C  : int10b := 0;
signal K4C  : int10b := 0;
signal K5C  : int10b := 0;
signal K6C  : int10b := 0;
signal K7C  : int10b := 0;
signal K8C  : int10b := 0;
signal K9C  : int10b := 0;
signal K10C : int10b := 0;

signal X1C  : int10b := 0;
signal X2C  : int10b := 0;
signal X3C  : int10b := 0;
signal X4C  : int10b := 0;
signal X5C  : int10b := 0;
signal X6C  : int10b := 0;
signal X7C  : int10b := 0;
signal X8C  : int10b := 0;
signal X9C  : int10b := 0;
signal X10C : int10b := 0;

signal Valeur : int10b := 0;
signal KBus   : int10b := 0;
signal XBus   : int10b := 0;
signal YNext  : int10b := 0;

signal Operation1 : integer range -262144 to 262143 := 0;
signal Operation2 : integer range -262144 to 262143 := 0;
signal Operation3 : integer range -262144 to 262143 := 0;
signal Operation4 : integer range -262144 to 262143 := 0;

signal GPA       : std_logic_vector(12 downto 0) := "0000001101001";
signal NoiseOn   : std_logic := '1';
signal PitchCnt  : integer range 0 to 255 :=0; 

signal TabChirp : Chirp_ARRAY; 
signal TabEnergy : Energy_ARRAY; 
signal TabPitch : Pitch_ARRAY; 
signal TabK1  : K32x10b_ARRAY; 
signal TabK2  : K32x10b_ARRAY; 
signal TabK3  : K16x10b_ARRAY; 
signal TabK4  : K16x10b_ARRAY; 
signal TabK5  : K16x10b_ARRAY; 
signal TabK6  : K16x10b_ARRAY; 
signal TabK7  : K16x10b_ARRAY; 
signal TabK8  : K8x10b_ARRAY;  
signal TabK9  : K8x10b_ARRAY;  
signal TabK10 : K8x10b_ARRAY;  

begin

TabChirp <= TabChirp_default when Model = "00" else TabChirp_5200;
TabEnergy <=  TabEnergy_default when Model = "00" else TabEnergy_5200;
TabPitch <= TabPitch_default when Model = "00" else TabPitch_5200 when Model = "01" else TabPitch_5220;
TabK1  <= TabK1_default when Model = "00" else TabK1_5200 when Model = "01" else TabK1_5220;
TabK2  <= TabK2_default when Model = "00" else TabK2_5200 when Model = "01" else TabK2_5220;
TabK3  <= TabK3_default when Model = "00" else TabK3_5200 when Model = "01" else TabK3_5220;
TabK4  <= TabK4_default when Model = "00" else TabK4_5200 when Model = "01" else TabK4_5220;
TabK5  <= TabK5_default when Model = "00" else TabK5_5200 when Model = "01" else TabK5_5220;
TabK6  <= TabK6_default when Model = "00" else TabK6_5200 when Model = "01" else TabK6_5220;
TabK7  <= TabK7_default when Model = "00" else TabK7_5200 when Model = "01" else TabK7_5220;
TabK8  <= TabK8_default when Model = "00" else TabK8_5200 when Model = "01" else TabK8_5220;
TabK9  <= TabK9_default when Model = "00" else TabK9_5200 when Model = "01" else TabK9_5220;
TabK10 <= TabK10_default when Model= "00" else TabK10_5200 when Model= "01" else TabK10_5220;

--E_Out      <= EC;
--P_Out      <= PC;
--KBus_Out   <= KBus;
--XBus_Out   <= XBus;
--Valeur_Out <= Valeur;
--Ynext_Out  <= YNext;
--Ope1_Out   <= Operation1;
--Ope2_Out   <= Operation2;
--Ope3_Out   <= Operation3;
--Ope4_Out   <= Operation4;

RomAdr <= RomAdrIn;

GetEnergy <= '1' when ( (CntSample = "00000000") and (Cnt_8k >= "000000") and  (Cnt_8k < "000100")) else '0';

Silence   <= '1' when (CodeEnergy =  "0000") else '0';
LastFrame <= '1' when (CodeEnergy =  "1111") else '0';
--NoK5K10   <= '1' when (CodePitch  = "00000") else '0';
NoK5K10   <= '1' when (CodePitch  ="000000") else '0';

GetRepeat <= '1' when ((CntSample = "00000000") and (Cnt_8k >= "000100") and  (Cnt_8k < "000101")) and ((Silence = '0') and (LastFrame = '0')) else '0';
--GetPitch  <= '1' when ((CntSample = "00000000") and (Cnt_8k >= "000101") and  (Cnt_8k < "001010")) and ((Silence = '0') and (LastFrame = '0')) else '0';
GetPitch  <= '1' when ((((Model  = "00") and (CntSample = "00000000") and (Cnt_8k >= "000101") and  (Cnt_8k < "001010"))
                     or ((Model /= "00") and (CntSample = "00000000") and (Cnt_8k >= "000101") and  (Cnt_8k < "001011"))) and ((Silence = '0') and (LastFrame = '0'))) else '0';
GetK1K4   <= '1' when ((CntSample = "00000000") and (Cnt_8k >= "001011") and  (Cnt_8k < "011101")) and ((Silence = '0') and (LastFrame = '0')  and (CodeRepeat = '0'))  else '0';
GetK5K10  <= '1' when ((CntSample = "00000000") and (Cnt_8k >= "011110") and  (Cnt_8k < "110011")) and ((Silence = '0') and (LastFrame = '0')  and (CodeRepeat = '0') and (NoK5K10 = '0')) else '0';

ReadRom   <= '1' when  (GetEnergy = '1') or (GetRepeat = '1') or(GetPitch = '1') or (GetK1K4 = '1') or (GetK5K10 = '1') else '0';

Operation1 <=  KBUS  *  XBus;
Operation2 <=  YNext - (Operation1/512);
Operation3 <=  KBUS  *  Operation2;
Operation4 <=  XBus  + (Operation3/512);

with Cnt_8k select
  KBus <=
    K10C     when "000010",
    K9C      when "000011",
    K8C      when "000100",
    K7C      when "000101",
    K6C      when "000110",
    K5C      when "000111",
    K4C      when "001000",
    K3C      when "001001",
    K2C      when "001010",
    K1C      when "001011",
    0        when others;
    
with Cnt_8k select
  XBus <=
    X10C     when "000010",
    X9C      when "000011",
    X8C      when "000100",
    X7C      when "000101",
    X6C      when "000110",
    X5C      when "000111",
    X4C      when "001000",
    X3C      when "001001",
    X2C      when "001010",
    X1C      when "001011",
    0        when others;

process(Clk512kHz)
begin
  if rising_edge(Clk512kHz) then
  
    if (Speak = '1') and (StartSpeak = '1') then
      -- division par 64 : 512kHz -> 8kHz
      if Cnt_8k = "111111" then
        Cnt_8k <= "000000";
      else
        Cnt_8k <= std_logic_vector(unsigned(Cnt_8k) + 1);
      end if;

      if Cnt_8k = "111111" then
       -- 25 echantillons par segment
        if CntSegment = "10111" then
          CntSegment <= "00000";
        else
          CntSegment <= std_logic_vector(unsigned(CntSegment) + 1);
        end if;
  
       -- 200 echantillons par trame 
        if CntSample =   "11000111" then -- "00001000" then  -- pour simulation plus rapide
          CntSample <= "00000000";
        else
          CntSample <= std_logic_vector(unsigned(CntSample) + 1);
        end if;
  
      end if;

      if (GetEnergy = '1')  then  CodeEnergy <= CodeEnergy(2 downto 0) & RomData; end if;
      if (GetRepeat = '1')  then  CodeRepeat <= RomData;                          end if;
--      if (GetPitch  = '1')  then  CodePitch  <= CodePitch(3 downto 0)  & RomData; end if;
      if (GetPitch  = '1' and (Model  = "00"))  then  CodePitch  <= '0' & CodePitch(3 downto 0)  & RomData; end if;
      if (GetPitch  = '1' and (Model /= "00"))  then  CodePitch  <= CodePitch(4 downto 0)  & RomData; end if;
      if (GetK1K4   = '1')  then  CodeK1K4   <= CodeK1K4(16 downto 0)  & RomData; end if;
      if (GetK5K10  = '1')  then  CodeK5K10  <= CodeK5K10(19 downto 0) & RomData; end if;

      if ReadRom = '1' then  RomAdrIn <= std_logic_vector(unsigned( RomAdrIn) + 1); end if;

      if (CntSample = "11000111") and (Cnt_8k = "111111") and (LastFrame = '1') then 
        Speak <= '0';
        Speaking <= '0';
      else 
        Speaking <= '1';
      end if; 

    else
      Cnt_8k     <= "000000";
      CntSegment <= "00000";
      CntSample  <= "00000000";
      RomAdrIn   <= "000000000001";
      NoiseOn    <= '1';
      if StartSpeak = '0' then Speak <= '1'; end if;
    end if;
 
    if Cnt_8k = "111110" then
      ET  <= TabEnergy(to_integer(unsigned(CodeEnergy)));

      if ((Silence = '1') or (LastFrame = '1')) then
        PT  <= 0;
      else
        PT   <= TabPitch(to_integer(unsigned(CodePitch)));
      end if;

      if ((Silence = '1') or (LastFrame = '1')) then
        K1T <= 0; K2T <= 0; K3T <= 0; K4T <= 0;
      else
        K1T  <= TabK1(to_integer(unsigned(CodeK1K4(  17 downto 13))));
        K2T  <= TabK2(to_integer(unsigned(CodeK1K4(  12 downto  8))));
        K3T  <= TabK3(to_integer(unsigned(CodeK1K4(   7 downto  4))));
        K4T  <= TabK4(to_integer(unsigned(CodeK1K4(   3 downto  0))));
      end if;

      if ((Silence = '1') or (LastFrame = '1') or (NoK5K10 = '1')) then
        K5T <= 0; K6T <= 0; K7T <= 0; K8T <= 0; K9T <= 0; K10T <= 0;
      else
        K5T  <= TabK5(to_integer(unsigned(CodeK5K10( 20 downto 17))));
        K6T  <= TabK6(to_integer(unsigned(CodeK5K10( 16 downto 13))));
        K7T  <= TabK7(to_integer(unsigned(CodeK5K10( 12 downto  9))));
        K8T  <= TabK8(to_integer(unsigned(CodeK5K10(  8 downto  6))));
        K9T  <= TabK9(to_integer(unsigned(CodeK5K10(  5 downto  3))));
        K10T <= TabK10(to_integer(unsigned(CodeK5K10( 2 downto  0))));	
      end if;

    end if;

    if ((CntSegment = "00000") and (Cnt_8k = "111111"))then
      EC   <= ET;
      PC   <= PT;
      K1C  <= K1T;
      K2C  <= K2T;
      K3C  <= K3T;
      K4C  <= K4T;
      K5C  <= K5T;
      K6C  <= K6T;
      K7C  <= K7T;
      K8C  <= K8T;
      K9C  <= K9T;
      K10C <= K10T;
      if (PC = 0) then NoiseOn <= '1'; else NoiseOn <= '0'; end if;
    end if;
 
    if (Cnt_8k = "000000") then
      if  EC = 0 then              
        Valeur <= 0; 
      elsif NoiseOn = '1' then
        if GPA(0) = '1' then
          Valeur <= -64;
        else
          Valeur <=  64;
        end if;
      else
        if (PitchCnt > 50) then 
          Valeur <= TabChirp(50);
        else
          Valeur <= TabChirp(PitchCnt);
        end if;
      end if; 
 
      if PC = 0 then 
        PitchCnt <= 0;
      else
        if PitchCnt < PC then 
          PitchCnt <= PitchCnt + 1;
        else
          PitchCnt <= 0;
        end if;
      end if;

    end if;
 
    if Cnt_8k < "010100" then
      if (GPA(12)='1') xor ( (GPA(10)='1') xor ( (GPA(9)='1') xor (GPA(0)='1'))) then 
        GPA <=  '1' & GPA(12 downto 1);
      else
        GPA <=  '0' & GPA(12 downto 1);
      end if;
    end if;

    case Cnt_8k is 
      when "000001" => YNext <=  (Valeur*EC)/64;
      when "000010" | "000011" | "000100" | "000101" |  "000110" | "000111" | "001000" | "001001" | "001010" |  "001011" => YNext <= Operation2;
      when others => NULL;
    end case;

    case Cnt_8k is
      when "000011" => X10C <= Operation4;
      when "000100" => X9C  <= Operation4;
      when "000101" => X8C  <= Operation4;
      when "000110" => X7C  <= Operation4;
      when "000111" => X6C  <= Operation4;
      when "001000" => X5C  <= Operation4;
      when "001001" => X4C  <= Operation4;
      when "001010" => X3C  <= Operation4;
      when "001011" => X2C  <= Operation4;
      when "001100" => X1C  <= Operation2; 
      when others => NULL;
    end case;

    if Cnt_8k = "001111" then
      --if    X1C >  255  then SampleData <=  255; 
      --elsif X1C < -256  then SampleData <= -256; 
      --else                   SampleData <=  X1C; end if;
      SampleData <= X1C;
    end if;

  end if;
end process;

end architecture;
