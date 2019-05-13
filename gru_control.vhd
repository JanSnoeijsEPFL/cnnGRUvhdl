library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gru_control is
	generic(
		NBITS : natural := 6;
		RAM_LINE_SIZE : natural := 600;
		NBOUT : natural := 100;
		wlog2NbWords : natural := 12;
		ulog2NbWords : natural := 9;
		xlog2NbWords : natural := 7;
		MAC_MAX : natural := 100;
		NACC : natural := 11
	);
	port(
		clk : in std_logic;
		rstB : in std_logic;

		trigger_gru : in std_logic;
		recur_CntrVal : in std_logic_vector(3 downto 0); 
		finished_products : out std_logic; -- indicator for pipelining of next  convolutional layer.
		
		--interface to fifo
		fifo_rdreq : out std_logic;
		fifo_data : in std_logic_vector(NBITS-1 downto 0);
		
		--interface to W and U OCRAMs
		wocram_addr : out std_logic_vector(wlog2NbWords-1 downto 0);
		wocram_data : in std_logic_vector(RAM_LINE_SIZE-1 downto 0);
		uocram_addr : out std_logic_vector(ulog2NbWords-1 downto 0);
		uocram_data : in std_logic_vector(RAM_LINE_SIZE-1 downto 0);
		
		--interface to mac_matrix
		macs_x_gru : out std_logic_vector(MAC_MAX*NBITS-1 downto 0);
		macs_w_gru : out std_logic_vector(MAC_MAX*NBITS-1 downto 0);
		macs_clear_gru : out std_logic_vector(MAC_MAX-1 downto 0);
		macs_o_gru : in std_logic_vector(MAC_MAX*(2*NBITS+NACC)-1 downto 0);
		-- interface to comp units
		--comp_line : out std_logic_vector(MAC_MAX*(2*NBITS+NACC)-1  downto 0);
		--comp_line_2 : out std_logic_vector(MAC_MAX*(2*NBITS+NACC)-1  downto 0);
		res_line : in std_logic_vector(NBITS*MAC_MAX-1 downto 0);
		
		-- output data
		s_out : out std_logic_vector(NBITS*NBOUT-1 downto 0);
		comp_mode : out std_logic_vector(1 downto 0);
		x_ocram_DEBUG_addr_b : out std_logic_vector(xlog2NbWords-1 downto 0);
		x_ocram_DEBUG_data_b : out std_logic_vector(RAM_LINE_SIZE-1 downto 0);
		x_ocram_DEBUG_wren_b : out std_logic
		
	);
end entity gru_control;

architecture rtl of gru_control is
	signal s_1_reg, s_1_next : std_logic_vector(NBOUT*NBITS-1 downto 0);
	signal s_reg, s_next : std_logic_vector(NBOUT*NBITS-1 downto 0);
	signal r_reg, r_next : std_logic_vector(NBOUT*NBITS-1 downto 0);
	signal z_reg, z_next : std_logic_vector(NBOUT*NBITS-1 downto 0);
	signal h_reg, h_next : std_logic_vector(NBOUT*NBITS-1 downto 0);
	signal trig_reg, trig_next : std_logic;
	signal trig_1_reg, trig_1_next : std_logic;
	--signal dir_reg, dir_next : std_logic_vector(NBOUT*(2*NBITS+NACC)-1 downto 0);
	--signal rec_reg, rec_next : std_logic_vector(NBOUT*(2*NBITS+NACC)-1 downto 0);
	signal z_inv : std_logic_vector(NBOUT*NBITS-1 downto 0);
	type FSM is (sleep , Zdir, Zrec, Zbias, Rdir, Rrec,Rbias,MacBreak1,R_S, Hdir, Hrec,Hbias, ZINV1, ZINV2, MacBreak2, H_1_Z, S_Z);
	signal state_reg, state_next : FSM;
	signal state_1_reg, state_1_next : FSM;
	signal state_2_reg, state_2_next : FSM;
	signal state_3_reg, state_3_next : FSM;
	signal state_4_reg, state_4_next : FSM;
	signal state_5_reg, state_5_next : FSM;
	signal state_6_reg, state_6_next : FSM;
	signal state_7_reg, state_7_next : FSM;
	--- NOTE: reuse r_reg to store r*s_1 (r not used afterwards)
	
	signal dir_CntrVal : std_logic_vector(10 downto 0);
	signal dir_CntrReset : std_logic;
	signal dir_CntrEnable : std_logic;
	signal dir_CntrEnd : std_logic;
	
	signal rec_CntrVal : std_logic_vector(6 downto 0);
	signal rec_CntrReset : std_logic;
	signal rec_CntrEnable : std_logic;
	signal rec_CntrEnd : std_logic;
	
	signal break_CntrVal : std_logic_vector(1 downto 0);
	signal break_CntrReset : std_logic;
	signal break_CntrEnable : std_logic;
	signal break_CntrEnd : std_logic;
	
	signal macs_clear : std_logic;
	signal trunc_mac : std_logic_vector(MAC_MAX*NBITS-1 downto 0);
	--signal macs_out_gru : std_logic_vector(MAC_MAX*(2*NBITS+NACC)-1 downto 0);
	
	constant BREAK_DELAY : natural := 4;
	constant DIR_ACC : natural := 1078;
	constant REC_ACC : natural := 100;
	constant WOFFSET : unsigned(11 downto 0) := to_unsigned(1078, 12);
	constant UOFFSET : unsigned(7 downto 0) := to_unsigned(100, 8);
	constant DEBUG_OFFSET :  unsigned(xlog2NbWords-1 downto 0) := to_unsigned(45, xlog2NbWords);
	constant const_one : std_logic_vector(NBITS-1 downto 0) := std_logic_vector(to_unsigned(16, NBITS));
	signal cnst_ones : std_logic_vector(MAC_MAX*NBITS-1 downto 0);
	constant const_17 : std_logic_vector(NBITS-1 downto 0) := std_logic_vector(to_unsigned(17, NBITS));
	signal cnst_17 : std_logic_vector(MAC_MAX*NBITS-1 downto 0);
	constant const_1 : std_logic_vector(NBITS-1 downto 0) := std_logic_vector(to_unsigned(1, NBITS));
	signal cnst_1 : std_logic_vector(MAC_MAX*NBITS-1 downto 0);
	
	signal s_reg_vect : std_logic_vector(MAC_MAX*NBITS-1 downto 0);
	signal fifo_data_vect : std_logic_vector(MAC_MAX*NBITS-1 downto 0);
	--signal cycle_lat_reg, cycle_lat_next : std_logic;

