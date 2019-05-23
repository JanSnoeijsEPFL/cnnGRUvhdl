library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dense is
	generic(
		--MAC_MAX : natural := 100;
		NBITS : natural := 6;
		INPUTS : natural := 100;
		OUTPUTS : natural := 3;
		BUFFER_SIZE : natural :=5;
		NBITS_DIV : natural := 16;
		ulog2NbWords : natural := 9;
		RAM_LINE_SIZE : natural := 600;
		U_DENSE_OFFSET : natural := 303;
		NACC_DENSE : natural := 7;
		NBFRAC : natural := 4;
		FRAC_LUT : natural := 11
	);
	port(
		clk: in std_logic;
		rstB : in std_logic;
		s_final : in std_logic_vector(NBITS*INPUTS-1 downto 0);
		dense_trigger: in std_logic;
		end_dense : out std_logic;
		uocram_data : in std_logic_vector(RAM_LINE_SIZE-1 downto 0);
		uocram_addr : out std_logic_vector(ulog2NbWords -1 downto 0);
		y_out : out std_logic_vector(OUTPUTS*NBITS_DIV-1 downto 0)
	);
end entity dense;

architecture rtl of dense is
	type FSM is (sleep, fill_buffer, wait1, wait2);
	type macFSM is (sleep, rd_buffer, bias);
	type buffer_type is array(0 to BUFFER_SIZE-1) of std_logic_vector(OUTPUTS*NBITS-1 downto 0);
	constant const_16 : std_logic_vector(NBITS-1 downto 0) := std_logic_vector(to_unsigned(16, NBITS));
	signal state_reg, state_next : FSM;
	signal state_1_reg, state_1_next : FSM;
	signal state_2_reg, state_2_next : FSM;
	signal mac_state_reg, mac_state_next : macFSM;
	--signal state_3_reg, state_3_next : FSM;
	--signal state_4_reg, state_4_next : FSM;
	--signal state_5_reg, state_5_next : FSM;
	--signal state_6_reg, state_6_next : FSM;
	--signal state_7_reg, state_7_next : FSM;
	signal buffer_reg, buffer_next : buffer_type;
	signal buffer_1_reg, buffer_1_next : buffer_type;
	signal ram_Cntr_1_reg, ram_Cntr_1_next : std_logic_vector(1 downto 0);
	signal ram_Cntr_2_reg, ram_Cntr_2_next : std_logic_vector(1 downto 0);
	
	signal trig_mac_1_reg, trig_mac_1_next : std_logic;
	signal trig_mac_2_reg, trig_mac_2_next : std_logic;


	signal dense_CntrEnd : std_logic;
	signal dense_CntrVal : std_logic_vector(6 downto 0);
	signal dense_CntrReset : std_logic;
	signal dense_CntrEnable : std_logic;
	
	signal buffIter_CntrEnd : std_logic;
	signal buffIter_CntrVal : std_logic_vector(4 downto 0);
	signal buffIter_CntrReset : std_logic;
	signal buffIter_CntrEnable : std_logic;
	
	signal buff_CntrEnd : std_logic;
	signal buff_CntrVal : std_logic_vector(2 downto 0);
	signal buff_CntrReset : std_logic;
	signal buff_CntrEnable : std_logic;
	
	signal ram_CntrEnd : std_logic;
	signal ram_CntrVal : std_logic_vector(1 downto 0);
	signal ram_CntrReset : std_logic;
	signal ram_CntrEnable : std_logic;
	
	signal res_dense : std_logic_vector(OUTPUTS*NBITS-1 downto 0);
	signal macs_clear_vect : std_logic_vector(OUTPUTS-1 downto 0);
	--constant RES_OFFSET :  unsigned(xlog2NbWords-1 downto 0) := to_unsigned(50, xlog2NbWords);
	
	signal softmax_in : std_logic_vector(OUTPUTS*NBITS-1 downto 0);
	signal softmax_out : std_logic_vector(OUTPUTS*NBITS_DIV-1 downto 0);
	signal trig_mac_fsm : std_logic;
	signal s_final_vect : std_logic_vector(NBITS*OUTPUTS-1 downto 0);
	signal macs_clear : std_logic;
	signal macs_x : std_logic_vector(NBITS*OUTPUTS-1 downto 0);
	signal macs_w : std_logic_vector(NBITS*OUTPUTS-1 downto 0);
	signal macs_o : std_logic_vector((NBITS*2+NACC_DENSE)*OUTPUTS-1 downto 0);
	signal dense_CntrEnd_1_reg, dense_CntrEnd_1_next : std_logic;
	signal dense_CntrEnd_2_reg, dense_CntrEnd_2_next : std_logic;
	signal dense_CntrEnd_3_reg, dense_CntrEnd_3_next : std_logic;
	signal dense_CntrEnd_4_reg, dense_CntrEnd_4_next : std_logic;
	signal dense_CntrEnd_5_reg, dense_CntrEnd_5_next : std_logic;
	signal const_16_vect : std_logic_vector(NBITS*OUTPUTS-1 downto 0);
	signal trig_softmax : std_logic;
	signal softmax_rdy : std_logic;

