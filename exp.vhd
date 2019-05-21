library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity exp is
	generic(
		NBITS_IN : natural := 6;
		NBITS_OUT : natural := 14
	port(
		x : in std_logic_vector(NBITS_IN-1 downto 0);
		y : out std_logic_vector(NBITS_OUT-1 downto 0)
	);
end entity exp;

architecture lut of exp is
	signal y_int : integer;
begin
	process(x)
	begin
		case x is 
			when "100000" => y_int <= 277 -- -32
			when "100001" => y_int <= 295-- -31
			when "100010" => y_int <= 314-- -30
			when "100011" => y_int <= 334-- -29
			when "100100" => y_int <= 356-- -28
			when "100101" => y_int <= 379-- -27
			when "100110" => y_int <= 403-- -26
			when "100111" => y_int <= 429-- -25
			when "101000" => y_int <= 457-- -24
			when "101001" => y_int <= 486-- -23
			when "101010" => y_int <= 518-- -22
			when "101011" => y_int <= 551-- -21
			when "101100" => y_int <= 587-- -20
			when "101101" => y_int <= 625-- -19
			when "101110" => y_int <= 665-- -18 
			when "101111" => y_int <= 708-- -17
			
			when "110000" => y_int <= 753-- -16
			when "110001" => y_int <= 802-- -15
			when "100010" => y_int <= 854-- -14
			when "110011" => y_int <= 909-- -13
			when "110100" => y_int <= 967-- -12
			when "110101" => y_int <= 1030-- -11
			when "110110" => y_int <= 1096-- -10
			when "110111" => y_int <= 1167-- -9
			when "111000" => y_int <= 1242-- -8
			when "111001" => y_int <= 1322-- -7
			when "111010" => y_int <= 1408-- -6
			when "111011" => y_int <= 1498-- -5
			when "111100" => y_int <= 1595-- -4
			when "111101" => y_int <= 1698-- -3
			when "111110" => y_int <= 1807-- -2 
			when "111111" => y_int <= 1924-- -1
			
			when "000000" => y_int <= 2048-- 0
			when "000001" => y_int <= 2180-- 1
			when "000010" => y_int <= 2321-- 2
			when "000011" => y_int <= 2470-- 3
			when "000100" => y_int <= 2630-- 4
			when "000101" => y_int <= 2799-- 5
			when "000110" => y_int <= 2980-- 6
			when "000111" => y_int <= 3172-- 7
			when "001000" => y_int <= 3377-- 8
			when "001001" => y_int <= 3594-- 9
			when "001010" => y_int <= 3826-- 10
			when "001011" => y_int <= 4073-- 11
			when "001100" => y_int <= 4336-- 12
			when "001101" => y_int <= 4615-- 13
			when "001110" => y_int <= 4913-- 14
			when "001111" => y_int <= 5230-- 15
			
			when "010000" => y_int <= 5567-- 16
			when "010001" => y_int <= 5926-- 17
			when "000010" => y_int <= 6308-- 18
			when "010011" => y_int <= 6715-- 19
			when "010100" => y_int <= 7148-- 20
			when "010101" => y_int <= 7609-- 21
			when "010110" => y_int <= 8100-- 22
			when "010111" => y_int <= 8622-- 23
			when "011000" => y_int <= 9178-- 24
			when "011001" => y_int <= 9770-- 25
			when "011010" => y_int <= 10401-- 26
			when "011011" => y_int <= 11071-- 27
			when "011100" => y_int <= 11785-- 28
			when "011101" => y_int <= 12546-- 29
			when "011110" => y_int <= 13355-- 30 
			when "011111" => y_int <= 14216-- 31
		end case;
	end process;
	
	y <= std_logic_vector(to_unsigned(y_int, y'length));
end architecture lut;