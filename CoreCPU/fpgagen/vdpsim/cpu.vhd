library ieee; use ieee.std_logic_1164.all; 

package cpu is
  procedure cpu_c (     
    clk: in std_logic;
    rst_n: in std_logic;

    sel : out std_logic;
    dtack_n : in std_logic;
    rnw : out std_logic;
    ds_n : out std_logic_vector(1 downto 0);
    a : out std_logic_vector(4 downto 0);
    d : out std_logic_vector(15 downto 0)
  );
  attribute foreign of cpu_c :
    procedure is "VHPIDIRECT cpu_c";
end cpu;

package body cpu is
  procedure cpu_c (
    clk: in std_logic;
    rst_n: in std_logic;

    sel : out std_logic;
    dtack_n : in std_logic;
    rnw : out std_logic;
    ds_n : out std_logic_vector(1 downto 0);
    a : out std_logic_vector(4 downto 0);
    d : out std_logic_vector(15 downto 0)
  )     is
  begin
    assert false report "VHPI" severity failure;
  end cpu_c;
end cpu;
