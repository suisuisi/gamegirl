library ieee; use ieee.std_logic_1164.all; 

package video is
  procedure video_c (     
    clk: in std_logic;
    r: in std_logic_vector(3 downto 0);
    g: in std_logic_vector(3 downto 0);
    b: in std_logic_vector(3 downto 0);
    hs: in std_logic;
    vs: in std_logic
  );
  attribute foreign of video_c :
    procedure is "VHPIDIRECT video_c";
end video;

package body video is
  procedure video_c (
    clk: in std_logic;
    r: in std_logic_vector(3 downto 0);
    g: in std_logic_vector(3 downto 0);
    b: in std_logic_vector(3 downto 0);
    hs: in std_logic;
    vs: in std_logic
  )     is
  begin
    assert false report "VHPI" severity failure;
  end video_c;
end video;
