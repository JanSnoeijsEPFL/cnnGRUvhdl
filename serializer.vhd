library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity serializer is
	generic(
		NBITS : natural := 6;
		NBMAXP : natural := 49;
		RAM_LINE_SIZE : natural := 600;
		MAXP_IM_HEIGHT : natural := 11
	);
	port(
		--xOCRAM interface
		clk : in std_logic;
		rstB : in std_logic;
		trigger : in std_logic;
		start_sampling : in std_logic;
		xocram_addr_a : out std_logic_vector(6 downto 0);
		xocram_data_a : in std_logic_vector(RAM_LINE_SIZE-1 downto 0);
		xocram_addr_b : out std_logic_vector(6 downto 0);
		xocram_wren_b : out std_logic;
		--fifo write interface
		clear_fifo : out std_logic;
		fifo_empty : in std_logic;
		fifo_full : in std_logic;
		fifo_wrreq : out std_logic;
		fifo_data : out std_logic_vector(NBITS-1 downto 0);
		recur_iter : in std_logic_vector(3 downto 0)
	);
end entity serializer;

architecture rtl of serializer is
	type SER_FSM is (sleep, read_F0, read_F1);
	type MAXP_FSM is (sleep,idle, ram_write, wait_1, ram_addr_inc);
	constant IN_OFFSET : unsigned(6 downto 0) := to_unsigned(23, 7);
	constant IMAGE_SIZE : unsigned(6 downto 0) := to_unsigned(11, 7);
	constant MASK : std_logic_vector(NBITS-1 downto 0) := "111111";
	constant ZEROS_594 : std_logic_vector(593 downto 0) := (others => '0');
	signal ser_state_reg, ser_state_next : SER_FSM;
	signal maxp_state_reg, maxp_state_next : MAXP_FSM;
	
	signal mask_CntrEnd : std_logic;
	signal mask_CntrVal : std_logic_vector(5 downto 0); --log2 NBMAXP
	signal mask_CntrReset : std_logic;
	signal mask_CntrEnable : std_logic;
	
	signal rdaddr_CntrEnd : std_logic;
	signal rdaddr_CntrVal : std_logic_vector(3 downto 0); -- log2 MAX_IM_HEIGHT
	signal rdaddr_CntrReset : std_logic;
	signal rdaddr_CntrEnable : std_logic;
	
	signal wraddr_CntrEnd : std_logic;
	signal wraddr_CntrVal : std_logic_vector(4 downto 0); -- log2 2* MAX_IM_HEIGHT
	signal wraddr_CntrReset : std_logic;
	signal wraddr_CntrEnable : std_logic;
	
	signal wait_CntrEnd : std_logic;
	signal wait_CntrVal : std_logic_vector(2 downto 0); -- log2 8
	signal wait_CntrReset : std_logic;
	signal wait_CntrEnable : std_logic;
	
	signal loop_CntrEnd : std_logic;
	signal loop_CntrVal : std_logic_vector(1 downto 0); -- log2 3
	signal loop_CntrReset : std_logic;
	signal loop_CntrEnable : std_logic;
	
	
	signal masked_data : std_logic_vector(RAM_LINE_SIZE-1 downto 0);
	signal init_next, init_reg : std_logic;
	signal end_next, end_reg : std_logic;
