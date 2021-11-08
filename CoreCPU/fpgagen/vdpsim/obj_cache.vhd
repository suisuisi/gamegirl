LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;

ENTITY obj_cache IS
	PORT
	(
		rdaddress		: IN STD_LOGIC_VECTOR (6 DOWNTO 0);
		wraddress		: IN STD_LOGIC_VECTOR (6 DOWNTO 0);
		byteena_a		: IN STD_LOGIC_VECTOR (3 DOWNTO 0) :=  (OTHERS => '1');
		clock		: IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
		wren		: IN STD_LOGIC  := '0';
		q		: OUT STD_LOGIC_VECTOR (31 DOWNTO 0)
	);
END obj_cache;

architecture arch of obj_cache is

type ram_type is array(natural range ((2**7)-1) downto 0) of std_logic_vector(31 downto 0);
shared variable ram : ram_type;

begin

-- Port A
process (clock)
variable old_data : std_logic_vector(31 downto 0);
begin
        if (clock'event and clock = '1') then
                old_data := ram(to_integer(unsigned(wraddress)));
                if wren='1' then
                        if byteena_a(0) = '1' then old_data( 7 downto  0) := data( 7 downto  0); end if;
                        if byteena_a(1) = '1' then old_data(15 downto  8) := data(15 downto  8); end if;
                        if byteena_a(2) = '1' then old_data(23 downto 16) := data(23 downto 16); end if;
                        if byteena_a(3) = '1' then old_data(31 downto 24) := data(31 downto 24); end if;
                        ram(to_integer(unsigned(wraddress))) := old_data;
                end if;
        end if;
end process;

-- Port B
process (clock)
begin
        if (clock'event and clock = '1') then
            q <= ram(to_integer(unsigned(rdaddress)));
        end if;
end process;

end architecture;