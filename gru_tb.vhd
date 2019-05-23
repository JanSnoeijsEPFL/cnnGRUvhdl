library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

entity gru_tb is
end entity gru_tb;

architecture bench of gru_tb is

	constant NBITS : natural := 6;
	constant NBFRAC : natural := 4;
	constant NBCONVREG : natural := 10;
	constant MAC_MAX : natural := 100;
	constant NACC : natural := 11;
	constant RECUR_CNTR_MAX : natural := 10;
	constant RAM_LINE_SIZE : natural := 600;
	constant wGruOCRamWordSize : natural := 600;
	constant wGruOCRamNbWords : natural := 3234;
	constant wGRUlog2NBWords : natural := 12;
	constant uGruOCRamWordSize : natural := 600;
	constant uGruOCRamNbWords : natural := 307;
	constant uGRUlog2NBWords : natural := 9;
	constant xOCRamWordSize : natural := 600;
	constant xOCRamNbWords : natural := 46;
	constant xlog2NBWords : natural := 7;
	constant BURST_LENGTH : natural := 8;
	constant NB_BURSTS : natural := 625;
	constant MAX_VAL_buffer : natural := 19; --19
	constant MAX_VAL_conv : natural := 2;--2

	constant NBOUT : natural := 100;
	constant	DEBUG : natural := 0;
	constant	NBITS_DIV : natural := 16;
	constant	DENSE_BUFFER_SIZE : natural := 5;
	constant	DENSE_OUT : natural := 3;
	constant	NACC_DENSE : natural :=7;
	constant	U_DENSE_OFFSET : natural := 303;
	constant FRAC_LUT : natural := 11;
	constant CLK_PER : time := 20 ns;
	--type paramSDRAM is array(5000 downto 0) of std_logic_vector(31 downto 0);
	--signal SDRAMblock : paramSDRAM;
	
	signal clk_tb : std_logic :=  '0';
	signal rstB_tb : std_logic;
	
	signal	ASreadEn_tb : std_logic;
	signal	ASwriteEn_tb : std_logic;
	signal	ASslaveAddr_tb : std_logic_vector(2 downto 0);
	signal	ASreaddata_tb : std_logic_vector(31 downto 0);
	signal	ASwritedata_tb : std_logic_vector(31 downto 0);
		
	signal	uAddress_hps_tb : std_logic_vector(13 downto 0);
	signal	wAddress_hps_tb : std_logic_vector(16 downto 0);
	signal	xAddress_hps_tb : std_logic_vector(11 downto 0);
		
	signal	uDataIn_hps_tb : std_logic_vector(31 downto 0);
	signal	wDataIn_hps_tb : std_logic_vector(31 downto 0);
	signal	xDataIn_hps_tb : std_logic_vector(31 downto 0);
		
	signal	uDataOut_hps_tb : std_logic_vector(31 downto 0);
	signal	wDataOut_hps_tb : std_logic_vector(31 downto 0);
	signal	xDataOut_hps_tb : std_logic_vector(31 downto 0);
		
	signal	uWren_hps_tb : std_logic;
	signal	wWren_hps_tb : std_logic;
	signal	xWren_hps_tb : std_logic;
		
	signal	uReadEn_tb : std_logic;
	signal	wReadEn_tb : std_logic;
	signal	xReadEn_tb : std_logic;
	
		

	constant TIME_DELTA : time := CLK_PER*10000;
	signal stop : boolean := false;
	
