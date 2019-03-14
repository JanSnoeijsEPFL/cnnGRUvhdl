library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity shift_acc is
	generic(
		NBITS : natural := 6;
		FRACBITS : natural := 4;
		NACC : natural := 11;
	port(
		x : in std_logic_vector((NBITS-1)*NBITS-1 downto 0);
		w : in std_logic_vector((NBITS-1)*NBITS-1 downto 0);
		
end entity shift_acc;

architecture rtl of shift_acc is
begin

end architecture rtl;