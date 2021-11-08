---------------------------------------------------------------------------
-- (c) 2020 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_MISC.all;

ENTITY I2C_regs IS
  generic (
    SLAVE_ADDR : std_logic_vector(6 downto 0);
	 regs : integer := 1; -- up to 16
	 bits : integer := 1
  );
  port (
    scl_in           : in std_logic;
    sda_in           : in std_logic;
	 scl_wen          : out std_logic;
	 sda_wen          : out std_logic;
	 
    clk              : in    std_logic;
    rst              : in    std_logic;
	 
    -- User interface	 	
    reg : out std_logic_vector((regs*bits)-1 downto 0)
);
END I2C_regs;

ARCHITECTURE vhdl OF I2C_regs IS	
	signal i2c_write : std_logic;
	signal i2c_read : std_logic;
	signal i2c_write_data : std_logic_vector(7 downto 0);
	signal i2c_read_data : std_logic_vector(7 downto 0);

	signal i2c_addr_next : std_logic_vector(3 downto 0);
	signal i2c_addr_reg : std_logic_vector(3 downto 0);

	signal i2c_state_next : std_logic_vector(2 downto 0);
	signal i2c_state_reg : std_logic_vector(2 downto 0);
	constant I2C_INIT : std_logic_vector(2 downto 0) := "000";
	constant I2C_READ1 : std_logic_vector(2 downto 0) := "001";
	constant I2C_READ2 : std_logic_vector(2 downto 0) := "010";
	constant I2C_WRITE1 : std_logic_vector(2 downto 0) := "011";
	constant I2C_WRITE2 : std_logic_vector(2 downto 0) := "100";
	
	signal reg_next : std_logic_vector((regs*bits)-1 downto 0);
	signal reg_reg : std_logic_vector((regs*bits)-1 downto 0);
	
	function MIN(LEFT, RIGHT: INTEGER) return INTEGER is
	begin
	  if LEFT < RIGHT then return LEFT;
	  else return RIGHT;
		 end if;
	  end;	
	  
	function IX(r,c : natural) return natural is
	begin
     return (r*bits + c);
	end;	  
BEGIN

	process(clk,rst)
	begin
		if (rst='1') then
			reg_reg <= (others=>'0');
			
			-- i2c
			i2c_state_reg <= I2C_INIT;
			i2c_addr_reg <= (others=>'0');
		elsif (clk'event and clk='1') then
			reg_reg <= reg_next;

			-- i2c
			i2c_state_reg <= i2c_state_next;
			i2c_addr_reg <= i2c_addr_next;
		end if;
	end process;

	i2cslave : entity work.I2C_slave
	generic map (
		SLAVE_ADDR => SLAVE_ADDR
	)
	port map (
		scl_in => scl_in,
		sda_in => sda_in,		
		scl_wen => scl_wen,
		sda_wen => sda_wen,				
		
		clk => clk,
		rst => rst,

		read_req => i2c_read,
		data_to_master => i2c_read_data,
		data_valid => i2c_write,
		data_from_master => i2c_write_data
	);

	process(
		reg_reg,
		i2c_addr_reg,
		i2c_state_reg,
		i2c_read,
		i2c_write,
		i2c_write_data
	)
		variable low_max : integer;
		variable i2c_addr_int : integer;
	begin
		low_max := min(7,bits-1);
		i2c_addr_int := to_integer(unsigned(i2c_addr_reg));
	
		reg_next <= reg_reg;

		i2c_addr_next <= i2c_addr_reg;
		i2c_state_next <= i2c_state_reg;

		i2c_read_data <= (others=>'0');

		case(i2c_state_reg) is
		when I2C_INIT =>
			if (i2c_write='1' and i2c_write_data(7 downto 5)="111") then -- F= write, E= read, bottom 4 bits = reg
				i2c_addr_next <= i2c_write_data(3 downto 0);
				if (i2c_write_data(4)='1') then
					i2c_state_next <= I2C_WRITE1;
				else
					i2c_state_next <= I2C_READ1;
				end if;
			end if;
		when I2C_WRITE1 =>
			if (i2c_write='1') then
				for i in 0 to regs-1 loop
					if (i2c_addr_int=i) then			
						reg_next(IX(i,low_max) downto IX(i,0)) <= i2c_write_data(low_max downto 0);
					end if;
				end loop;
				i2c_state_next <= I2C_WRITE2;
			end if;
		when I2C_WRITE2 =>
			if (i2c_write='1') then
				for i in 0 to regs-1 loop
					if (i2c_addr_int=i) then					
						reg_next(ix(i,bits-1) downto ix(i, 8)) <= i2c_write_data(bits-9 downto 0);
					end if;
				end loop;
				i2c_state_next <= I2C_INIT;
			end if;
		when I2C_READ1 =>
			for i in 0 to regs-1 loop
				if (i2c_addr_int=i) then
					i2c_read_data(low_max downto 0) <= reg_reg(ix(i,low_max) downto ix(i,0));
				end if;
			end loop;
			if (i2c_read='1') then
				i2c_state_next <= I2C_READ2;
			end if;
		when I2C_READ2 =>			
			for i in 0 to regs-1 loop
				if (i2c_addr_int=i) then
					i2c_read_data(bits-9 downto 0) <= reg_reg(ix(i,bits-1) downto ix(i,8));
				end if;
			end loop;			
			
			if (i2c_read='1') then
				i2c_state_next <= I2C_INIT;
			end if;
		when others =>
			i2c_state_next <= I2C_INIT;
		end case;
	end process;
	
	reg <= reg_reg;
	
end vhdl;
		
		