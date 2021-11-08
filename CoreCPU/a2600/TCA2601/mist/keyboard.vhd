library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity ps2Keyboard is
port
(
    clk       	: in     std_logic;
    reset     	: in     std_logic;

		-- inputs from PS/2 port
    ps2_clk  		: in     std_logic;                            
    ps2_data 		: in     std_logic;                            

    -- user outputs
		scancode		: out    std_logic_vector(7 downto 0)
);
end ps2Keyboard;

architecture SYN of ps2Keyboard is

  component ps2kbd                                          
    port
    (
      clk       : in  std_logic;                            
      rst_n     : in  std_logic;                            
      tick1us   : in  std_logic;
      ps2_clk   : in  std_logic;                            
      ps2_data  : in  std_logic;                            

      reset     : out std_logic;                            
      keydown   : out std_logic;                            
      keyup     : out std_logic;                            
      scancode  : out std_logic_vector(7 downto 0)
    );
  end component;

  signal rst_n			: std_logic;

  -- 1us tick for PS/2 interface
  signal tick1us		: std_logic;

  signal ps2_reset      : std_logic;
  signal ps2_press      : std_logic;
  signal ps2_release    : std_logic;
  signal ps2_scancode   : std_logic_vector(7 downto 0);

begin

	rst_n <= not reset;
	
	-- produce a 1us tick from the 28MHz ref clock
  process (clk, reset)
		variable count : integer range 0 to 27;
	begin
	  if reset = '1' then
			tick1us <= '0';
			count := 0;
	  elsif rising_edge (clk) then
			if count = 27 then
		  	tick1us <= '1';
		  	count := 0;
			else
		  	tick1us <= '0';
		  	count := count + 1;
			end if;
	  end if;
	end process;
	
  latchInputs: process (clk, rst_n)
  begin
    -- note: all inputs are active HIGH

    if rst_n = '0' then
       scancode <= (others => '0');
    elsif rising_edge (clk) then
      if ps2_press = '1' then
         scancode <= ps2_scancode;
      elsif ps2_release = '1' then
         scancode <= (others => '0');
      end if; -- ps2_press or release
      if (ps2_reset = '1') then
         scancode <= (others => '0');
      end if;
    end if; -- rising_edge (clk)
  end process latchInputs;

  ps2kbd_inst : ps2kbd                                        
    port map
    (
      clk      	=> clk,                                     
      rst_n    	=> rst_n,
      tick1us  	=> tick1us,
      ps2_clk  	=> ps2_clk,
      ps2_data 	=> ps2_data,

      reset    	=> ps2_reset,
      keydown 	=> ps2_press,
      keyup 	  => ps2_release,
      scancode 	=> ps2_scancode
    );

end SYN;
