library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity acc_matrix is
	generic(
		EXTRA_ADDERS : natural := 100;
		OUT_NBITS : natural := 24; -- 6*2+log2(1078*2+1)
		NBITS : natural := 6
		);
	port(
		clk : in std_logic;
		rstB : in std_logic;
		clear : in std_logic;
		add : in std_logic;
		d_in : in std_logic_vector(EXTRA_ADDERS*NBITS-1 downto 0);
		d_out : out std_logic_vector(EXTRA_ADDERS*(OUT_NBITS)-1 downto 0)
		);
end entity acc_matrix;

architecture rtl of acc_matrix is
	type in_arr is array(0 to EXTRA_ADDERS-1) of std_logic_vector(NBITS-1 downto 0);
	type out_arr is array(0 to EXTRA_ADDERS-1) of std_logic_vector(OUT_NBITS-1 downto 0);
	signal d_in_arr: in_arr;
	signal acc_reg, acc_next : out_arr;
	begin
	-- input considered as registered
	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			acc_reg <= (others => '0');
		elsif rising_edge(clk) then
			acc_reg <= acc_next;
		end if;
	end process;
	
	convert : for i in 0 to EXTRA_ADDERS-1 generate
		d_in_arr(i) <= d_in(NBITS-1+i*NBITS downto 0 +i*NBITS);
		d_out(OUT_NBITS*-1 + OUT_NBITS*i downto i*OUT_NBITS) <= acc_reg(i) when clear = '0' else (others => '0');
	end generate;
	
	ACC : for i in 0 to EXTRA_ADDERS-1 generate
		acc_next <= std_logic_vector(to_signed(d_in_arr(i))+to_signed(acc_reg)) when add = '1' else
						d_in_arr(i) when clear = '1' else
						acc_reg;
	end generate;
	
end architecture rtl;