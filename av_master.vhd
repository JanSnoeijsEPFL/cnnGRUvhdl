library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity av_master is
	generic(
		NBITS : natural := 6;
		FRACBITS : natural := 4;
		BURST_LENGTH : natural := 8;
		NB_BURSTS : natural := 625
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
		address : out std_logic_vector(31 downto 0);
		byteenable : out std_logic_vector(3 downto 0);
		readdatavalid : in std_logic;
		
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
	signal ReadAddressReg, ReadAddressNext: std_logic_vector(31 downto 0);
	--signal BurstCntrReg, BurstCntrNext: std_logic_vector(3 downto 0);
	--signal NbBurstCntrReg, NbBurstCntrNext: std_logic_vector(9 downto 0);
	signal FifoWriting : std_logic;
	
	signal CntrBurstEnable : std_logic;
	signal CntrBurstEnd : std_logic;
	signal CntrBurstVal : std_logic_vector(integer(ceil(log2(real(BURST_LENGTH))))-1 downto 0);
	signal CntrBurstReset : std_logic;
	
	signal CntrNbBurstEnable : std_logic;
	signal CntrNbBurstEnd : std_logic;
	signal CntrNbBurstVal : std_logic_vector(integer(ceil(log2(real(NB_BURSTS))))-1 downto 0);
	signal CntrNbBurstReset : std_logic; 
	
	signal ReadingActive : std_logic;
	signal NbBurstCntrEnd : std_logic;
	
begin 
	
	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			ReadAddressReg <= (others => '0');
		elsif rising_edge(clk) then
			ReadAddressReg <= ReadAddressNext;
		end if;
	end process;
	
	burst_cntr_inst : entity work.counter(rtl)
	generic map(
		MAX_VAL => BURST_LENGTH
	)
	port map(
		clk => clk,
		rstB => rstB,
		CntrEnable => CntrBurstEnable,
		CntrReset => CntrBurstReset,
		CntrVal => CntrBurstVal,
		CntrEnd => CntrBurstEnd
	);
	
	nbburst_cntr_inst : entity work.counter(rtl)
	generic map(
		MAX_VAL => NB_BURSTS
	)
	port map(
		clk => clk,
		rstB => rstB,
		CntrEnable => CntrNbBurstEnable,
		CntrReset => CntrNbBurstReset,
		CntrVal => CntrNbBurstVal,
		CntrEnd => CntrNbBurstEnd
	);
	
	CntrBurstReset <= '0';
	CtrlBurstCntrEnd <= CntrBurstEnd;
	CtrlNbBurstCntrEnd <= CntrNbBurstEnd;
	-- address update
	ADDR: process(ReadAddressReg, ASReadAddr, CtrlInitState, CntrBurstEnd)
	begin
		ReadAddressNext <= ReadAddressReg;
		if CtrlInitState = '1' then
			ReadAddressNext <= ASReadAddr;
		elsif CntrBurstEnd = '1' then
			ReadAddressNext <= std_logic_vector(unsigned(ReadAddressReg) + 8);
		end if;
	end process ADDR;
	--ReadAddressNext <= std_logic_vector(unsigned(ReadAddressReg) + 8) when BurstCntrEnd = '1' else ReadAddressReg;
	
	CntrNbBurstEnable <= '1' when CntrBurstEnd = '1' else '0';
	CntrNbBurstReset <= '0';
	
	BURST_READ_WRITE : process(waitrequest, readdata, ReadAddressReg, FifoWriting, CtrlFetchNNparam, CtrlFetchRTData, ClassSeqClass, CtrlWriteResult, ASWriteAddr)
	begin -- all Ctrl signals should be synchronous
		readEn <= '0';
		writeEn <= '0';
		byteenable <= "1111";
		burstcount <= "1000";
		address <= (others => '0');
		writedata <= (others => '0');
		ReadingActive <= '0';
		CntrBurstEnable <= '0';
		FifoDataIn <= (others => '0');
		if (CtrlFetchNNparam = '1' or CtrlFetchRTData = '1') then --if access granted from avalon
			readEn <= '1';
			address <= ReadAddressReg;
			if readdatavalid = '1' and waitrequest = '1' then
				FifoDataIn <= readdata;
				ReadingActive <= '1';
				CntrBurstEnable <= '1';
			end if;
		elsif CtrlWriteResult = '1' and FifoWriting = '0' then
			writeEn <= '1';
			if waitrequest = '0' then
				address <= ASWriteAddr;
				writedata(0) <= ClassSeqClass;
			end if;
		end if;
	end process BURST_READ_WRITE;
	
	FIFO_CTRL : process(FifoWrfull, CtrlFifoWriteAllow)
	begin
		FifoWrreq <= '0';
		FifoWriting <= '0';
		if FifoWrfull = '0' and CtrlFifoWriteAllow = '1' then
			FifoWrreq <= '1';
			FifoWriting <= '1';
		end if;
	end process FIFO_CTRL;
	
	-- output signals 
	CtrlFifoWriting <= FifoWriting;
	CtrlReadingActive <= ReadingActive;
	ASReadingActive <= ReadingActive;
	--FBReadingActive <= ReadingActive;
	
end architecture rtl;
		
		
		
		