begin
	dut : entity work.accelerator(rtl)
	generic map(
		NBITS => NBITS,
		NBFRAC => NBFRAC,
		NBCONVREG  => NBCONVREG,
		MAC_MAX => MAC_MAX,
		NACC => NACC,
		RECUR_CNTR_MAX => RECUR_CNTR_MAX,
		RAM_LINE_SIZE => RAM_LINE_SIZE,
		wGruOCRamWordSize => wGruOCRamWordSize,
		wGruOCRamNbWords => wGruOCRamNbWords,
		wGRUlog2NBWords => wGRUlog2NBWords,
		uGruOCRamWordSize => uGruOCRamWordSize,
		uGruOCRamNbWords => uGruOCRamNbWords,
		uGRUlog2NBWords => uGRUlog2NBWords,
		xOCRamWordSize => xOCRamWordSize,
		xOCRamNbWords => xOCRamNbWords,
		xlog2NBWords => xlog2NBWords,
		BURST_LENGTH => BURST_LENGTH,
		NB_BURSTS => NB_BURSTS,
		MAX_VAL_buffer => MAX_VAL_buffer,
		MAX_VAL_conv => MAX_VAL_conv
	)
	port map(
		clk => clk_tb,
		rstB => rstB_tb,

		-- avalon master
		-- avalon slave
		ASreadEn => ASreadEn_tb,
		ASwriteEn => ASwriteEn_tb,
		ASslaveAddr => ASslaveAddr_tb,
		ASreaddata => ASreaddata_tb,
		ASwritedata => ASwritedata_tb,
		
		uAddress_hps => uAddress_hps_tb,
		wAddress_hps => wAddress_hps_tb,
		xAddress_hps => xAddress_hps_tb,
		uDataIn_hps  => uDataIn_hps_tb,
		wDataIn_hps  => wDataIn_hps_tb,
		xDataIn_hps  => xDataIn_hps_tb,
		uDataOut_hps  => uDataOut_hps_tb,
		wDataOut_hps  => wDataOut_hps_tb,
		xDataOut_hps  => xDataOut_hps_tb,
		
		uWren_hps => uWren_hps_tb,
		wWren_hps => wWren_hps_tb,
		xWren_hps => xWren_hps_tb,
		uReadEn => uReadEn_tb,
		wReadEn => wReadEn_tb,
		xReadEn => xReadEn_tb
	);

	
	clk_tb <= not clk_tb after CLK_PER/2 when not stop;
	rstB_tb <= '1', '0' after CLK_PER*1/4, '1' after CLK_PER*3/4;
	--stop <= true after TIME_DELTA;
	process
		variable seed1, seed2 : positive;              -- seed values for random generator
		variable rand: real;   -- random real-number value in range 0 to 1.0  
		variable range_of_rand : real := 2.0**5-1.0;    -- the range of random values created will be 0 to +1000.
		variable RAMvector : std_logic_vector(31 downto 0);
		variable rand_num : integer;
	begin
		
		wait for CLK_PER*1/2;
		wait for 1*CLK_PER;
		--write in Conv2D reg:
		ASslaveAddr_tb <= "100";
		ASwriteEn_tb <= '1';
		ASwritedata_tb <= x"FEDCBA98";
		wait for 1*CLK_PER;
		ASslaveAddr_tb <= "101";
		ASwritedata_tb <= x"76543210";
		wait for 1*CLK_PER;
		ASwriteEn_tb <= '0';
		for i in 0 to 20*23-1 loop
			uniform(seed1, seed2, rand);
			rand_num := integer(rand*range_of_rand);
			xWren_hps_tb <= '1';
			if i = 0 or i = 1 then
				xDataIn_hps_tb <= "00000001000001000001000001000001";
			elsif i = 20 or i = 21 then
				xDataIn_hps_tb <= "00000011000011000011000011000011";
			else
				xDataIn_hps_tb <= std_logic_vector(to_unsigned(rand_num,xDataIn_hps_tb'length ));
			end if;
			xAddress_hps_tb <= std_logic_vector(to_unsigned(i/20*32+i mod 20, xAddress_hps_tb'length));
			wait for 1*CLK_PER;
		end loop;
		xWren_hps_tb <= '0';
		for i in 0 to 20*3234-1 loop
			uniform(seed1, seed2, rand);
			rand_num := integer(rand*range_of_rand);
			wWren_hps_tb <= '1';
			if i = 0 or i = 1 then
				wDataIn_hps_tb <= "00000001000001000001000001000001";
			elsif i = 20 or i = 21 then
				wDataIn_hps_tb <= "00000011000011000011000011000011";
			else
				wDataIn_hps_tb <= std_logic_vector(to_unsigned(rand_num,wDataIn_hps_tb'length ));
			end if;
			wAddress_hps_tb <= std_logic_vector(to_unsigned(i/20*32+i mod 20, wAddress_hps_tb'length));
			wait for 1*CLK_PER;
		end loop;
		wWren_hps_tb <= '0';
		for i in 0 to 20*307-1 loop
			uniform(seed1, seed2, rand);
			rand_num := integer(rand*range_of_rand);
			uWren_hps_tb <= '1';
			if i = 0 or i = 1 then
				uDataIn_hps_tb <= "00000001000001000001000001000001";
			elsif i = 20 or i = 21 then
				uDataIn_hps_tb <= "00000011000011000011000011000011";
			else
				uDataIn_hps_tb <= std_logic_vector(to_unsigned(rand_num, uDataIn_hps_tb'length ));
			end if;
			uAddress_hps_tb <= std_logic_vector(to_unsigned(i/20*32+i mod 20, uAddress_hps_tb'length));
			wait for 1*CLK_PER;
		end loop;
		uWren_hps_tb <= '0';
		wait for 2*CLK_PER;
		-- trigger the accelerator by writing to slave registers
		ASslaveAddr_tb <= "000";
		ASwriteEn_tb <= '1';
		ASwritedata_tb(1 downto 0) <= "11";
		
		wait for 1*CLK_PER;
		ASwriteEn_tb <= '0';
		wait for 50000*CLK_PER;
		ASwriteEn_tb <= '1';
		ASwritedata_tb(1 downto 0) <= "00";
		wait for 1*CLK_PER;
		ASwriteEn_tb <= '0';
		xReadEn_tb <= '1';
		wait for 1*CLK_PER;
	--	for i in 0 to 20*44-1 loop
		--	xAddress_hps_tb <= std_logic_vector(to_unsigned(i/20*32+i mod 20 + 23*32, xAddress_hps_tb'length));
	--		wait for 1*CLK_PER;
	--	end loop;
		stop <= true;
		wait;
		
		-- everything should be automatic from here : no more testbench input
	end process;
end architecture bench;