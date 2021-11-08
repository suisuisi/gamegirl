LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
USE ieee.std_logic_unsigned.all;

ENTITY internalromram_simple IS
  PORT(
    clock   : IN     STD_LOGIC;                             --system clock
    reset_n : IN     STD_LOGIC;                             --asynchronous reset

	ROM_ADDR : in STD_LOGIC_VECTOR(21 downto 0);
	ROM_REQUEST_COMPLETE : out STD_LOGIC;
	ROM_REQUEST : in std_logic;
	OS_DATA : out std_logic_vector(7 downto 0);
	BASIC_DATA : out std_logic_vector(7 downto 0);
	
	RAM_ADDR : in STD_LOGIC_VECTOR(18 downto 0);
	RAM_WR_ENABLE : in std_logic;
	RAM_DATA_IN : in STD_LOGIC_VECTOR(7 downto 0);
	RAM_REQUEST_COMPLETE : out STD_LOGIC;
	RAM_REQUEST : in std_logic;
	RAM_DATA : out std_logic_vector(7 downto 0)
	);
END internalromram_simple;

architecture vhdl of internalromram_simple is
	signal rom_request_reg : std_logic;
	signal ram_request_reg : std_logic;
	
	signal ramwe_temp : std_logic;
begin
	process(clock,reset_n)
	begin
		if (reset_n ='0') then
			rom_request_reg <= '0';
			ram_request_reg <= '0';
		elsif (clock'event and clock='1') then
			rom_request_reg <= rom_request;
			ram_request_reg <= ram_request;
		end if;
	end process;

	rom16a : entity work.os16
	PORT MAP(clock => clock,
			 address => rom_addr(13 downto 0),
			 q => OS_DATA
			 );

	basic1 : entity work.basic
	PORT MAP(clock => clock,
			 address => rom_addr(12 downto 0),
			 q => BASIC_data
			 );			 

	rom_request_complete <= rom_request_reg;
	
	ramwe_temp <= RAM_WR_ENABLE and ram_request;
	ramint1 : entity work.generic_ram_infer
        generic map
        (
                ADDRESS_WIDTH => 19,
                SPACE => 65536,
                DATA_WIDTH =>8
        )
	PORT MAP(clock => clock,
			reset_n => reset_n,
			 address => ram_addr,
			 data => ram_data_in(7 downto 0),
			 we => ramwe_temp,
			 q => ram_data
			 );	
	ram_request_complete <= ram_request_reg;
        
end vhdl;
