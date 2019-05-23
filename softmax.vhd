library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity softmax is
	generic(
		NBITS : natural := 6;
		NBITS_DIV : natural := 16;
		OUTPUTS : natural := 3;
		FRAC_LUT : natural := 11
		);
	port(
		clk : in std_logic;
		rstB : in std_logic;
		x : in std_logic_vector(OUTPUTS*NBITS-1 downto 0);
		y : out std_logic_vector(OUTPUTS*NBITS_DIV-1 downto 0);
		trig_softmax : in std_logic;
		softmax_rdy : out std_logic
	);	
end entity softmax;

architecture rtl of softmax is
	type FSM is (sleep, calc_sum, divide_1, divide_2);
	signal state_reg, state_next : FSM;
	signal state_1_reg, state_1_next : FSM;
	signal state_2_reg, state_2_next : FSM;
	type exp_arr is array(0 to OUTPUTS-1) of std_logic_vector(NBITS_DIV+FRAC_LUT-1 downto 0);
	type out_arr is array(0 to OUTPUTS-1) of std_logic_vector(NBITS_DIV-1 downto 0);
	signal acc_reg, acc_next : std_logic_vector(NBITS_DIV-1 downto 0);
	signal exp_reg, exp_next : exp_arr;
	signal sum_reg, sum_next : std_logic_vector(NBITS_DIV-1 downto 0);
	constant ZEROS : std_logic_vector(NBITS_DIV*OUTPUTS-1 downto 0) := (others => '0');
	signal exp_CntrEnable : std_logic;
	signal exp_CntrReset : std_logic;
	signal exp_CntrEnd : std_logic;
	signal exp_CntrVal : std_logic_vector(1 downto 0);
	signal exp_out : std_logic_vector(NBITS_DIV-1 downto 0);
	constant DIV_ZEROS : std_logic_vector(FRAC_LUT-1 downto 0) := (others => '0');
	signal exp_Cntr_1_reg, exp_Cntr_1_next : std_logic_vector(1 downto 0);
	signal exp_Cntr_2_reg, exp_Cntr_2_next : std_logic_vector(1 downto 0);
	signal acc_extended : std_logic_vector(NBITS_DIV+FRAC_LUT-1 downto 0);
	signal softmax_rdy_reg, softmax_rdy_next : std_logic;
	signal x_new : std_logic_vector(NBITS-1 downto 0);
	signal y_reg, y_next : out_arr;
	signal div_res : std_logic_vector(NBITS_DIV+FRAC_LUT-1 downto 0);
	signal x_reg, x_next : std_logic_vector(NBITS*OUTPUTS-1 downto 0);
	--signal trig_softmax_1_reg, trig_softmax_1_next : std_logic;
begin
	
	-- reg chain
	state_1_next <= state_reg;
	state_2_next <= state_1_reg;
	exp_Cntr_1_next <= exp_CntrVal;
	exp_Cntr_2_next <= exp_Cntr_1_reg;
	--trig_softmax_1_next <= trig_softmax;
	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			acc_reg <= (others => '0');
			exp_reg <= (others => (others => '0'));
			sum_reg <= (others => '0');
			state_reg <= sleep;
			state_1_reg <= sleep;
			state_2_reg <= sleep;
			softmax_rdy_reg <= '0';
			exp_Cntr_1_reg <= (others => '0');
			exp_Cntr_2_reg <= (others => '0');
			x_reg <= (others => '0');
			y_reg <= (others => (others => '0'));
			--trig_softmax_1_reg <= '0';
		elsif rising_edge(clk) then
			acc_reg <= acc_next;
			exp_reg <= exp_next;
			sum_reg <= sum_next;
			state_reg <= state_next;
			state_1_reg <= state_1_next;
			state_2_reg <= state_2_next;
			softmax_rdy_reg <= softmax_rdy_next;
			exp_Cntr_1_reg <= exp_Cntr_1_next;
			exp_Cntr_2_reg <= exp_Cntr_2_next;
			x_reg <= x_next;
			y_reg <= y_next;
			--trig_softmax_1_reg <= trig_softmax_1_next;
		end if;
	end process;

	NSL: process(state_reg, trig_softmax, exp_CntrEnd)
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
					state_next <= divide_1;
				end if;
			when divide_1 => 
				state_next <= divide_2;
			when divide_2 =>
				exp_CntrEnable <= '1';
				if exp_CntrEnd = '1' then
					state_next <= sleep;
				else
					state_next <= divide_1;
				end if;
		end case;
	end process;
	explut_inst: entity work.explut(lut)
	generic map(
		NBITS_IN => NBITS,
		NBITS_OUT => NBITS_DIV
		)
	port map(
		x => x_new,
		y => exp_out 
		);
	x_next <= x when trig_softmax = '1' else x_reg;	
	x_new <= x_reg(NBITS*to_integer(unsigned(exp_CntrVal)) +NBITS-1 downto NBITS*to_integer(unsigned(exp_CntrVal)));
	softmax_rdy_next <= '1' when state_1_reg = divide_2 and exp_CntrEnd = '1' else '0';
	softmax_rdy <= softmax_rdy_reg;
	acc_extended <= DIV_ZEROS&acc_reg;
	reg_fill: for i in 0 to OUTPUTS-1 generate
		exp_next(i) <=exp_out& DIV_ZEROS when state_reg = calc_sum and to_integer(unsigned(exp_CntrVal))=i else exp_reg(i);
		y_next(i) <= div_res(NBITS_DIV-1 downto 0) when state_2_reg = divide_2 and to_integer(unsigned(exp_Cntr_2_reg)) = i else y_reg(i);
		y(NBITS_DIV*i+NBITS_DIV-1 downto NBITS_DIV*i) <= y_next(i);
	end generate;
	div_res <= std_logic_vector(unsigned(exp_reg(to_integer(unsigned(exp_Cntr_2_reg))))/(unsigned(acc_extended)))
					when state_2_reg = divide_2 else (others => '0');
	sum_next <= exp_out when state_reg = calc_sum else sum_reg;
	acc_next <= std_logic_vector(resize(unsigned(sum_reg), acc_reg'length)+unsigned(acc_reg)) when state_1_reg = calc_sum else acc_reg;
	
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
