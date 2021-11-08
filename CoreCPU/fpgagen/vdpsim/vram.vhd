library ieee; use ieee.std_logic_1164.all; 

package vram is
  procedure vram_c (     
    clk: in std_logic;
    we: in std_logic;
    din: in std_logic_vector(15 downto 0);
    addr: in std_logic_vector(14 downto 0);
    dout: out std_logic_vector(15 downto 0)
  );
  attribute foreign of vram_c :
    procedure is "VHPIDIRECT vram_c";
end vram;

package body vram is
  procedure vram_c (
    clk: in std_logic;
    we: in std_logic;
    din: in std_logic_vector(15 downto 0);
    addr: in std_logic_vector(14 downto 0);
    dout: out std_logic_vector(15 downto 0)
  )     is
  begin
    assert false report "VHPI" severity failure;
  end vram_c;
end vram;
