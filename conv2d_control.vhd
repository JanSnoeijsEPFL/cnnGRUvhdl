library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity conv2d_control is
	generic(
		RAM_LINE_SIZE : natural := 600;
		xlog2NBWords : natural := 7;
		NBITS : natural := 6;
		MAC_MAX : natural := 100
	);
	port(
		clk : in std_logic;
		rstB : in std_logic;
	   x_ocram_data : in std_logic_vector(RAM_LINE_SIZE-1 downto 0);
	   x_ocram_address : out std_logic_vector(xlog2NBWords-1 downto 0);
		start_sampling : out std_logic;
		--algo_state : in std_logic_vector(2 downto 0);
		start_conv2d : in std_logic;
		conv2d_reg : in std_logic_vector(NBITS*10 -1 downto 0);
		macs_x : out std_logic_vector(NBITS*MAC_MAX-1 downto 0);
		macs_w : out std_logic_vector(NBITS*MAC_MAX-1 downto 0)
		--macs_o : in std_logic_vector(2*(NBITS+NACC)*MAc_MAX-1 downto 0);
		--macs_clear : out std_logic_vector(MAC_MAX-1 downto 0)
		);
end entity conv2d_control;

architecture rtl of conv2d_control is
	type FSM is (sleep,line_even, line_odd, bias);
	signal state_reg, state_next : FSM;
	signal f0_end_reg, f0_end_next : std_logic;
	signal wait_CntrEnable : std_logic;
	signal wait_CntrReset : std_logic;
	signal wait_CntrVal : std_logic_vector(0 downto 0); 
	signal wait_CntrEnd : std_logic;
	
	signal line_CntrEnable : std_logic;
	signal line_CntrReset : std_logic;
	signal line_CntrVal : std_logic_vector(4 downto 0); --log2(22)
	signal line_CntrEnd : std_logic;
	
	signal filter_CntrEnable : std_logic;
	signal filter_CntrReset : std_logic;
	signal filter_CntrVal : std_logic_vector(0 downto 0); 
	signal filter_CntrEnd : std_logic;
	
	constant line_CntrZERO : std_logic_vector(4 downto 0) := (others => '0');
	constant line_CntrMAX : std_logic_vector(4 downto 0) := std_logic_vector(to_unsigned(23, line_CntrZero'length));
	constant filter_CntrMAX : std_logic_vector(1 downto 0) := "10";
	
	signal param : std_logic_vector(NBITS-1 downto 0);
	signal param_line : std_logic_vector(99*NBITS-1 downto 0);
	signal one_cst_line : std_logic_vector(99*NBITS-1 downto 0);
	signal x_data : std_logic_vector(99*NBITS-1 downto 0);
begin
	
	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			state_reg <= sleep;
			f0_end_reg <= '0';
		elsif rising_edge(clk) then
			state_reg <= state_next;
			f0_end_reg <= f0_end_next;
		end if;
	end process;
	
	NSL : process(start_conv2d, filter_CntrVal, line_CntrVal, line_CntrEnd, wait_CntrEnd, filter_CntrEnd, state_reg, f0_end_reg)
	begin
		--default 
		f0_end_next <= f0_end_reg;
		state_next <= state_reg;
		line_CntrEnable <= '0';
		wait_CntrEnable <= '0';
		filter_CntrEnable <= '0';
		--macs_clear <= (others => '0');
		wait_CntrReset <= '0';
		line_CntrReset <= '0';
		filter_CntrReset <= '0';
		start_sampling <= '0';
		case state_reg is
			when sleep =>
				if start_conv2d = '1' then
					wait_CntrReset <= '1';
					line_CntrReset <= '1';
					filter_CntrReset <= '1';
					state_next <= line_even;
					line_CntrEnable <= '1';
					f0_end_next <= '0';
				end if;
			when line_even =>
				wait_CntrEnable <= '1';
				if wait_CntrEnd = '1' then
					state_next <= line_odd;
					if line_CntrVal = "00010" and filter_CntrEnd = '0' then
						start_sampling <= '1';
					elsif line_CntrEnd = '1' and filter_CntrEnd = '0' then
						f0_end_next <= '1';
						line_CntrReset <= '1';
					end if;
				end if;
			when line_odd =>
				wait_CntrEnable <= '1';
				if wait_CntrEnd = '1' then
					state_next <= bias;
				end if;
			when bias =>
				line_CntrEnable <= '1';
				if line_CntrEnd = '1' or f0_end_reg = '1' then
					f0_end_next <= '0';
					filter_CntrEnable <= '1';
					wait_CntrReset <= '1';
					line_CntrReset <= '1';
					if filter_CntrEnd = '1' then
						state_next <= sleep;
					else
						state_next <= line_even;
					end if;
				else
					state_next <= line_even;
				end if;
		end case;
	end process;

	x_ocram_address <= "00"&std_logic_vector(unsigned(line_CntrVal)); -- lines 23 to 46 not used here
	x_data <= x_ocram_data(593 downto 0) when wait_CntrEnd = '0' and (state_reg = line_odd or state_reg = line_even) else
				x_ocram_data(599 downto 6) when wait_CntrEnd = '1' and (state_reg = line_odd or state_reg = line_even) else
				one_cst_line when state_reg = bias else (others => '0');
	
	process(filter_CntrVal, state_reg, wait_CntrEnd, conv2d_reg)
	begin
		if filter_CntrVal = "0" then
			if state_reg = line_even and wait_CntrEnd = '0' then
				param <= conv2d_reg(NBITS-1 downto 0);
			elsif state_reg = line_even and wait_CntrEnd = '1' then
				param <= conv2d_reg(2*NBITS-1 downto NBITS);
			elsif state_reg = line_odd and wait_cntrEnd = '0' then
				param <= conv2d_reg(3*NBITS-1 downto 2*NBITS);
			elsif state_reg = line_odd and wait_cntrEnd = '1' then
				param <= conv2d_reg(4*NBITS-1 downto 3*NBITS);
			elsif state_reg = bias then
				param <= conv2d_reg(5*NBITS-1 downto 4*NBITS);
			else
				param <= (others => '0');
			end if;
		elsif filter_CntrVal = "1" then
			if state_reg = line_even and wait_CntrEnd = '0' then
				param <= conv2d_reg(6*NBITS-1 downto 5*NBITS);
			elsif state_reg = line_even and wait_CntrEnd = '1' then
				param <= conv2d_reg(7*NBITS-1 downto 6*NBITS);
			elsif state_reg = line_odd and wait_cntrEnd = '0' then
				param <= conv2d_reg(8*NBITS-1 downto 7*NBITS);
			elsif state_reg = line_odd and wait_cntrEnd = '1' then
				param <= conv2d_reg(9*NBITS-1 downto 8*NBITS);
			elsif state_reg = bias then
				param <= conv2d_reg(10*NBITS-1 downto 9 *NBITS);
			else
				param <= (others => '0');
			end if;
		else
			param <= (others => '0');
		end if;
	end process;
		
	dispatcher: for i in 0 to 98 generate
		param_line(i*NBITS+NBITS-1 downto 0+NBITS*i) <= param;
		one_cst_line(i*NBITS+NBITS-1 downto 0+NBITS*i) <= std_logic_vector(to_signed(16, NBITS));
	end generate;
	
	macs_x <= "000000"&x_data;
	macs_w <= "000000"&param_line;
		
	wait_cntr_inst : entity work.counter(rtl)
	generic map(
		MAX_VAL => 2
	)
	port map(
		clk => clk,
		rstB => rstB,
		CntrEnable => wait_CntrEnable, 
		CntrReset => wait_CntrReset,
		CntrVal => wait_CntrVal,
		CntrEnd => wait_CntrEnd
	);
	
	line_cntr_inst : entity work.counter(rtl)
	generic map(
		MAX_VAL => to_integer(unsigned(line_CntrMAX))
	)
	port map(
		clk => clk,
		rstB => rstB,
		CntrEnable => line_CntrEnable, 
		CntrReset => line_CntrReset,
		CntrVal => line_CntrVal,
		CntrEnd => line_CntrEnd
	);
	
	filter_cntr_inst : entity work.counter(rtl)
	generic map(
		MAX_VAL => to_integer(unsigned(filter_CntrMAX))
	)
	port map(
		clk => clk,
		rstB => rstB,
		CntrEnable => filter_CntrEnable, 
		CntrReset => filter_CntrReset,
		CntrVal => filter_CntrVal,
		CntrEnd => filter_CntrEnd
	);
	
end architecture rtl;


