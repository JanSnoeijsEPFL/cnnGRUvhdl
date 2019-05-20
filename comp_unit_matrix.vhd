library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity comp_unit_matrix is
	generic(
		MAC_MAX : natural := 100;
		NBITS : natural := 6;
		NACC : natural := 11;
		NBFRAC : natural := 4
	);
	port(
		clk : in std_logic;
		rstB : in std_logic;
		x_line : in std_logic_vector(MAC_MAX*(2*NBITS+NACC)-1 downto 0);
		mode : in std_logic_vector(1 downto 0);
		res_line : out std_logic_vector(MAC_MAX*NBITS-1 downto 0)
	
	);
end entity comp_unit_matrix;

architecture rtl of comp_unit_matrix is
	type long_arr is array (0 to MAC_MAX-1) of std_logic_vector(2*NBITS+NACC-1 downto 0);
	type short_arr is array (0 to MAC_MAX-1) of std_logic_vector(NBITS-1 downto 0);
	
	signal x_arr,in_max_arr, in_min_arr : long_arr;
	signal op_arr, out_max_arr, out_min_arr, res_arr, round_arr, hs_arr : short_arr;
	
begin
	convert: for i in 0 to MAC_MAX-1 generate
		x_arr(i) <= x_line(i*(2*NBITS+NACC)+2*NBITS+NACC-1 downto i*(2*NBITS+NACC)+0);
		res_line(i*NBITS+NBITS-1 downto i*NBITS+0) <= res_arr(i) ;
	end generate;		
			
	gen_matrix : for i in 0 to MAC_MAX-1 generate
		comp_unit_inst: entity work.comp_unit(rtl)
		generic map(
			NBITS => NBITS,
			NACC => NACC,
			NBFRAC => NBFRAC
		)
		port map(
			clk => clk,
			rstB => rstB,
			in_x => x_arr(i),
			mode => mode,
			res => res_arr(i)
		);
	end generate;
	
end architecture;
 

	