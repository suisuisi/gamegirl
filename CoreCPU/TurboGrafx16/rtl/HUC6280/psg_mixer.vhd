library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

-- On the falling edge of REQ the mixer updates LDATA and RDATA, and clears the accumulators
-- LEFT_STB and RIGHT_STB must go high for a single cycle to mark incoming data.
-- SAMPLE and ATTENUATION should remain stable until the next _STB pulse.
-- There must be at least one idle cycle between _STB pulses

entity psg_mixer is
	generic (
		O_WIDTH : integer := 24;
		A_WIDTH : integer := 24;
		VOLTAB_FILE: string := "../voltab/voltab_small.mif"
	);
	port (
		CLK 	: in std_logic;
		RESET_N	: in std_logic;

		-- Incoming audio data
		REQ : in std_logic;
		SAMPLE : in std_logic_vector(4 downto 0);
		ATTENUATION : IN std_logic_vector(6 downto 0);
		LEFT_STB : in std_logic;
		RIGHT_STB : in std_logic;

		-- DAC Interface
		
		LDATA		: out std_logic_vector(O_WIDTH-1 downto 0);
		RDATA		: out std_logic_vector(O_WIDTH-1 downto 0)
	);
end psg_mixer;

architecture rtl of psg_mixer is

signal sample_in : signed(5 downto 0);
signal sample_offset : signed(5 downto 0);
signal scale : std_logic_vector(A_WIDTH-1 downto 0);
signal product : signed(A_WIDTH+5 downto 0);

signal l_acc : signed(A_WIDTH+5 downto 0);
signal r_acc : signed(A_WIDTH+5 downto 0);

signal l_pipe : std_logic_vector(3 downto 0);
signal r_pipe : std_logic_vector(3 downto 0);
signal req_pipe : std_logic_vector(4 downto 0);

begin

-- attenuation table

VT : entity work.dpram generic map (8,A_WIDTH/2,VOLTAB_FILE)
port map (
	clock		=> CLK,
	address_a=> '0'&ATTENUATION,
	address_b=> '1'&ATTENUATION,
	q_a		=> scale(A_WIDTH-1 downto A_WIDTH/2),
	q_b		=> scale(A_WIDTH/2-1 downto 0)
);


sample_in(5 downto 1) <= signed(sample);
sample_in(0)<='0';

-- Pipeline control

process(clk, RESET_N) begin
	if RESET_N = '0' then
		LDATA<=(others=>'0');
		RDATA<=(others=>'0');
		l_pipe<=(others=>'0');
		r_pipe<=(others=>'0');
		req_pipe<="10000";
	elsif rising_edge(clk) then
		l_pipe<=l_pipe(2 downto 0)&LEFT_STB;
		r_pipe<=r_pipe(2 downto 0)&RIGHT_STB;
		req_pipe<=req_pipe(3 downto 0)&REQ;

		-- latch incoming data one cycle after strobe
		if l_pipe(0)='1' or r_pipe(0)='1' then
			sample_offset<=sample_in-31;
		end if;

		-- scale shuld be valid by *pipe(1), so product should be valid by *pipe(2)
		product <= sample_offset * signed(scale);

		-- at *pipe(2) add the signal to the appropriate accumulator
		if l_pipe(2)='1' then
			l_acc<=l_acc+signed(product);
		end if;
		
		if r_pipe(2)='1' then
			r_acc<=r_acc+signed(product);
		end if;

		-- Copy accumulators to output if we're done
		if req_pipe(1)='0' then
			LDATA<=std_logic_vector(l_acc(A_WIDTH+4 downto A_WIDTH+5-O_WIDTH));
			RDATA<=std_logic_vector(r_acc(A_WIDTH+4 downto A_WIDTH+5-O_WIDTH));
			l_acc<=(others=>'0');
			r_acc<=(others=>'0');
		end if;

	end if;
end process;

	
end architecture;
