library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity conv2d_output_control is
	generic(
		xlog2NBWords : natural := 7;
		MAC_MAX : natural := 100
	);
	port(
		clk : in std_logic;
		rstB : in std_logic;
		conv2d_end : out std_logic;
		--x_ocram_address_b : out std_logic_vector(xlog2NBWords-1 downto 0);
		--x_ocram_wren_b : out std_logic;
		start_sampling : in std_logic;
		macs_clear : out std_logic_vector(MAC_MAX-1 downto 0)
		--trig_serializer : out std_logic
		);
end entity conv2d_output_control;

architecture rtl of conv2d_output_control is
	type FSM is (sleep,mac_clr,sample,idle);
	signal state_reg, state_next : FSM;
	
	signal outline_CntrEnable : std_logic;
	signal outline_CntrReset : std_logic;
	signal outline_CntrVal : std_logic_vector(5 downto 0); --log2(44)
	signal outline_CntrEnd : std_logic;
	
	signal wait_CntrEnable : std_logic;
	signal wait_CntrReset : std_logic;
	signal wait_CntrVal : std_logic_vector(1 downto 0); --log2(3)
	signal wait_CntrEnd : std_logic;
	
	--constant OFFSET : std_logic_vector := std_logic_vector(to_unsigned(23,x_ocram_address_b'length));
	
begin
	
	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			state_reg <= sleep;
		elsif rising_edge(clk) then
			state_reg <= state_next;
		end if;
	end process;
	
	NSL : process(state_reg, outline_CntrEnd, wait_CntrEnd, start_sampling)
	begin
		--default 
		state_next <= state_reg;
		outline_CntrEnable <= '0';
		outline_CntrReset <= '0';
		wait_CntrEnable <= '0';
		wait_CntrReset <= '0';
		conv2d_end <= '0';
		--x_ocram_wren_b <= '0';
		macs_clear <= (others  => '0');
		
		case state_reg is
			when sleep =>
				if start_sampling = '1' then
					outline_CntrReset <= '1';
					state_next <= mac_clr;
				end if;
			when mac_clr =>
				macs_clear <= (others => '1');
				state_next <= sample;
			when sample =>
				outline_CntrEnable <= '1';
				if outline_CntrEnd = '1' then
					conv2d_end <= '1';
					state_next <= sleep;
				else
					state_next <= idle;
				end if;
			when idle =>
				wait_CntrEnable <= '1';
				if wait_CntrEnd = '1' then
					state_next <= mac_clr;
				end if;
			when others => 
				state_next <= sleep;
		end case;
	end process;

	--x_ocram_address_b <= std_logic_vector(unsigned(OFFSET) + unsigned(outline_CntrVal));
	--trig_serializer <= '1' when outline_CntrEnd = '1' else '0';	
	outline_cntr_inst : entity work.counter(rtl)
	generic map(
		MAX_VAL => 44 -- (23-1)*2
	)
	port map(
		clk => clk,
		rstB => rstB,
		CntrEnable => outline_CntrEnable, 
		CntrReset => outline_CntrReset,
		CntrVal => outline_CntrVal,
		CntrEnd => outline_CntrEnd
	);
	
	wait_cntr_inst : entity work.counter(rtl)
	generic map(
		MAX_VAL => 3
	)
	port map(
		clk => clk,
		rstB => rstB,
		CntrEnable => wait_CntrEnable, 
		CntrReset => wait_CntrReset,
		CntrVal => wait_CntrVal,
		CntrEnd => wait_CntrEnd
	);
	
end architecture rtl;


