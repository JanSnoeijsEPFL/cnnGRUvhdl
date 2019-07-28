library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity maxp_matrix is
	generic(
		NBITS : natural := 6;
		NBMAXP : natural := 49
	);
	port(
		clk : in std_logic;
		rstB : in std_logic;
		in_1_line : in std_logic_vector(NBMAXP*NBITS-1 downto 0);
		in_2_line : in std_logic_vector(NBMAXP*NBITS-1 downto 0);
		sample: in std_logic;  --sample : '1';  or wait : '0'
		maxp_line : out std_logic_vector(NBMAXP*NBITS-1 downto 0)
		--xocram_wren_b : out std_logic
	);
end entity maxp_matrix;

architecture rtl of maxp_matrix is
	type arr is array(0 to NBMAXP-1) of std_logic_vector(NBITS-1 downto 0);
	signal in_1_arr : arr;
	signal in_2_arr : arr;
	signal maxp_arr : arr;
	signal mode : std_logic := '1';
	signal sample_next, sample_reg : std_logic;
	--signal wren_b_next, wren_b_reg : std_logic;

begin
	
	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			sample_reg <= '0';
			--wren_b_reg <= '0';
		elsif rising_edge(clk) then
			sample_reg <= sample_next;
			--wren_b_reg <= wren_b_next;
		end if;
	end process;
	
	convert : for i in 0 to NBMAXP-1 generate
		in_1_arr(i) <= in_1_line(NBITS-1+NBITS*i downto 0+NBITS*i);
		in_2_arr(i) <= in_2_line(NBITS-1+NBITS*i downto 0+NBITS*i);
		maxp_line(NBITS-1+NBITS*i downto 0+NBITS*i) <= maxp_arr(i);
	end generate;
	
	gen_maxp: for i in 0 to NBMAXP-1 generate
		maxp_unit_inst : entity work.maxp_unit(rtl)
		generic map(
			NBITS => NBITS
		)
		port map(
			clk => clk,
			rstB => rstB,
			in_1 => in_1_arr(i),
			in_2 => in_2_arr(i),
			sample => sample_reg,
			mode => mode,
			maxp => maxp_arr(i)
		);
	end generate;
	sample_next <= sample;
	--wren_b_next <= sample_reg;
	--xocram_wren_b <= wren_b_reg;
	mode <= not mode when rising_edge(sample_reg);
end architecture rtl;
