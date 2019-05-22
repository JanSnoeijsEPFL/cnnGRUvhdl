library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

entity dense_tb is
end entity dense_tb;

architecture bench of dense_tb is

	constant NBITS : natural := 6;
	constant RAM_LINE_SIZE : natural := 600;
	constant xlog2NBWords : natural := 7;
	constant NBOUT : natural := 100;
	constant	DEBUG : natural := 0;
	constant	NBITS_DIV : natural := 16;
	constant	DENSE_BUFFER_SIZE : natural := 5;
	constant	DENSE_OUT : natural := 3;
	constant	NACC_DENSE : natural :=7;
	constant	U_DENSE_OFFSET : natural := 303;
	constant NBFRAC : natural := 4;
	constant FRAC_LUT : natural := 11;
	constant ulogNbWords : natural := 9;
	constant CLK_PER : time := 20 ns;
	--type paramSDRAM is array(5000 downto 0) of std_logic_vector(31 downto 0);
	--signal SDRAMblock : paramSDRAM;
	type arr is array(0 to DENSE_OUT -1) of std_logic_vector(NBITS_DIV-1 downto 0);
	type s_arr is array(0 to NBOUT -1) of std_logic_vector(NBITS-1 downto 0);
	signal clk_tb : std_logic :=  '0';
	signal rstB_tb : std_logic;
	signal s_out_tb : std_logic_vector(NBOUT*NBITS-1 downto 0);
	signal dense_trigger_tb : std_logic;
	signal end_dense_tb : std_logic;
	signal uocram_addr_tb : std_logic_vector(ulogNbWords-1 downto 0);
	signal uocram_data_tb : std_logic_vector(RAM_LINE_SIZE-1 downto 0);
	signal y_out_tb : std_logic_vector(NBITS_DIV*DENSE_OUT-1 downto 0);
	signal y_out_arr_tb : arr;
	signal s_out_arr_tb : s_arr;
	constant TIME_DELTA : time := CLK_PER*10000;
	signal stop : boolean := false;
	
begin
	dut: entity work.dense(rtl)
	generic map(
	NBITS => NBITS,
		INPUTS => NBOUT,
		OUTPUTS => DENSE_OUT,
		BUFFER_SIZE => DENSE_BUFFER_SIZE,
		NBITS_DIV=> NBITS_DIV,
		RAM_LINE_SIZE => RAM_LINE_SIZE,
		U_DENSE_OFFSET => U_DENSE_OFFSET,
		NACC_DENSE => NACC_DENSE,
		NBFRAC => NBFRAC,
		FRAC_LUT => FRAC_LUT
	)
	port map(
		clk => clk_tb, 
		rstB => rstB_tb,
		s_final => s_out_tb,
		dense_trigger => dense_trigger_tb,
		end_dense => end_dense_tb,
		uocram_data => uocram_data_tb,
		uocram_addr => uocram_addr_tb,
		y_out => y_out_tb
	);
	
	clk_tb <= not clk_tb after CLK_PER/2 when not stop;
	rstB_tb <= '1', '0' after CLK_PER*1/4, '1' after CLK_PER*3/4;
	gen: for i in 0 to DENSE_OUT -1 generate
		y_out_arr_tb(i) <= y_out_tb( NBITS_DIV*i + NBITS_DIV-1 downto NBITS_DIV*i);
	end generate;
	gen2: for i in 0 to NBOUT-1 generate
		s_out_arr_tb(i) <= s_out_tb( NBITS*i + NBITS-1 downto NBITS *i);
	end generate;
	--stop <= true after TIME_DELTA;
	process
		variable seed1, seed2 : positive;              -- seed values for random generator
		variable rand: real;   -- random real-number value in range 0 to 1.0  
		variable range_of_rand : real := 2.0**5-1.0;   
		variable range_of_rand2 : real := 2.0**30-1.0;	-- the range of random values created will be 0 to +0b111111.
		variable RAMvector : std_logic_vector(31 downto 0);
		variable rand_num : integer;
	begin
		
		wait for CLK_PER*1/2;
		wait for 1*CLK_PER;
		for i in 0 to NBOUT-1 loop
			uniform(seed1, seed2, rand);
			rand_num := integer(rand*range_of_rand);
			s_out_tb(i*NBITS+NBITS-1 downto i*NBITS) <= std_logic_vector(to_unsigned(rand_num,6 ));
			uocram_data_tb(i*NBITS+NBITS-1 downto i*NBITS) <= std_logic_vector(to_unsigned(rand_num,6)); 
		end loop;
		dense_trigger_tb <= '1';
		wait for 1*CLK_PER;
		dense_trigger_tb <= '0';
		wait for 150*CLK_PER;
		stop <= true;
		wait;

	end process;
end architecture bench;