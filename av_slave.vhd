library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity av_slave is
	port(
		-- avalon interface
		clk : in std_logic;
		rstB : in std_logic;
		readEn : in std_logic;
		writeEn : in std_logic;
		regAddress : in std_logic_vector(2 downto 0);
		readdata : out std_logic_vector(31 downto 0);
		writedata : in std_logic_vector(31 downto 0)
		
		-- to avalon master
		AMWriteAddr : out std_logic_vector(31 downto 0);
		AMReadAddr : out std_logic_vector(31 downto 0);
		AMReadingActive: in std_logic; -- set to indicate Master is reading data from SDRAM	
		
		-- to controller
		CtrlNNParamset : out std_logic; -- set by proc to indicate parameters are ready in SDRAM
		CtrlRTDataReady: out std_logic; -- set by proc to indicate new RT data is ready in SDRAM
		CtrlStatusCtrller : in std_logic_vector(2 downto 0) -- status of controller for processor checks
	);
end entity av_slave;

architecture rtl of av_slave is
	-- avalon readable / writable registers
	signal NNParamsetReg, NNParamsetNext : std_logic;
	signal NNDataReadyReg, NNDataReadyNext : std_logic;
	signal ReadingActiveReg, ReadingActiveNext : std_logic;
	signal StatusCtrllerReg, StatusCtrllerNext : std_logic_vector(2 downto 0); -- not writable
	signal ReadAddressReg, ReadAddressNext : std_logic_vector(31 downto 0);
	signal WriteAddressReg, ReadAddressNext : std_logic_vector(31 downto 0);
	
begin
	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			NNParamsetReg <= '0';
			NNDataReadyReg <= '0';
			ReadingActiveReg <= '0';
			StatusCtrllerReg <= '0';
			ReadAddressReg <= '0';
			WriteAddressReg <= '0';
		elsif rising_edge(clk) then
			NNParamsetReg <= NNParamsetNext;
			NNDataReadyReg <= NNDataReadyNext;
			ReadingActiveReg <= ReadingActiveNext;
			StatusCtrllerReg <= StatusCtrllerNext;
			ReadAddressReg <= ReadAddressNext;
			WriteAddressReg <= WriteAddressNext;
		end if;
	end process REG;
	
	READ: process(readEn, NNParamsetReg, NNDataReadyReg,ReadingActiveReg, StatusCtrllerReg, ReadAddressReg, WriteAddressReg, regAddress) --processor wants to read a register
	begin
		-- default
		readdata <= (others => '0');
		if readEn = '1' then
			case regAddress is
				when "000" => readdata(0) <= NNParamsetReg;
								  readdata(1) <= NNDataReadyReg;
				when "001" => readdata(0) <= ReadingActiveReg;
								  readdata(3 downto 1) <= StatusCtrllerReg;
				when "010" => readdata <= ReadAddressReg;
				when "011" => readdata <= WriteAddressReg;
				when others => null;
			end case regAddress;
		end if;						  	
	end process READ;
	
	WRITE: process(writeEn, writedata, NNParamsetReg, NNDataReadyReg, ReadAddressReg, WriteAddressReg, regAddress) --processor wants to write a register
	begin
		-- default
		NNParamsetNext <= NNParamsetReg;
		NNDataReadyNext <= NNDataReadyReg;
		ReadAddressNext <= ReadAddressReg;
		WriteAddressNext <= WriteAddressReg;
		
		if writeEn = '1' then
			case regAddress is
				when "000" => NNParamsetNext <= writedata(0);
								  NNDataReadyNext <= writedata(1); 
				when "010" => ReadAddressNext <= writedata;
				when "011" => WriteAddressNext <= writedata;
			end case regAddress;
		end if;
	end process WRITE;
	
	-- status
	StatusCtrllerNext <= CtrlStatusCtrller;
	ReadingActiveNext <= AMReadingActive;
	
	-- output signals
	AMWriteAddr <= WriteAddressReg; 
	AMReadAddr <= ReadAddressReg;
	CtrlNNParamset <= NNParamsetReg;
	CtrlRTDataReady <= RTDataReadyReg;
end architecture rtl;