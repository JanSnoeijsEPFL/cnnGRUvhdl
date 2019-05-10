library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity maxp_unit is
	generic(
		NBITS : natural := 6
		--NBMAXP : natural := 49;
		--NBFRAC : natural := 4
	);
	port(
		clk : in std_logic;
		rstB : in std_logic;
		in_1 : in std_logic_vector(NBITS-1 downto 0);
		in_2 : in std_logic_vector(NBITS-1 downto 0);
		sample: in std_logic;  --sample : '1';  or wait : '0'
		mode : in std_logic; -- compare : '1';  or wait : '0'
		maxp : out std_logic_vector(NBITS-1 downto 0)
	);
end entity maxp_unit;

architecture rtl of maxp_unit is
	signal max12_next, max12_reg : std_logic_vector(NBITS-1 downto 0);
	signal maxfinal_next, maxfinal_reg : std_logic_vector(NBITS-1 downto 0);
begin
	
	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			max12_reg <= (others => '0');
			maxfinal_reg <= (others => '0');
		elsif rising_edge(clk) then
			max12_reg <= max12_next;
			maxfinal_reg <= maxfinal_next;
		end if;
	end process;
	
	--inputs are already registered
	max12_next <=  in_1 when (signed(in_1) >= signed(in_2)) and sample = '1' else
						in_2	when (signed(in_1) < signed(in_2)) and sample = '1' else
						max12_reg;
	maxfinal_next <= max12_reg when (signed(max12_reg) >= signed(max12_next)) and mode = '1'	else 
							max12_next;
	
	maxp <= maxfinal_reg;
end architecture rtl;