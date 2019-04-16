library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

entity ocram_tb is
end entity ocram_tb;

architecture bench of ocram_tb is

	constant	NBITS : natural := 6;
	constant	FRACBITS : natural := 4;
	constant	NBCONVREG : natural := 10;
	constant	NACC : natural := 11;
	constant	wGruOCRamWordSize : natural := 600;
	constant	wGruOCRamNbWords : natural := 3234;
	constant	wGRUlog2NBWords : natural := 12;
	constant	uGruOCRamWordSize : natural := 600;
	constant	uGruOCRamNbWords : natural := 307;
	constant	uGRUlog2NBWords : natural := 9;
	constant	xOCRamWordSize : natural := 600;
	constant	xOCRamNbWords : natural := 46;
	constant	xlog2NBWords : natural := 6;
	constant	BURST_LENGTH : natural := 8;
	constant	NB_BURSTS : natural := 625;
	constant	MAX_VAL_buffer : natural := 19; --19
	constant	MAX_VAL_conv : natural := 2;
	constant CLK_PER : time := 10 ns;
			-- avalon slave
	signal ASreadEn_tb : std_logic;
	signal ASwriteEn_tb : std_logic;
	signal	ASslaveAddr_tb : std_logic_vector(2 downto 0);
	signal	ASreaddata_tb : std_logic_vector(31 downto 0);
	signal	ASwritedata_tb : std_logic_vector(31 downto 0);
		
	signal	uAddress_hps_tb : std_logic_vector(13 downto 0);
	signal	wAddress_hps_tb : std_logic_vector(16 downto 0);
	signal	xAddress_hps_tb : std_logic_vector(10 downto 0);
		
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
	
	signal clk_tb : std_logic := '0';
	signal rstB_tb : std_logic;
	signal stop : boolean := false;
	
	procedure write_to_ocram
		(variable X : in integer;
		variable Y: out std_logic_vector(31 downto 0)) is
	begin
		Y := std_logic_vector(to_unsigned(X, 32));
	end procedure write_to_ocram;
begin
	
	clk_tb <= not clk_tb after CLK_PER/2 when not stop;
	rstB_tb <= '1', '0' after CLK_PER*1/4, '1' after CLK_PER*3/4;
	
	dut: entity work.accelerator(rtl)
	generic map(
		NBITS => NBITS,
		FRACBITS => FRACBITS,
		NBCONVREG  => NBCONVREG,
		NACC => NACC,
		wGruOCRamWordSize => wGruOCRamWordSize,
		wGruOCRamNbWords => wGruOCRamNbWords,
		wGRUlog2NBWords => wGRUlog2NBWords,
		uGruOCRamWordSize => uGruOCRamWordSize,
		uGruOCRamNbWords => uGruOCRamNbWords,
		uGRUlog2NBWords => uGRUlog2NBWords,
		xOCRamWordSize => xOCRamWordSize,
		xOCRamNbWords => xOCRamNbWords,
		BURST_LENGTH => BURST_LENGTH,
		xlog2NBWords => xlog2NBWords,
		NB_BURSTS => NB_BURSTS,
		MAX_VAL_buffer => MAX_VAL_buffer,
		MAX_VAL_conv => MAX_VAL_conv
	)
	port map(
		clk => clk_tb,
		rstB => rstB_tb,
	
		-- avalon slave
		ASreadEn => ASreadEn_tb,
		ASwriteEn => ASwriteEn_tb,
		ASslaveAddr => ASslaveAddr_tb,
		ASreaddata => ASreaddata_tb,
		ASwritedata => ASwritedata_tb,
		
		uAddress_hps => uAddress_hps_tb,
		wAddress_hps => wAddress_hps_tb,
		xAddress_hps => xAddress_hps_tb,
		
		uDataIn_hps => uDataIn_hps_tb,
		wDataIn_hps => wDataIn_hps_tb,
		xDataIn_hps => xDataIn_hps_tb,
		
		uDataOut_hps => uDataOut_hps_tb,
		wDataOut_hps => wDataOut_hps_tb,
		xDataOut_hps => xDataOut_hps_tb,
		
		uWren_hps => uWren_hps_tb,
		wWren_hps => wWren_hps_tb,
		xWren_hps => xWren_hps_tb,
		
		uReadEn => uReadEn_tb,
		wReadEn => wReadEn_tb,
		xReadEn => wReadEn_tb
	);
		
		
	process
	
		variable seed1, seed2 : positive;              -- seed values for random generator
		variable rand: real;   -- random real-number value in range 0 to 1.0  
		variable range_of_rand : real := 2.0**31-1.0;    -- the range of random values created will be 0 to +1000.
		variable datavect : std_logic_vector(31 downto 0);
		variable rand_num : integer;
	begin
		-- DISABLE all write / read signals
		wait for CLK_PER/2;

		uWren_hps_tb <= '0';
		wWren_hps_tb <= '0';
		xWren_hps_tb <= '0';
		uReadEn_tb <= '0';
		wReadEn_tb <= '0';
		xReadEn_tb <= '0';
		wait for CLK_PER;
		--write in w_ocRAM
		wWren_hps_tb <= '1';
		for i in 0 to 500 loop
			uniform(seed1, seed2, rand);
			rand_num := integer(rand*range_of_rand);
			write_to_ocram(rand_num, datavect);
			if i = 5 then
				wWren_hps_tb <= '0';
			elsif i = 6 then
				wWren_hps_tb <= '1';
			end if;
			uDataIn_hps_tb <= datavect;
			wDataIn_hps_tb <= datavect;
			wAddress_hps_tb <= std_logic_vector(to_unsigned(i,17)); -- invalid addresses here. see what happens
			wait for CLK_PER;
		end loop;
		wWren_hps_tb <= '0';
		uWren_hps_tb <= '1';
		wait for CLK_PER;
		-- check what happens during this cycle
		--for i in 0 to 6139 loop --oc ram should be full
			--uniform(seed1, seed2, rand);
			--rand_num := integer(rand*range_of_rand);
			--write_to_ocram(rand_num, datavect);
			--uDataIn_hps_tb <= datavect;
			--uAddress_hps_tb(4 downto 0) <= std_logic_vector(to_unsigned(i mod 20, 5)); -- only correct addresses
			--uAddress_hps_tb(13 downto 5) <= std_logic_vector(to_unsigned(i/20, 9));
			--wait for CLK_PER;
		--end loop;
	--	uAddress_hps_tb <= (others => '0');
			-- should overwrite 1st value
		--wait for CLK_PER;
	
		--uWren_hps_tb <= '0';
		--xWren_hps_tb <= '1';
		
--		for i in 0 to 50 loop --oc ram should be full
	--		uniform(seed1, seed2, rand);
		--	rand_num := integer(rand*range_of_rand);
			--write_to_ocram(rand_num, datavect);
			--xDataIn_hps_tb <= datavect;
			--xAddress_hps_tb(4 downto 0) <= std_logic_vector(to_unsigned(i mod 20, 5)); -- only correct addresses
			--xAddress_hps_tb(10 downto 5) <= std_logic_vector(to_unsigned(i/20, 6));
			--wait for CLK_PER;
		--end loop;
		stop <= true;
		wait;
	end process;
end architecture bench;