begin
	REG : process(clk, rstB)
	begin
		if rstB = '0' then
			ser_state_reg <= sleep;
			maxp_state_reg <= sleep;
			init_reg <= '0';
			end_reg <= '0';
		elsif rising_edge(clk) then
			ser_state_reg <= ser_state_next;
			maxp_state_reg <= maxp_state_next;
			init_reg <= init_next;
			end_reg <= end_next;
		end if;
	end process;
	
	NSL: process(ser_state_reg, rdaddr_CntrVal, rdaddr_CntrEnd, mask_CntrEnd, trigger, init_reg, mask_CntrVal, loop_CntrEnd, end_reg, recur_iter, loop_CntrVal)
	begin
		ser_state_next <= ser_state_reg;
		xocram_addr_a <= (others => '0');
		mask_CntrReset <= '0';
		rdaddr_CntrReset <= '0';
		mask_CntrEnable <= '0';
		rdaddr_CntrEnable <= '0';
		loop_CntrEnable <= '0';
		loop_CntrReset <= '0';
		fifo_wrreq <= '0';
		end_next <= end_reg;
		init_next <= init_reg;
		--fifo_wrreq <= '1';
		case ser_state_reg is
			when sleep =>
				if trigger = '1' then
					ser_state_next <= read_F0;
					mask_CntrReset <= '1';
					rdaddr_CntrReset <= '1';
					loop_CntrReset <= '1';
					init_next <= '1';
					end_next <= '0';
				end if;
			when read_F0 =>
				if init_reg = '0' then
					fifo_wrreq <= '1';
				end if;
				xocram_addr_a <= std_logic_vector(IN_OFFSET + unsigned(rdaddr_CntrVal));
				ser_state_next <= read_F1;
			when read_F1 =>
				if init_reg = '0' then
					fifo_wrreq <= '1';
					mask_CntrEnable <= '1';
				end if;
				init_next <= '0';
				xocram_addr_a <= std_logic_vector(IN_OFFSET + IMAGE_SIZE + unsigned(rdaddr_CntrVal));
				if mask_CntrVal = std_logic_vector(to_unsigned(47, mask_CntrVal'length)) then
					rdaddr_CntrEnable <= '1';
					mask_CntrReset <= '1';
				end if;
				if rdaddr_CntrEnd = '1' and  mask_CntrVal = std_logic_vector(to_unsigned(47, mask_CntrVal'length))  then
					loop_CntrEnable <= '1';
					rdaddr_CntrReset <= '1';
				end if;
				if loop_CntrVal = "01" and mask_CntrEnd = '1' and rdaddr_CntrEnd = '1' and recur_iter = "0000" then
					end_next <= '1';
				elsif loop_CntrEnd = '1' and mask_CntrEnd = '1' and rdaddr_CntrEnd = '1' then
					end_next <= '1';
				end if;
				if end_reg = '1' and mask_CntrEnd = '1' then
					ser_state_next <= sleep;
				else
					ser_state_next <= read_F0;
				end if;
			when others => 
				ser_state_next <= sleep;
		end case;
	end process;
	
	MAXP_NSL: process(maxp_state_reg, start_sampling, wraddr_CntrEnd, wait_CntrEnd)
	begin
	
		maxp_state_next <= maxp_state_reg;
		wait_CntrEnable <= '0';
		wraddr_CntrEnable <= '0';
		wraddr_CntrReset <= '0';
		wait_CntrReset <= '0';
		xocram_wren_b <= '0';
		case maxp_state_reg is
			when sleep =>
				if start_sampling = '1' then
					wait_CntrReset <= '1';
					wraddr_CntrReset <= '1';
					maxp_state_next <= idle;
				end if;
			when idle =>
				wait_CntrEnable <= '1';
				if wait_CntrEnd = '1' then
					maxp_state_next <= ram_write;
				end if;
			when ram_write =>
				xocram_wren_b <= '1';
				maxp_state_next <= wait_1;
			when wait_1 => 
				maxp_state_next <= ram_addr_inc;
			when ram_addr_inc =>
				wraddr_CntrEnable <= '1';
				if wraddr_CntrEnd = '1' then
					maxp_state_next <= sleep;
				else
					maxp_state_next <= idle;
				end if;
			when others => 
				maxp_state_next <= sleep;
			
		end case;
	end process;
	
	clear_fifo <= '0';

	xocram_addr_b <= std_logic_vector(resize(unsigned(IN_OFFSET),xocram_addr_b'length) + resize(unsigned(wraddr_CntrVal),xocram_addr_b'length));
	
	
	rdaddr_cntr_inst : entity work.counter(rtl)
	generic map(
		MAX_VAL => MAXP_IM_HEIGHT
	)
	port map(
		clk => clk,
		rstB => rstB,
		CntrEnable => rdaddr_CntrEnable, 
		CntrReset => rdaddr_CntrReset,
		CntrVal => rdaddr_CntrVal,
		CntrEnd => rdaddr_CntrEnd
	);
	
	wraddr_cntr_inst : entity work.counter(rtl)
	generic map(
		MAX_VAL => MAXP_IM_HEIGHT*2
	)
	port map(
		clk => clk,
		rstB => rstB,
		CntrEnable => wraddr_CntrEnable, 
		CntrReset => wraddr_CntrReset,
		CntrVal => wraddr_CntrVal,
		CntrEnd => wraddr_CntrEnd
	);
	
	mask_cntr_inst : entity work.counter(rtl)
	generic map(
		MAX_VAL => NBMAXP
	)
	port map(
		clk => clk,
		rstB => rstB,
		CntrEnable => mask_CntrEnable, 
		CntrReset => mask_CntrReset,
		CntrVal => mask_CntrVal,
		CntrEnd => mask_CntrEnd
	);
	
	wait_cntr_inst : entity work.counter(rtl)
	generic map(
		MAX_VAL => 7
	)
	port map(
		clk => clk,
		rstB => rstB,
		CntrEnable => wait_CntrEnable, 
		CntrReset => wait_CntrReset,
		CntrVal => wait_CntrVal,
		CntrEnd => wait_CntrEnd
	);
	
	loop_cntr_inst : entity work.counter(rtl)
	generic map(
		MAX_VAL => 3
	)
	port map(
		clk => clk,
		rstB => rstB,
		CntrEnable => loop_CntrEnable, 
		CntrReset => loop_CntrReset,
		CntrVal => loop_CntrVal,
		CntrEnd => loop_CntrEnd
	);
	--output signals assignments
	masked_data <= std_logic_vector(shift_right(unsigned(std_logic_vector(shift_left(unsigned(ZEROS_594&MASK),NBITS*to_integer(unsigned(mask_CntrVal)))) and xocram_data_a), NBITS*to_integer(unsigned(mask_CntrVal))));
	fifo_data <= masked_data(NBITS-1 downto 0);
	--fifo_wrreq <= '0' when to_integer(unsigned(mask_CntrVal)) = 0 else '1';
	
end architecture rtl;
