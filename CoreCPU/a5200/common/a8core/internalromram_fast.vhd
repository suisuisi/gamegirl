LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
USE ieee.std_logic_unsigned.all;

------
-- CLK        1100110011001100110011
-- CLK2X      1010101010101010101010
-- readValid  0011001100110011001100 (data is valid here)     
-- writeValid 0011001100110011001100 (only allow write to happen here!)
--
-- ts         000011110000111100001111
-- tf         0000001111000011110000
-- out        0000110011001100110011

ENTITY internalromram_fast IS
	GENERIC
	(
		internal_rom : integer := 1;  
		internal_ram : integer := 16384 
	);
  PORT(
    clock2x   : IN     STD_LOGIC;                           --system clock2x 2x faster
    clock1x   : IN     STD_LOGIC;                             --system clock2x
    reset_n : IN     STD_LOGIC;                             --asynchronous reset

	ROM_ADDR : in STD_LOGIC_VECTOR(21 downto 0);
	ROM_REQUEST_COMPLETE : out STD_LOGIC;
	ROM_REQUEST : in std_logic;
	ROM_DATA : out std_logic_vector(7 downto 0);
	
	RAM_ADDR : in STD_LOGIC_VECTOR(18 downto 0);
	RAM_WR_ENABLE : in std_logic;
	RAM_DATA_IN : in STD_LOGIC_VECTOR(7 downto 0);
	RAM_REQUEST_COMPLETE : out STD_LOGIC;
	RAM_REQUEST : in std_logic;
	RAM_DATA : out std_logic_vector(7 downto 0)
	);
END internalromram_fast;

architecture vhdl of internalromram_fast is
	signal toggle_fast_next : std_logic;
	signal toggle_fast_reg : std_logic;
	signal toggle_slow_next : std_logic;
	signal toggle_slow_reg : std_logic;

	signal writePossible : std_logic;

	signal ROM16_DATA : std_logic_vector(7 downto 0);
	signal ROM8_DATA : std_logic_vector(7 downto 0);
	signal ROM2_DATA : std_logic_vector(7 downto 0);
	signal BASIC_DATA : std_logic_vector(7 downto 0);	
	
	signal ramwe_temp : std_logic;
begin
	process(clock2x,reset_n)
	begin
		if (reset_n ='0') then
			toggle_fast_reg <= '0';
		elsif (clock2x'event and clock2x='1') then
			toggle_fast_reg <= toggle_fast_next;
		end if;
	end process;
	toggle_fast_next <= toggle_slow_reg;

	process(clock1x,reset_n)
	begin
		if (reset_n ='0') then
			toggle_slow_reg <= '0';
		elsif (clock1x'event and clock1x='1') then
			toggle_slow_reg <= toggle_slow_next;
		end if;
	end process;
	toggle_slow_next <= not(toggle_slow_reg);

	writePossible <= toggle_fast_reg xnor toggle_slow_reg;

gen_internal_5200 : if internal_rom=4 generate
	-- f000 to ffff (4k)
	rom4 : entity work.os_5200
	PORT MAP(clock => clock2x,
			 address => rom_addr(10 downto 0),
			 q => ROM_data
			 );
	rom_request_complete <= rom_request;
	
end generate;

gen_internal_os_b : if internal_rom=3 generate
	-- d800 to dfff (2k)
	rom2 : entity work.os2
	PORT MAP(clock => clock2x,
			 address => rom_addr(10 downto 0),
			 q => ROM2_data
			 );

	-- e000 to ffff (8k)
	rom10 : entity work.os8
	PORT MAP(clock => clock2x,
			 address => rom_addr(12 downto 0),
			 q => ROM8_data
			 );

	process(rom_addr)
	begin
		case rom_addr(13 downto 11) is
		when "011" =>
			ROM_DATA <= ROM2_data;
		when "100"|"101"|"110"|"111" =>
			ROM_DATA <= ROM8_data;
		when others=>
			ROM_DATA <= x"ff";
		end case;
	end process;

	rom_request_complete <= rom_request;
	
end generate;

gen_internal_os_loop : if internal_rom=2 generate
	rom16a : entity work.os16_loop
	PORT MAP(clock => clock2x,
			 address => rom_addr(13 downto 0),
			 q => ROM16_data
			 );

	ROM_DATA <= ROM16_DATA;

	rom_request_complete <= rom_request;
	
end generate;

gen_internal_os : if internal_rom=1 generate
	rom16a : entity work.os16
	PORT MAP(clock => clock2x,
			 address => rom_addr(13 downto 0),
			 q => ROM16_data
			 );

	basic1 : entity work.basic
	PORT MAP(clock => clock2x,
			 address => rom_addr(12 downto 0),
			 q => BASIC_data
			 );			 

	process(rom16_data,basic_data, rom_addr(15 downto 0))
	begin
		ROM_DATA <= ROM16_DATA;
		if (rom_addr(15)='1') then
			ROM_DATA <= BASIC_DATA;
		end if;
	end process;

	rom_request_complete <= rom_request;
	
end generate;

gen_internal_os_nobasic : if internal_rom=5 generate
	rom16a : entity work.os16
	PORT MAP(clock => clock2x,
			 address => rom_addr(13 downto 0),
			 q => ROM16_data
			 );			 

	process(rom16_data,basic_data, rom_addr(15 downto 0))
	begin
		ROM_DATA <= ROM16_DATA;
		if (rom_addr(15)='1') then
			ROM_DATA <= x"FF";
		end if;
	end process;

	rom_request_complete <= rom_request;
	
end generate;


gen_no_internal_os : if internal_rom=0 generate
	ROM16_data <= (others=>'0');

	rom_request_complete <= '0';
end generate;
	
gen_internal_ram: if internal_ram>0 generate
	ramwe_temp <= writePossible and RAM_WR_ENABLE and ram_request;
	ramint1 : entity work.generic_ram_infer
        generic map
        (
                ADDRESS_WIDTH => 19,
                SPACE => internal_ram,
                DATA_WIDTH =>8
        )
	PORT MAP(clock => clock2x,
			 address => ram_addr,
			 data => ram_data_in(7 downto 0),
			 we => ramwe_temp,
			 q => ram_data
			 );	
	ram_request_complete <= ram_request;
end generate;
gen_no_internal_ram : if internal_ram=0 generate
	ram_request_complete <='1';
	ram_data <= (others=>'1');
end generate;
        
end vhdl;
