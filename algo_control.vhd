library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity algo_control is
	generic(
		RECUR_CNTR_MAX : natural := 10;
		DEBUG : natural := 0 -- DEBUG mode when '1'
	);
	port(
		clk : in std_logic;
		rstB : in std_logic;
		start_algo : in std_logic;
		conv2d_end : in std_logic;
		gru_end : in std_logic;
		dense_end : in std_logic;
		algo_state : out std_logic_vector(2 downto 0);
		start_conv2d : out std_logic;
		trig_serializer : out std_logic;
		recur_iter : out std_logic_vector(3 downto 0);
		trigger_gru : out std_logic;
		hps_write_new_batch : out std_logic;
		hps_DEBUG_read : out std_logic;
		trigger_dense : out std_logic
		
	);
end entity algo_control;

architecture rtl of algo_control is
	type FSM is (sleep,recur, conv2d,maxp, gru, dense, wait_trig);
	signal state_reg, state_next : FSM;
	signal recur_CntrEnable : std_logic;
	signal recur_CntrReset : std_logic;
	signal recur_CntrVal : std_logic_vector(3 downto 0); --log2(RECUR_CNTR_MAX)
	signal recur_CntrEnd : std_logic;
begin
	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			state_reg <= sleep;
		elsif rising_edge(clk) then
			state_reg <= state_next;
		end if;
	end process;
	NSL : process(state_reg, start_algo, recur_CntrEnd, conv2d_end, gru_end, dense_end)
	begin
		-- default
		recur_CntrReset <= '0';
		recur_CntrEnable <= '0';
		start_conv2d <= '0';
		trig_serializer <= '0';
		trigger_gru <= '0';
		state_next <= state_reg;
		hps_write_new_batch <= '0';
		hps_DEBUG_read <= '0';
		trigger_dense <= '0';
		case state_reg is
			when sleep =>
				hps_DEBUG_read <= '1';
				recur_CntrReset <= '1';
				if start_algo = '1' then --  has to be deasserted by processor
					state_next <= conv2d;
					start_conv2d <= '1';
				end if;
			when conv2d =>
				if conv2d_end = '1' then
					state_next <= maxp;
				end if;
			when maxp => 
				trig_serializer <= '1';
				state_next <= gru;
				trigger_gru <= '1';
			when gru => 
				hps_write_new_batch <= '1';
				if gru_end = '1' then
					state_next <= wait_trig;
				end if;
			when wait_trig =>
				hps_DEBUG_read <= '1';
				if recur_CntrEnd = '1' then --  has to be deasserted by processor
					trigger_dense <= '1';
					state_next <= dense;
				elsif start_algo = '1' then
					if DEBUG = 1 then
						state_next <= sleep;
					else
						state_next <= recur;
					end if;
				end if;
			when recur =>
				recur_CntrEnable <= '1';
				state_next <= conv2d;
				start_conv2d <= '1';
			when dense =>
				if dense_end = '1' then
					state_next <= sleep;
				end if;
			when others => 
				state_next <= sleep;
		end case;
	end process;
	
	recur_iter <= recur_CntrVal;
	recur_cntr_inst : entity work.counter(rtl)
	generic map(
		MAX_VAL => RECUR_CNTR_MAX
	)
	port map(
		clk => clk,
		rstB => rstB,
		CntrEnable => recur_CntrEnable, 
		CntrReset => recur_CntrReset,
		CntrVal => recur_CntrVal,
		CntrEnd => recur_CntrEnd
	);
	
	algo_state <=  "000" when state_reg = sleep else
						"001" when state_reg = recur else
						"010" when state_reg = conv2d else
						"011" when state_reg = gru else
						"100" when state_reg = dense else (others => '0');
end architecture rtl;
