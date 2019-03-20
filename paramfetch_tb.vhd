library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity paramfetch_tb.vhd is
end entity paramfetch_tb.vhd;

architecture bench of paramfetch_tb is
	type paramSDRAM is array(4999 downto 0) of std_logic_vector(31 downto 0)
begin
	
end architecture bench;