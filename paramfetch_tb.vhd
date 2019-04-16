library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

entity paramfetch_tb is
end entity paramfetch_tb;

architecture bench of paramfetch_tb is

	constant CLK_PER : time := 4 ns;
	constant NBITS : natural := 6;
	constant FRACBITS : natural := 4;
	constant	NBCONVREG : natural := 10;
	constant	NACC : natural := 11;
	constant	WGruOCRamWordSize : natural := 600;
	constant	WGruOCRamNbWords : natural := 3234;
	constant	UGruOCRamWordSize : natural := 600;
	constant	UGruOCRamNbWords : natural := 307;
	constant BURST_LENGTH : natural := 8;
	constant NB_BURSTS : natural := 625;
	constant	MAX_VAL_buffer : natural := 20;
	constant	MAX_VAL_conv : natural := 2;
	
	type paramSDRAM is array(5000 downto 0) of std_logic_vector(31 downto 0);
	signal SDRAMblock : paramSDRAM;
	
	signal clk_tb : std_logic :=  '0';
	signal rstB_tb : std_logic;
	
	signal AMburstcount_tb : std_logic_vector(3 downto 0);
	signal AMwaitrequest_tb : std_logic;
	signal AMreadEn_tb : std_logic;
	signal AMwriteEn_tb : std_logic;
	signal AMreaddata_tb : std_logic_vector(31 downto 0);
	signal AMwritedata_tb : std_logic_vector(31 downto 0);
	signal AMaddress_tb : std_logic_vector(31 downto 0);
	signal AMbyteenable_tb : std_logic_vector(3 downto 0);
	signal AMreaddatavalid_tb : std_logic;
		
		-- avalon slave
	signal ASreadEn_tb : std_logic;
	signal ASwriteEn_tb : std_logic;
	signal ASslaveAddr_tb : std_logic_vector(2 downto 0);
	signal ASreaddata_tb : std_logic_vector(31 downto 0);
	signal ASwritedata_tb : std_logic_vector(31 downto 0);

	signal DEBUG_OCRAMWdataIsNull_a_tb : std_logic;
	signal DEBUG_OCRAMUdataIsNull_a_tb : std_logic;
	signal DEBUG_OCRAMWdataIsNull_b_tb : std_logic;
	signal DEBUG_OCRAMUdataIsNull_b_tb : std_logic;
	
		

	constant TIME_DELTA : time := CLK_PER*10000;
	signal stop : boolean := false;
	
	
	procedure WRITE_IN_EXT_SDRAM
		(variable intData : in integer;
		 variable stdlvData: out std_logic_vector(31 downto 0)) is
	begin
		Y := std_logic_vector(to_unsigned(X, 32));
	end procedure WRITE_IN_EXT_SDRAM;
	
begin
	dut : entity work.accelerator(rtl)
	generic map(
		NBITS => NBITS,
		FRACBITS => FRACBITS,
		NBCONVREG  => NBCONVREG,
		NACC => NACC,
		WGruOCRamWordSize => WGruOCRamWordSize,
		WGruOCRamNbWords => WGruOCRamNbWords,
		UGruOCRamWordSize => UGruOCRamWordSize,
		UGruOCRamNbWords => UGruOCRamNbWords,
		BURST_LENGTH => BURST_LENGTH,
		NB_BURSTS => NB_BURSTS,
		MAX_VAL_buffer => MAX_VAL_buffer,
		MAX_VAL_conv => MAX_VAL_conv
	)
	port map(
		clk => clk_tb,
		rstB => rstB_tb,
		
		-- avalon master
		AMburstcount => AMburstcount_tb,
		AMwaitrequest => AMwaitrequest_tb,
		AMreadEn => AMreadEn_tb,
		AMwriteEn => AMwriteEn_tb,
		AMreaddata => AMreaddata_tb,
		AMwritedata => AMwritedata_tb,
		AMaddress => AMaddress_tb,
		AMbyteenable => AMbyteenable_tb,
		AMreaddatavalid => AMreaddatavalid_tb,
		
		-- avalon slave
		ASreadEn => ASreadEn_tb,
		ASwriteEn => ASwriteEn_tb,
		ASslaveAddr => ASslaveAddr_tb,
		ASreaddata => ASreaddata_tb,
		ASwritedata => ASwritedata_tb,

		DEBUG_OCRAMWdataIsNull_a => DEBUG_OCRAMWdataIsNull_a_tb,
		DEBUG_OCRAMUdataIsNull_a => DEBUG_OCRAMUdataIsNull_a_tb,
		DEBUG_OCRAMWdataIsNull_b => DEBUG_OCRAMWdataIsNull_b_tb,
		DEBUG_OCRAMUdataIsNull_b => DEBUG_OCRAMUdataIsNull_b_tb
	);

	
	clk_tb <= not clk_tb after CLK_PER/2 when not stop;
	rstB_tb <= '1', '0' after CLK_PER*1/4, '1' after CLK_PER*3/4;
	stop <= true after TIME_DELTA;
	process
		variable seed1, seed2 : positive;              -- seed values for random generator
		variable rand: real;   -- random real-number value in range 0 to 1.0  
		variable range_of_rand : real := 2.0**30-1.0;    -- the range of random values created will be 0 to +1000.
		variable RAMvector : std_logic_vector(31 downto 0);
		variable rand_num : integer;
	begin
		
		
		wait for 1*CLK_PER;
		AMwaitrequest_tb <= '0';
		AMreaddatavalid_tb <= '1';
		for i in 0 to 5000 loop
			uniform(seed1, seed2, rand);
			rand_num := integer(rand*range_of_rand);
			WRITE_IN_EXT_SDRAM(rand_num, RAMvector);
			SDRAMblock(i) <= RAMvector;
			--wait for 1*CLK_PER;
		end loop;
		
		wait for 1*CLK_PER;
		-- trigger the accelerator by writing to slave registers
		ASslaveAddr_tb <= "000";
		ASwriteEn_tb <= '1';
		ASwritedata_tb(0) <= '1';
		
		wait for 1*CLK_PER;
		wait for CLK_PER*1/2;
		-- set read address in SDRAM fro burst transfers
		ASslaveAddr_tb <= "010";
		ASwritedata_tb <= (others => '0');
		
		--wait for CLK_PER;

		ASwriteEn_tb <= '0';
		
		for i in 0 to 5000 loop
			AMreaddata_tb <= SDRAMblock(i);
			wait for CLK_PER;
		end loop;
		
		wait;--stop <= true;
		
		-- everything should be automatic from here : no more testbench input
	end process;
end architecture bench;