begin

	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			--s_1_reg <= (others => '0');
			s_reg <= (others => '0');
			z_reg <= (others => '0');
			r_reg <= (others => '0');
			h_reg <= (others => '0');
			state_reg <= sleep;
			state_1_reg <= sleep;
			state_2_reg <= sleep;
			state_3_reg <= sleep;
			state_4_reg <= sleep;
			state_5_reg <= sleep;
			state_6_reg <= sleep;
			state_7_reg <= sleep;
			trig_reg <= '0';
			trig_1_reg <= '0';
			--cycle_lat_reg <= '0';
		elsif rising_edge(clk) then
			--s_1_reg <= s_1_next;
			s_reg <= s_next;
			z_reg <= z_next;
			r_reg <= r_next;
			h_reg <= h_next;
			trig_reg <= trig_next;
			trig_1_reg <= trig_1_next;
			state_reg <= state_next;
			state_1_reg <= state_1_next;
			state_2_reg <= state_2_next;
			state_3_reg <= state_3_next;
			state_4_reg <= state_4_next;
			state_5_reg <= state_5_next;
			state_6_reg <= state_6_next;
			state_7_reg <= state_7_next;
			--cycle_lat_reg <= cycle_lat_next;
		end if;
	end process;
	
	--shift register for state_reg
	state_1_next <= state_reg;
	state_2_next <= state_1_reg;
	state_3_next <= state_2_reg;
	state_4_next <= state_3_reg;
	state_5_next <= state_4_reg;
	state_6_next <= state_5_reg;
	state_7_next <= state_6_reg;
	
	trig_next <= trigger_gru;
	trig_1_next <= trig_reg;
	
	NSL: process(state_reg, trig_1_reg, recur_CntrVal, dir_CntrEnd, rec_CntrEnd, break_CntrEnd)
	begin
		state_next <= state_reg;
		dir_CntrEnable <= '0';
		rec_CntrEnable <= '0';
		dir_CntrReset <= '0';
		rec_CntrReset <= '0';
		break_CntrEnable <= '0';
		break_CntrReset <= '0';
		comp_mode <= "00";
		--finished_products <= '0';
		case state_reg is
			when sleep =>
				if trig_1_reg = '1' then
					state_next <= Zdir;
					dir_CntrReset <= '1';
					rec_CntrReset <= '1';
					break_CntrReset <= '1';
				end if;
			when Zdir =>
				-- counter enable (1078)
				dir_CntrEnable <= '1';
				if dir_CntrEnd = '1' then
					if recur_CntrVal = "0000" then
						state_next <= Zbias;
					else
						state_next <= Zrec;
					end if;
				end if;
			when Zrec =>
				rec_CntrEnable <= '1';
				if rec_CntrEnd = '1' then
					state_next <= Zbias;
				end if;
			when Zbias =>
				state_next <= Rdir;
				if recur_CntrVal = "0000" then
					state_next <= Hdir;
				else
					state_next <= Rdir;
				end if;
			when Rdir => 
				-- mode for Z
				comp_mode <= "10"; -- Hard sigmoid
				dir_CntrEnable <= '1';
				if dir_CntrEnd = '1' then
						state_next <= Rrec;
				end if;
			when Rrec =>
				rec_CntrEnable <= '1';
				if rec_CntrEnd = '1' then
					state_next <= Rbias;
				end if;
			when Rbias =>
				state_next <= MacBreak1;
			when MacBreak1 =>
				break_CntrEnable <= '1';
				if break_CntrEnd = '1' then
					state_next <=R_S;
				end if;
			when R_S =>
				state_next <= Hdir;
			when Hdir => 
				--mode for R
				comp_mode <= "10"; -- Hard sigmoid
				dir_CntrEnable <= '1';
				if dir_CntrEnd = '1' then
					if recur_CntrVal = "0000" then
						state_next <= Hbias;
					else
						state_next <= Hrec;
					end if;
				end if;
			when Hrec =>
				rec_CntrEnable <= '1';
				if rec_CntrEnd = '1' then
					state_next <= Hbias;
				end if;
			when Hbias => 
				comp_mode <= "11"; -- Hard tanh
				state_next <= ZINV1;
			when ZINV1 =>
				state_next <= ZINV2;
			when ZINV2 =>
				state_next <= MacBreak2;
			when MacBreak2 =>
				break_CntrEnable <= '1';
				if break_CntrEnd = '1' then
					state_next <=H_1_Z;
				end if;
			when H_1_Z =>
				if recur_CntrVal = "0000" then
					state_next <= sleep;
					--finished_products <= '1';
				else
					state_next <= S_Z;
				end if;
			when S_Z =>
				state_next  <= sleep;
				--finished_products <= '1';
		end case;
	end process;
	
	
	wocram_addr <= '0'& dir_CntrVal when state_reg = Zdir else
						std_logic_vector(unsigned(dir_CntrVal) + WOFFSET) when state_reg = Rdir else
						std_logic_vector(unsigned(dir_CntrVal) + WOFFSET+WOFFSET) when state_reg  = Hdir else 
						(others => '0');
	
	uocram_addr <= "00" & rec_CntrVal when state_reg = Zrec else
						std_logic_vector(to_unsigned(to_integer(unsigned(rec_CntrVal) + UOFFSET), uocram_addr'length)) when state_reg = Rrec else
						std_logic_vector(to_unsigned(to_integer(unsigned(rec_CntrVal) + UOFFSET+UOFFSET), uocram_addr'length)) when state_reg  = Hrec else
					   std_logic_vector(to_unsigned(300, uocram_addr'length)) when state_reg = Zbias else
						std_logic_vector(to_unsigned(301, uocram_addr'length)) when state_reg = Rbias else
						std_logic_vector(to_unsigned(302, uocram_addr'length)) when state_reg = Hbias else
						(others => '0');
	
	-- read from Fifo
	fifo_rdreq <= '1' when state_1_reg = Zdir or state_1_reg = Rdir or state_1_reg = Hdir 
					  else '0';
	
	-- control MAC_MATRIX (clear mac + sample the outputs)
	-- 2 cycles latency because of the OCRAM read accesses
	-- 3 cycles of latency because of the MAC units
	-- => 5 cycles + 1078 / 5 + 100 mac_clear => delay CntrEnd signals by 5 cycles. (create counter to count 5 cycles).

	macs_clear <= '1' when state_5_reg = Zbias or state_5_reg = Rbias or state_5_reg = Hbias or 
							state_5_reg = ZINV2 or state_5_reg = R_S or state_5_reg = S_Z or (state_5_reg = H_1_Z and recur_CntrVal = "0000")
						else '0';
	
	gen_vect : for i in 0 to MAC_MAX-1 generate
		cnst_ones(NBITS*i + NBITS-1 downto NBITS*i) <= const_one;
		cnst_17(NBITS*i + NBITS-1 downto NBITS*i) <= const_17;
		cnst_1(NBITS*i + NBITS-1 downto NBITS*i) <= const_1;
		fifo_data_vect(NBITS*i +NBITS-1 downto NBITS*i) <= fifo_data;
		s_reg_vect(NBITS*i+NBITS-1 downto NBITS*i) <= s_reg(NBITS*to_integer(unsigned(rec_CntrVal))+NBITS-1 downto NBITS*to_integer(unsigned(rec_CntrVal)));
	end generate;
	
	
	macs_x_gru <= fifo_data_vect  when state_2_reg = Zdir or state_2_reg = Rdir or state_2_reg  = Hdir else
						s_reg when state_2_reg = Zrec or state_2_reg = Rrec or state_2_reg = Hrec or state_2_reg = R_S or state_2_reg = S_Z else
						cnst_1 when state_2_reg = ZINV1 else
						cnst_17 when state_2_reg = ZINV2 else
						h_reg when state_2_reg = H_1_Z else 
						cnst_ones when state_2_reg = Zbias or state_2_reg = Rbias or state_2_reg = Hbias else
						(others => '0');
						
	macs_w_gru <= wocram_data when state_2_reg = Zdir or state_2_reg = Rdir or state_2_reg  = Hdir else
						uocram_data when state_2_reg = Zrec or state_2_reg = Rrec or state_2_reg = Hrec else
						uocram_data when state_2_reg = Zbias or state_2_reg = Rbias or state_2_reg = Hbias else
						r_reg when state_2_reg = R_S or state_2_reg = H_1_Z else
						not z_reg when state_2_reg = ZINV1 else
						cnst_1 when state_2_reg = ZINV2 else
						z_reg when state_2_reg = S_Z else (others => '0');
	TRUNCATE : for i in 0 to MAC_MAX-1 generate
		trunc_mac(NBITS-1+NBITS*i downto NBITS*i) <= macs_o_gru(NBITS-1 +(NBITS*2+NACC)*i downto (NBITS*2+NACC)*i);
	end generate;
	
	z_next <= res_line when state_6_reg = Zbias else z_reg;
	r_next <= res_line when state_6_reg = Rbias or state_6_reg = R_S else
				trunc_mac when state_5_reg = ZINV2 else r_reg;
	h_next <= res_line when state_6_reg = Hbias else h_reg;
	s_next <= res_line when state_6_reg = S_Z or (recur_CntrVal = "0000" and state_6_reg = H_1_Z) else s_reg;
	
	finished_products <= '1' when state_6_reg = S_Z or (recur_CntrVal = "0000" and state_6_reg = H_1_Z) else '0';
	
	x_ocram_DEBUG_addr_b <=  std_logic_vector(DEBUG_OFFSET) when state_7_reg = Zbias else
									std_logic_vector(DEBUG_OFFSET+1) when state_7_reg = Rbias else
									std_logic_vector(DEBUG_OFFSET+2) when state_7_reg = Hbias else
									std_logic_vector(DEBUG_OFFSET+3) when state_7_reg = S_Z  or (recur_CntrVal = "0000" and state_6_reg = H_1_Z) else
									(others => '0');
	x_ocram_DEBUG_data_b <= z_reg when state_7_reg = Zbias else
							r_reg when state_7_reg = Rbias else
							h_reg when state_7_reg = Hbias else
							s_reg when state_7_reg = S_Z  or (recur_CntrVal = "0000" and state_6_reg = H_1_Z) else
							(others => '0');
	x_ocram_DEBUG_wren_b <= '1' when state_7_reg = Zbias or state_7_reg = Rbias or state_7_reg = Hbias 
								or state_7_reg = S_Z or  (recur_CntrVal = "0000" and state_6_reg = H_1_Z) else '0';
								
								
	extend: for i in 0 to MAC_MAX-1 generate
		macs_clear_gru(i) <= macs_clear;
	end generate;
	
	rec_cntr_inst : entity work.counter(rtl)
	generic map(
		MAX_VAL => REC_ACC --100
	)
	port map(
		clk => clk,
		rstB => rstB,
		CntrEnable => rec_CntrEnable, 
		CntrReset => rec_CntrReset,
		CntrVal => rec_CntrVal,
		CntrEnd => rec_CntrEnd
	);
	
	dir_cntr_inst : entity work.counter(rtl)
	generic map(
		MAX_VAL => DIR_ACC --1078
	)
	port map(
		clk => clk,
		rstB => rstB,
		CntrEnable => dir_CntrEnable, 
		CntrReset => dir_CntrReset,
		CntrVal => dir_CntrVal,
		CntrEnd => dir_CntrEnd
	);
	
	break_cntr_inst : entity work.counter(rtl)
	generic map(
		MAX_VAL => BREAK_DELAY -- 4
	)
	port map(
		clk => clk,
		rstB => rstB,
		CntrEnable => break_CntrEnable, 
		CntrReset => break_CntrReset,
		CntrVal => break_CntrVal,
		CntrEnd => break_CntrEnd
	);
	
end architecture;
