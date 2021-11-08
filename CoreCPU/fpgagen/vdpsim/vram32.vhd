library ieee; use ieee.std_logic_1164.all;

package vram32 is
  procedure vram32_c (
    clk: in std_logic;
    addr: in std_logic_vector(14 downto 0);
    dout: out std_logic_vector(31 downto 0)
  );
  attribute foreign of vram32_c :
    procedure is "VHPIDIRECT vram32_c";
end vram32;

package body vram32 is
  procedure vram32_c (
    clk: in std_logic;
    addr: in std_logic_vector(14 downto 0);
    dout: out std_logic_vector(31 downto 0)
  )     is
  begin
    assert false report "VHPI" severity failure;
  end vram32_c;
end vram32;
