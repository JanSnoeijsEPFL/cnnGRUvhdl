library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity conv2d is
	line_in : in std_logic_vector(599 downto 0);
	line_out : out std_logic_vector(599 downto 0);
	x_ocram_wren : out std_logic;
	clk : in std_logic;
	rstB : in std_logic;
	line_ctr : in std_logic;
	convreg : in std_logic_vector(59 downto 0);
end entity conv2d;

architecture rtl of conv2d is
	--signal mult_a_reg, mult_a_next : std_logic_vector(1199 downto 0);
	--signal mult_b_reg, mult_b_next : std_logic_vector(1199 downto 0);
	signal buffer_bias_reg, buffer_bias_next : std_logic_vector(1299 downto 0);
	signal buffer_final_reg, buffer_final_next : std_logic_vector(1399 downto 0);
	signal mult_a : std_logic_vector(1199 downto 0);
	signal mult_b : std_logic_vector(1199 downto 0);
	
	signal mux_a: std_logic_vector(5 downto 0);
	signal mux_b: std_logic_vector(5 downto 0);
	signal add_2lines : std_logic_vector(1299 downto 0);
begin
	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			mult_a_reg <= (others => '0');
			mult_b_reg <= (others => '0');
			add_a_reg <= (others => '0');
			add_b_reg <= (others => '0');
		elsif rising_edge(clk) then
			mult_a_reg <= mult_a_next;
			mult_b_reg <= mult_b_next;
			add_a_reg <= add_a_next;
			add_b_reg <= add_b_next;
		end if;
	end process;
	
	MUX: process(line_ctr, conv_reg)
	begin
		if line_ctr = '0' then
			mux_a <= conv_reg(5 downto 0); --w1
			mux_b <= conv_reg(11 downto 6); -- w2
		else
			mux_a <= conv_reg(17 downto 12); --w3
			mux_b <= conv_reg(23 downto 18); -- w4
		end if;
	end process;
	
	MULT:	for i in 0 to 99 generate
			mult_a(11+i*12 downto 0+i*12) <= line_in(5+i*6 downto 0+i*6)*mux_a;
			mult_b(11+i*12 downto 0+i*12) <= line_in(5+i*6 downto 0+i*6)*mux_b;
	end generate;
	
	ADD: for i in 0 to 99 generate
		add_2lines(12+i*13 downto 0+i*13) <= mult_a(11+i*12 downto 0+i*12)+ mult_b(11+i*12 downto 0+i*12);
	end generate;
	
	DEMUX: process(line_ctr, add2_lines, buffer_bias_reg, buffer_final_reg)
	begin
		buffer_bias_next <= buffer_bias_reg;
		buffer_final_next <= buffer_final_reg;
		if line_ctr = '0' then
			buffer_bias_next <= add_2lines(12+i*13 downto 0+i*13) + conv_reg(28 downto 22); -- b1
		else
			buffer_final_next(13+i*14 downto 0+i*14) <= add_2lines(12+i*13 downto 0+i*13) + buffer_bias_next(12+i*13 downto 0+i*13);
	end process;
end architecture rlt;