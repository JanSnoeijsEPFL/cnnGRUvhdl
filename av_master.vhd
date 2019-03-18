library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity av_master is
	generic(
		NBITS : natural := 6;
		FRACBITS : natural := 4
		);
	port(
	
		--avalon interface
		clk : in std_logic;
		rstB : in std_logic;
		burstcount : out std_logic_vector(3 downto 0);
		waitrequest : in std_logic;
		readEn : out std_logic;
		writeEn : out std_logic;
		readdata : in std_logic_vector(31 downto 0);
		writedata : out std_logic_vector(31 downto 0);
		addressRead : out std_logic_vector(31 downto 0);
		addressWrite : out std_logic_vector(31 downto 0);
		byteenable : out std_logic_vector(3 downto 0);
		
		--interface to slave
		ASReadAddr : in std_logic_vector(31 downto 0); -- read address in SDRAM for data fetching
		ASWriteAddr : in std_logic_vector(31 downto 0); -- write address in SDRAM for writing results of algorithm
		ASReadingActive: out std_logic; -- set to indicate Master is reading data from SDRAM	
		
		--dcfifo write interface
		FifoDataIn : out std_logic_vector(31 downto 0);
		FifoWrreq: out std_logic;
		FifoWrfull : in std_logic;
		
		--interface with control block
		CtrlFetchNNParam : in std_logic; --signal to allow reading parameters from SDRAM (should be kept at 1 for the whole duration)
		CtrlFetchRTData : in std_logic; --signal to allow fetching RT data
		CtrlFifoWriteAllow : in std_logic; -- allow writing data to FIFO
		CtrlFifoWriting : out std_logic; -- indicates data is being written in FIFO
		CtrlWriteResult : in std_logic; -- allows writing result to SDRAM
		CtrlReadingActive: out std_logic; -- set to indicate Master is reading data from SDRAM	
		CtrlBurstCntrEnd : out std_logic;
		CtrlNbBurstCntrEnd : out std_logic; -- tells controller when NbBursts completed
		CtrlInitState : in std_logic; -- controller is in init state if this signal equals to 1
		
		--interface with fifo_backend (FB)
		--FBReadingActive : out std_logic;
		--interface with classifier
		ClassSeqClass: in std_logic -- sequence classification result
		
		);
end entity av_master;

architecture rtl of av_master is
-- internal signals declaration
	--addrWriteReg, addrWriteNext: std_logic_vector(31 downto 0);
	ReadAddressReg, ReadAddressNext: std_logic_vector(31 downto 0);
	BurstCntrReg, BurstCntrNext: std_logic_vector(3 downto 0);
	NbBurstCntrReg, NbBurstCntrNext: std_logic_vector(9 downto 0);
	FifoWriting : std_logic;
	BurstCntrEn : std_logic;
	ReadingActive : std_logic;
begin 
	
	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			ReadAddressReg <= (others => '0');
			BurstCntrReg <= "1000"; --8
			NbBurstsCntrReg <= "1001101100"; --620
		elsif rising_edge(clk) then
			ReadAddressReg <= ReadAddressNext;
			BurstCntrReg <= BurstCntrNext;
			NbBurstCntrReg <= NbBurstCntrNext;
		end if;
	end process;
	
	BURST_CNTR: process(BurstCntrReg, BurstCntrEn)
	BurstCntrNext <= BurstCntrReg;
	begin
		if BurstCntrEn = '1' and BurstCntrReg /= "0000" then
			BurstCntrNext <= std_logic_vector(unsigned(BurstCntrReg)-1);
		elsif BurstCntrEn = '1' and BurstCntrReg = "0000" then
			BurstCntrNext <= (others => '1');
		end if;
	end process BURST_CNTR; 
	
	-- counters reaching threshold value
	BurstCntrEnd <= '1' when BurstCntrReg = "0000" else '0';
	CtrlNbBurstCntrEnd <= '1' when NbBurstCntrReg = "0000000000";
	CtrlBurstCntrEnd <= BurstCntrEnd;
	-- address update
	ADDR: process(ReadAddressReg, ASReadAddr, CtrlInitState)
	ReadAddressNext <= ReadAddressReg;
	begin
		if CtrlInitState = '1' then
			ReadAddressNext <= ASReadAddr;
		elsif BurstCntrEnd = '1' then
			ReadAddressNext <= std_logic_vector(unsigned(ReadAddressReg) + 8);
		end if;
	end process ADDR;
	--ReadAddressNext <= std_logic_vector(unsigned(ReadAddressReg) + 8) when BurstCntrEnd = '1' else ReadAddressReg;
	
	NB_BURSTS_CNTR: process(BurstCntrEnd, NbBurstCntrReg)
	NbBurstCntrNext <= NbBurstCntrReg;
	begin
		if BurstCntrEnd = '1' and NbBurstCntrReg /= "0000000000" then
			NbBurstCntrNext <= std_logic_vector(unsigned(NbBurstCntrReg)-1)
		elsif BurstTransferEnd = '1' and NbBurstCntrReg = "0000000000" then
			NbBurstCntrNext <= "1001101100";
		end if;
	end process NB_BURSTS_CNTR;
	
	BURST_READ : process(waitrequest, readdata, ReadAddressReg, FifoWriting, CtrlFetchNNparam, CtrlFetchRTData)
	readEn <= '0';
	byteeable <= "1111";
	burstcount <= "1000";
	addressRead <= (others => '0');
	ReadingActive <= '0';
	BurstCntrEn <= '0';
	begin -- all Ctrl signals should be synchronous
		if waitrequest = '0' and (CtrlFetchNNparam = '1' or CtrlFetchRTData = '1') then --if access granted from avalon
			if FifoWriting = '1' then -- if allowed access to FIFO we can fetch data
				readEn <= '1';
				addressRead <= ReadAddressReg;
				FifoDataIn <= readdata;
				ReadingActive <= '1';
				BurstCntrEn <= '1';
			end if;
		end if;
	end process BURST_READ;
	
	FifoWrclk <= clk;
	
	FIFO_CTRL : process(FifoWrfull, CtrlFifoAllow)
	FifoWrreq <= '0';
	FifoWriting <= '1';
	begin
		if FifoWrfull = '0' and CtrlFifoAllow = '1' then
			FifoWrreq <= '1';
			FifoWriting <= '1';
		end if;
	end process FIFO_CTRL;
	
	WRITE_ : process(clk, waitrequest, ClassSeqClass, CtrlWriteResult, ASWriteAddr)
	writeEn <= '0';
	byteenable <= "1111";
	addressWrite <= (others => '0');
	writedata <= (others => '0');
	begin
		if waitrequest = '0' and CtrlWriteResult = '1' then
			writeEn <= '1';
			addressWrite <= ASWriteAddr;
			writedata(0) <= ClassSeqClass;
		end if;
	end process WRITE_ ;
	
	-- output signals 
	CtrlFifoWriting <= FifoWriting;
	CtrlReadingActive <= ReadingActive;
	ASReadingActive <= ReadingActive;
	--FBReadingActive <= ReadingActive;
	
end architecture rtl;
		
		
		
		