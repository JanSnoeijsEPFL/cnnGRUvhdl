library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity explut is
	generic(
		NBITS_IN : natural := 6;
		NBITS_OUT : natural := 16
		);
	port(
		x : in std_logic_vector(NBITS_IN-1 downto 0);
		y : out std_logic_vector(NBITS_OUT-1 downto 0)
	);
end entity explut;

architecture lut of explut is
	
begin
	
	process(x)
		constant NBITS_case : natural := 6;
		subtype lutcase is std_logic_vector(NBITS_case-1 downto 0);
		variable x_case : lutcase;
	begin
		x_case := x;
		case x_case is 
			when "100000"=> y <=  x"0115";-- -32
			when "100001"=> y <=  x"0127";-- -31
			when "100010"=> y <=  x"013A";-- -30
			when "100011"=> y <=  x"014E";-- -29
			when "100100"=> y <=  x"0164";-- -28
			when "100101"=> y <=  x"017B";-- -27
			when "100110"=> y <=  x"0193";-- -26
			when "100111"=> y <=  x"01AD";-- -25
			when "101000"=> y <=  x"01C9";-- -24
			when "101001"=> y <=  x"01E6";-- -23
			when "101010"=> y <=  x"0206";-- -22
			when "101011"=> y <=  x"0227";-- -21
			when "101100"=> y <=  x"024B";-- -20
			when "101101"=> y <=  x"0271";-- -19
			when "101110"=> y <=  x"0299";-- -18 
			when "101111"=> y <=  x"02C4";-- -17
			
			when "110000"=> y <=  x"02F1";-- -16
			when "110001"=> y <=  x"0322";-- -15
			when "110010"=> y <=  x"0356";-- -14
			when "110011"=> y <=  x"038D";-- -13
			when "110100"=> y <=  x"03C7";-- -12
			when "110101"=> y <=  x"0406";-- -11
			when "110110"=> y <=  x"0448";-- -10
			when "110111"=> y <=  x"048F";-- -9
			when "111000"=> y <=  x"04DA";-- -8
			when "111001"=> y <=  x"052A";-- -7
			when "111010"=> y <=  x"0580";-- -6
			when "111011"=> y <=  x"05DA";-- -5
			when "111100"=> y <=  x"063B";-- -4
			when "111101"=> y <=  x"06A2";-- -3
			when "111110"=> y <=  x"070F";-- -2 
			when "111111"=> y <=  x"0784";-- -1
			
			when "000000"=> y <=  x"0800";-- 0
			when "000001"=> y <=  x"0884";-- 1
			when "000010"=> y <=  x"0911";-- 2
			when "000011"=> y <=  x"09A6";-- 3
			when "000100"=> y <=  x"0A46";-- 4
			when "000101"=> y <=  x"0AEF";-- 5
			when "000110"=> y <=  x"0BA4";-- 6
			when "000111"=> y <=  x"0C64";-- 7
			when "001000"=> y <=  x"0D31";-- 8
			when "001001"=> y <=  x"0E0A";-- 9
			when "001010"=> y <=  x"0EF2";-- 10
			when "001011"=> y <=  x"0FE9";-- 11
			when "001100"=> y <=  x"10F0";-- 12
			when "001101"=> y <=  x"1207";-- 13
			when "001110"=> y <=  x"1331";-- 14
			when "001111"=> y <=  x"146E";-- 15
			
			when "010000"=> y <=  x"15BF";-- 16
			when "010001"=> y <=  x"1726";-- 17
			when "010010"=> y <=  x"18A4";-- 18
			when "010011"=> y <=  x"1A3B";-- 19
			when "010100"=> y <=  x"1BEC";-- 20
			when "010101"=> y <=  x"1DB9";-- 21
			when "010110"=> y <=  x"1FA4";-- 22
			when "010111"=> y <=  x"21AE";-- 23
			when "011000"=> y <=  x"23DA";-- 24
			when "011001"=> y <=  x"262A";-- 25
			when "011010"=> y <=  x"28A1";-- 26
			when "011011"=> y <=  x"2B3F";-- 27
			when "011100"=> y <=  x"2E09";-- 28
			when "011101"=> y <=  x"3102";-- 29
			when "011110"=> y <=  x"342B";-- 30 
			when "011111"=> y <=  x"3788";-- 31
			
			when others => y <=  (others => '0');
		end case;
	end process;
end architecture lut;