begin
	end_dense <= softmax_rdy;
	-- reg chain delay
	ram_Cntr_1_next <= ram_CntrVal;
	ram_Cntr_2_next <= ram_Cntr_1_reg;
	dense_CntrEnd_1_next <= dense_CntrEnd;
	dense_CntrEnd_2_next <= dense_CntrEnd_1_reg;
	dense_CntrEnd_3_next <= dense_CntrEnd_2_reg;
	dense_CntrEnd_4_next <= dense_CntrEnd_3_reg;
	dense_CntrEnd_5_next <= dense_CntrEnd_4_reg;
	state_1_next <= state_reg;
	state_2_next <= state_1_reg;
	trig_mac_1_next <= trig_mac_fsm;
	trig_mac_2_next <= trig_mac_1_reg;
	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			state_reg <= sleep;
			state_1_reg <= sleep;
			state_2_reg <= sleep;
			mac_state_reg <= sleep;
			--state_3_reg <= sleep;
			--state_4_reg <= sleep;
			--state_5_reg <= sleep;
			--state_6_reg <= sleep;
			buffer_reg <= (others => (others => '0'));
			buffer_1_reg <= (others => (others => '0'));
			ram_Cntr_1_reg <= (others => '0');
			ram_Cntr_2_reg <= (others => '0');
			trig_mac_1_reg <= '0';
			trig_mac_2_reg <= '0';
			dense_CntrEnd_1_reg <= '0';
			dense_CntrEnd_2_reg <= '0';
			dense_CntrEnd_3_reg <= '0';
			dense_CntrEnd_4_reg <= '0';
			dense_CntrEnd_5_reg <= '0';
		elsif rising_edge(clk) then
			state_reg <= state_next;
			state_1_reg <= state_1_next;
			state_2_reg <= state_2_next;
			mac_state_reg <= mac_state_next;
			--state_3_reg <= state_3_next;
			--state_4_reg <= state_4_next;
			--state_5_reg <= state_5_next;
			--state_6_reg <= state_6_next;
			buffer_reg <= buffer_next;
			buffer_1_reg <= buffer_1_next;
			ram_Cntr_1_reg <= ram_Cntr_1_next;
			ram_Cntr_2_reg <= ram_Cntr_2_next;
			trig_mac_1_reg <= trig_mac_1_next;
			trig_mac_2_reg <= trig_mac_2_next;
			dense_CntrEnd_1_reg <= dense_CntrEnd_1_next;
			dense_CntrEnd_2_reg <= dense_CntrEnd_2_next;
			dense_CntrEnd_3_reg <= dense_CntrEnd_3_next;
			dense_CntrEnd_4_reg <= dense_CntrEnd_4_next;
			dense_CntrEnd_5_reg <= dense_CntrEnd_5_next;

		end if;
	end process;
	
	NSL: process(state_reg, dense_trigger, buffIter_CntrEnd, ram_CntrEnd, buffIter_CntrVal)
	begin
		state_next <= state_reg;
		trig_mac_fsm <= '0';
		buffIter_CntrEnable <= '0';
		buffIter_CntrReset <= '0';
		ram_CntrEnable <= '0';
		ram_CntrReset <= '0';
		case state_reg is
			when sleep => 
				if dense_trigger = '1' then
					state_next <= fill_buffer;
					ram_CntrReset <= '1';
					buffIter_CntrReset <= '1';
				end if;
			when fill_buffer =>
				ram_CntrEnable <= '1';
				if ram_CntrEnd = '1' then
					state_next <= wait1;
				end if;
			when wait1 =>
				if buffIter_CntrVal = "00000" then
					trig_mac_fsm <= '1';
				end if;
				state_next <= wait2;
			when wait2 =>
				buffIter_CntrEnable <= '1';
				if buffIter_CntrEnd = '1' then
					state_next <= sleep;
				else
					state_next <= fill_buffer;
				end if;
		end case;
	end process;
	
	MAC_NSL : process(mac_state_reg, trig_mac_2_reg, buff_CntrEnd, dense_CntrEnd)
	begin
		mac_state_next <= mac_state_reg;
		buff_CntrReset <= '0';
		buff_CntrEnable <= '0';
		dense_CntrEnable <= '0';
		dense_CntrReset <= '0';
		case mac_state_reg is
			when sleep =>
				if trig_mac_2_reg = '1' then
					mac_state_next <= rd_buffer;
					buff_CntrReset <= '1';
					dense_CntrReset <= '1';
				end if;
			when rd_buffer =>
				buff_CntrEnable <= '1';
				dense_CntrEnable <= '1';
				if dense_CntrEnd = '1' then
					mac_state_next <= bias;
				end if;
			when bias =>
				mac_state_next <= sleep;
		end case;
	end process;
	
	uocram_addr <= std_logic_vector(to_unsigned(U_DENSE_OFFSET,uocram_addr'length) + resize(unsigned(ram_CntrVal), uocram_addr'length))
						when state_reg = fill_buffer else 
						std_logic_vector(to_unsigned(306,uocram_addr'length)) when state_reg = wait1 and buffIter_CntrEnd = '1' else
						(others => '0');
	BUFF :for i in 0 to BUFFER_SIZE-1 generate
		buffer_next(i)(NBITS-1+NBITS*(to_integer(unsigned(ram_Cntr_2_reg))) downto NBITS*(to_integer(unsigned(ram_Cntr_2_reg)))) <= 
												uocram_data(to_integer(unsigned(buffIter_CntrVal))*NBITS*BUFFER_SIZE+NBITS*i+NBITS-1 downto 
													to_integer(unsigned(buffIter_CntrVal))*NBITS*BUFFER_SIZE+NBITS*i) when state_2_reg = fill_buffer;
	end generate;
	
	COPY : for i in 0 to OUTPUTS-1 generate
		s_final_vect(NBITS*i+NBITS-1 downto NBITS*i) <= s_final(NBITS*to_integer(unsigned(dense_CntrVal))+ NBITS-1 
																		downto NBITS*to_integer(unsigned(dense_CntrVal)));
		const_16_vect(NBITS*i+NBITS-1 downto NBITS*i) <= const_16;
		macs_clear_vect(i) <= macs_clear;
	end generate;
	buffer_1_next <= buffer_reg when state_2_reg = wait1 else buffer_1_reg;
	macs_x <= s_final_vect when mac_state_reg = rd_buffer else 
						const_16_vect when mac_state_reg = bias else (others => '0');
	macs_w <= buffer_1_reg(to_integer(unsigned(buff_CntrVal))) when mac_state_reg = rd_buffer else
				uocram_data(NBITS*OUTPUTS-1 downto 0)  when mac_state_reg = bias else
				(others=> '0');
	macs_clear <= '1' when dense_CntrEnd_4_reg = '1' else '0';
	softmax_in	<= res_dense when dense_CntrEnd_5_reg = '1' else (others => '0');
	trig_softmax <= '1' when dense_CntrEnd_5_reg = '1' else '0';
	y_out <= softmax_out;
	buffIter_cntr_inst : entity work.counter(rtl)
	generic map(
		MAX_VAL =>  INPUTS/BUFFER_SIZE --20
	)
	port map(
		clk => clk,
		rstB => rstB,
		CntrEnable => buffIter_CntrEnable,
		CntrReset => buffIter_CntrReset,
		CntrVal => buffIter_CntrVal,
		CntrEnd => buffIter_CntrEnd
	);
	
	dense_cntr_inst : entity work.counter(rtl)
	generic map(
		MAX_VAL =>  INPUTS --100
	)
	port map(
		clk => clk,
		rstB => rstB,
		CntrEnable => dense_CntrEnable,
		CntrReset => dense_CntrReset,
		CntrVal => dense_CntrVal,
		CntrEnd => dense_CntrEnd
	);
	buff_cntr_inst : entity work.counter(rtl)
	generic map(
		MAX_VAL =>  BUFFER_SIZE --5
	)
	port map(
		clk => clk,
		rstB => rstB,
		CntrEnable => buff_CntrEnable,
		CntrReset => buff_CntrReset,
		CntrVal => buff_CntrVal,
		CntrEnd => buff_CntrEnd
	);
	
	ram_cntr_inst : entity work.counter(rtl)
	generic map(
		MAX_VAL =>  OUTPUTS --3
	)
	port map(
		clk => clk,
		rstB => rstB,
		CntrEnable => ram_CntrEnable,
		CntrReset => ram_CntrReset,
		CntrVal => ram_CntrVal,
		CntrEnd => ram_CntrEnd
	);
	
	softmax_inst : entity work.softmax(rtl)
	generic map(
		NBITS => NBITS,
		NBITS_DIV => NBITS_DIV,
		OUTPUTS => OUTPUTS,
		FRAc_LUT => FRAC_LUT
		)
	port map(
		clk => clk,
		rstB => rstB,
		x => softmax_in,
		y => softmax_out,
		trig_softmax => trig_softmax,
		softmax_rdy => softmax_rdy
	);
		
	macs_dense_inst: entity work.mac_matrix(rtl)
	generic map(
		NBITS => NBITS,
		NACC => NACC_DENSE, --7
		MAC_MAX => OUTPUTS -- 3
	)
	port map(
		in_a => macs_x,
		in_b => macs_w,
		macs_o => macs_o,
		clk => clk,
		rstB=> rstB,
		clear => macs_clear_vect
	);
		
	macs_comp_inst : entity work.comp_unit_matrix(rtl)
	generic map(
		MAC_MAX => OUTPUTS,
		NBITS => NBITS, 
		NACC => NACC_DENSE,
		NBFRAC => NBFRAC
	)
	port map(
		clk => clk,
		rstB => rstB,
		x_line => macs_o,
		mode => "00",
		res_line => res_dense
	);
end architecture rtl;