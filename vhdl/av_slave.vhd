library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity av_slave is
	generic(
		NBITS : natural := 6;
		NBITS_DIV : natural := 16;
		OUT_DENSE : natural := 3
		);
	port(
		-- avalon interface
		clk : in std_logic;
		rstB : in std_logic;
		readEn : in std_logic;
		writeEn : in std_logic;
		slaveAddr : in std_logic_vector(2 downto 0);
		readdata : out std_logic_vector(31 downto 0);
		writedata : in std_logic_vector(31 downto 0);
		
		-- to avalon master
		--AMWriteAddr : out std_logic_vector(31 downto 0);
		--AMReadAddr : out std_logic_vector(31 downto 0);
	
		-- to controller
		start_algo : out std_logic; -- set by proc to indicate parameters are ready in SDRAM
		algo_state : in std_logic_vector(2 downto 0);
		hps_write_new_batch : in std_logic;
		hps_DEBUG_read : in std_logic;
		
		--to convreg
		ConvIn : out std_logic_vector(10*NBITS-1 downto 0);
		ConvOut : in std_logic_vector(10*NBITS-1 downto 0);
		ConvWriteEn : out std_logic_vector(10-1 downto 0);
		xOCRAM_b_mode : out std_logic;
		res_final : in std_logic_vector(NBITS_DIV*OUT_DENSE-1 downto 0)
		
		);
		
end entity av_slave;

architecture rtl of av_slave is
	-- avalon readable / writable registers
	signal start_algoReg, start_algoNext : std_logic;
	signal xOCRAM_b_modeReg, xOCRAM_b_modeNext : std_logic;
	signal algoStateReg, algoStateNext : std_logic_vector(2 downto 0); -- not writable
	signal ReadAddressReg, ReadAddressNext : std_logic_vector(31 downto 0);
	signal WriteAddressReg, WriteAddressNext : std_logic_vector(31 downto 0);
	signal hps_ram_trigReg, hps_ram_trigNext : std_logic_vector(1 downto 0);
	type res_arr is array(0 to OUT_DENSE-1) of std_logic_vector(NBITS_DIV-1 downto 0);
	signal resReg, resNext : res_arr;
	signal resIndexReg, resIndexNext : std_logic_vector(1 downto 0);
	
begin
	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			start_algoReg <= '0';
			xOCRAM_b_modeReg <= '0';
			algoStateReg <= (others => '0');
			ReadAddressReg <= (others => '0');
			WriteAddressReg <= (others => '0');
			hps_ram_trigReg <= (others => '0');
			resReg <= (others => (others => '0'));
			resIndexReg <= (others => '0');
		elsif rising_edge(clk) then
			start_algoReg <= start_algoNext;
			xOCRAM_b_modeReg <= xOCRAM_b_modeNext;
			algoStateReg <= algoStateNext;
			ReadAddressReg <= ReadAddressNext;
			WriteAddressReg <= WriteAddressNext;
			hps_ram_trigReg <= hps_ram_trigNext;
			resReg <= resNext;
			resIndexReg <= resIndexNext;
		end if;
	end process REG;

	READING: process(readEn, hps_ram_trigReg, xOCRAM_b_modeReg, start_algoReg, 
							ReadAddressReg, WriteAddressReg, slaveAddr, ConvOut, resReg, resIndexReg) --processor wants to read a register
	begin
		-- default
		readdata <= (others => '0');
		if readEn = '1' then
			case slaveAddr is
				when "000" => 
					readdata(0) <= start_algoReg;
					readdata(1) <= xOCRAM_b_modeReg;
				when "001" => 
					readdata(1 downto 0) <= hps_ram_trigReg;
				when "010" => 
					readdata <= ReadAddressReg;
				when "011" => 
					readdata <= WriteAddressReg;
				when "100" =>
					readdata(29 downto 0) <= ConvOut(5*6-1 downto 0);
				when "101" =>
					readdata(29 downto 0) <= ConvOut(10*6-1 downto 5*6);
				when "110" => 
					readdata(NBITS_DIV-1 downto 0) <= resReg(to_integer(unsigned(resIndexReg)));
				when others =>
					readdata <= (others => '0');	
			end case;
		end if;						  	
	end process READING;
	
	WRITING: process(writeEn, writedata, start_algoReg, xOCRAM_b_modeReg,
						ReadAddressReg, WriteAddressReg, slaveAddr, resIndexReg) --processor wants to write a register
	begin
		-- default
		start_algoNext <= start_algoReg;
		xOCRAM_b_modeNext <= xOCRAM_b_modeReg;
		ReadAddressNext <= ReadAddressReg;
		WriteAddressNext <= WriteAddressReg;
		resIndexNext <= resIndexReg;
		ConvWriteEn <= (others => '0');
		ConvIn <= (others => '0');
		if writeEn = '1' then
			case slaveAddr is
				when "000" => 
					start_algoNext <= writedata(0);
					xOCRAM_b_modeNext <= writedata(1); 
				when "010" => 
					ReadAddressNext <= writedata;
				when "011" => 
					WriteAddressNext <= writedata;
				when "100" =>
					ConvWriteEn(4 downto 0) <= (others => '1');
					ConvWriteEn(9 downto 5) <= (others => '0');
					ConvIn(5*6-1 downto 0) <= writedata(29 downto 0);
				when "101" =>
					ConvWriteEn(4 downto 0) <= (others => '0');
					ConvWriteEn(9 downto 5) <= (others => '1');
					ConvIn(10*6-1 downto 5*6) <= writedata(29 downto 0);
				when "110" =>
					resIndexNext <= writedata(1 downto 0);
				when others =>
					null;
			end case;
		end if;
	end process WRITING;
	
	-- status
	res_gen: for i in 0 to OUT_DENSE-1 generate
		resNext(i) <= res_final(NBITS_DIV*i + NBITS_DIV-1 downto NBITS_DIV*i );
	end generate;
	algoStateNext <= algo_state;
	hps_ram_trigNext <= hps_DEBUG_read & hps_write_new_batch;
	-- output signals
	--AMWriteAddr <= WriteAddressReg; 
	--AMReadAddr <= ReadAddressReg;
	start_algo <= start_algoReg;
	xOCRAM_b_mode <= xOCRAM_b_modeReg;
end architecture rtl;
