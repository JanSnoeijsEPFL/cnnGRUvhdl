library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity softmax is
	generic(
		NBITS : natural := 6;
		NBITS_LUT : natural := 14;
		NBITS_DIV : natural := 16;
		OUTPUTS : natural := 3
		);
	port(
		clk : in std_logic;
		rstB : in std_logic;
		x : in std_logic_vector(NBITS-1 downto 0);
		y : out std_logic_vector(NBITS-1 downto 0);
		trig_softmax : in std_logic
	);	
end entity softmax;

architecture rtl of softmax is
	type FSM is (sleep, calc_sum, divide);
	signal state_reg, state_next : FSM;
	signal state_1_reg, state_1_next : FSM;
	type exp_arr is array(0 to OUTPUTS-1) of std_logic_vector(NBITS_LUT-1 downto 0);
	signal acc_reg, acc_next : std_logic_vector(NBITS_DIV-1 downto 0);
	signal div_reg, div_next : std_logic_vector(NBITS_DIV*2-1 downto 0);
	signal exp_reg, exp_next : exp_arr;
	signal sum_reg, sum_next : std_logic_vector(NBITS_LUT-1 downto 0);
	
	signal exp_CntrEnable : std_logic;
	signal exp_CntrReset : std_logic;
	signal exp_CntrEnd : std_logic;
	signal exp_CntrVal : std_logic_vector(1 downto 0);
	signal exp_out : std_logic_vector(NBITS_LUT-1 downto 0);

begin
	
	-- reg chain
	state_1_next <= state_reg;
	
	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			acc_reg <= (others => '0');
			div_reg <= (others => '0');
			exp_reg <= (others => '0');
			sum_reg <= (others => '0');
			state_reg <= sleep;
			state_1_reg <= sleep;
		elsif rising_edge(clk) then
			acc_reg <= acc_next;
			div_reg <= div_next;
			exp_reg <= exp_next;
			sum_reg <= sum_next;
			state_reg <= state_next;
			state_1_reg <= state_1_next;
		end if;
	end process;
	
	NSL: process(state_reg)
	begin
		state_next <= state_reg;
		exp_CntrEnable <= '0';
		exp_CntrReset <= '0';
		case state_reg is
			when sleep =>
				if trig_softmax = '1' then
					state_next <= calc_sum;
					exp_CntrReset <= '1';
				end if;
			when calc_sum => 
				exp_CntrEnable <= '1';
				if exp_CntrEnd = '1' then
					state_next <= divide;
				end if;
			when divide => 
				exp_CntrEnable <= '1';
				if exp_CntrEnd = '1' then
					state_next <= sleep;
				end if;
		end case;
	end process;
	exp_inst: entity work.exp(lut)
	generic map(
		NBITS_IN => NBITS,
		NBITS_OUT => NBITS_LUT
		)
	port map(
		x => x,
		y => exp_out 
		);
	exp_next(to_integer(unsigned(exp_CntrVal)) <= exp_out when state_reg = calc_sum else exp_reg;
	sum_next <= exp_out when state_reg = calc_sum else sum_reg;
	acc_next <= std_logic_vector(resize(unsigned(sum_reg), acc_reg'length)+unsigned(acc_reg)) when state_1_reg = calc_sum else acc_reg;
	div_next <= std_logic_vector(unsigned(acc_reg)/unsigned(to_integer(unsigned(exp_CntrVal)))) when state_1_reg = divide else div_reg;
	y <= div_reg;
	exp_cntr_inst: entity work.counter(rtl)
	generic map(
		MAX_VAL =>  OUTPUTS --3
	)
	port map(
		clk => clk,
		rstB => rstB,
		CntrEnable => exp_CntrEnable,
		CntrReset => exp_CntrReset,
		CntrVal => exp_CntrVal,
		CntrEnd => exp_CntrEnd
	);
	
end architecture rtl;
