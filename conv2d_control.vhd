library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity conv2d_control is
	generic(
		RECUR_CNTR_MAX : natural := 10;
		RAM_LINE_SIZE : natural := 600;
		xlog2NBWords : natural := 6
	);
	port(
		clk : in std_logic;
		rstB : in std_logic;
		conv2d_end : out std_logic;
	   x_ocram_data : in std_logic_vector(RAM_LINE_SIZE-1 downto 0);
	   x_ocram_address : out std_logic_vector(xlog2NBWords-1 downto 0);
		algo_state : in std_logic_vector(2 downto 0);
	);
end entity conv2d_control;

architecture rtl of conv2d_control is
	type FSM is (sleep,line_even, line_odd, bias);
	signal state_reg, state_next : FSM;
	signal subMatrix_CntrEnable : std_logic;
	signal subMatrix_CntrReset : std_logic;
	signal subMatrix_CntrVal : std_logic_vector(3 downto 0); --log2(RECUR_CNTR_MAX)
	signal subMatrix_CntrEnd : std_logic;
	
	signal xdata_CntrEnable : std_logic;
	signal xdata_CntrReset : std_logic;
	signal xdata_CntrVal : std_logic_vector(3 downto 0); --log2(RECUR_CNTR_MAX)
	signal xdata_CntrEnd : std_logic;

begin
	
	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			state_reg <= sleep;
		elsif rising_edge(clk) then
			state_reg <= state_next;
		end if;
	end process;
	
	NSL : process(state_reg, start_algo, recur_cntr_end, conv2d_end, gru_end, dense_end)
	begin
		case state_reg is
			when sleep =>
				recur_CntrReset <= '1';
				if start_algo = '1' then
					state_next <= recur;
				end if;
			when recur =>
				recur_CntrReset <= '0';
				recur_CntrEnable <= '1';
				if recur_CntrEnd = '1' then
					state_next <= dense;
				else
					state_next <= conv2d;
			when conv2d =>
				recur_CntrEnable <= '0';
				if conv2d_end = '1' then
					state_next <= gru;
				end if;
			when gru => 
				if gru_end = '1' then
					state_next <= recur;
				end if;
			when dense =>
				if dense_end = '1' then
					state_next <= sleep;
				end if;
		end case;
end architecture rtl;

