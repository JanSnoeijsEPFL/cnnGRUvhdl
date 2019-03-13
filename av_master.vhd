library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity av_master is
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
		ASReadAddrReg : in std_logic_vector(31 downto 0); -- read address in SDRAM for data fetching
		ASWriteAddrReg : in std_logic_vector(31 downto 0); -- write address in SDRAM for writing results of algorithm
		ASNNParamset : in std_logic; -- set by proc to indicate parameters are ready in SDRAM
		ASRTDataReady: in std_logic; -- set by proc to indicate new RT data is ready in SDRAM
		ASReadingActive: out std_logic; -- set to indicate Master is reading data from SDRAM	
		
		--dcfifo write interface
		FifoDataIn : out std_logic_vector(31 downto 0);
		FifoWrreq : out std_logic;
		FifoWrclk : out std_logic;
		FifoWrempty : in std_logic;
		FifoWrfull : in std_logic;
		FifoAclr : out std_logic;
		FifoWrusedw : in std_logic(31 downto 0);
		FifoEccstatus : in std_logic_vector (1 downto 0);
		FifoAlmostFull : in std_logic;
		
		--interface with control block
		CtrlFetchNNParam : in std_logic; --signal to allow reading parameters from SDRAM (should be kept at 1 for the whole duration)
		CtrlFetchRTData : in std_logic; --signal to allow fetching RT data
		CtrlFifoWriteAllow : in std_logic; -- allow writing data to FIFO
		CtrlFifoWriting : out std_logic; -- indicates data is being written in FIFO
		CtrlWriteResult : in std_logic; -- allows writing result to SDRAM
		CtrlReadingActive: out std_logic; -- set to indicate Master is reading data from SDRAM	
		
		--interface with classifier
		ClassSeqClass: in std_logic -- sequence classification result
		
		);
end entity av_master;

architecture rtl of av_master is
-- internal signals declaration
	readingActive;
	--addrWriteReg, addrWriteNext: std_logic_vector(31 downto 0);
	--addrReadReg, addrReadNext: std_logic_vector(31 downto 0);
	FifoWriting : std_logic;
	
begin 
	
	BURST_READ : process(waitrequest, readdata, ASAddrReadReg, FifoWriting, CtrlFetchNNparam, CtrlFetchRTData)
	read_en <= '0';
	byteeable <= "1111";
	burstcount <= "1000";
	addressRead <= (others => '0');
	ASReadingActive <= '0';
	begin -- all Ctrl signals should be synchronous
		if waitrequest = '0' and (CtrlFetchNNparam = '1' or CtrlFetchRTData = '1') then --if access granted from avalon
			if FifoWriting = '1' then -- if allowed access to FIFO we can fetch data
				readEn <= '1';
				addressRead <= ASReadAddrReg;
				FifoDataIn <= readdata;
				ASReadingActive <= '1';
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
	
	WRITE_ : process(clk, waitrequest, ClassSeqClass, CtrlWriteResult, ASWriteAddrReg)
	writeEn <= '0';
	byteenable <= "1111";
	addressWrite <= (others => '0');
	writedata <= (others => '0');
	begin
		if waitrequest = '0' and CtrlWriteResult = '1' then
			writeEn <= '1';
			addressWrite <= ASWriteAddrReg;
			writedata(0) <= ClassSeqClass;
		end if;
	end process WRITE_ ;
	
	--control signals
	CtrlFifoWriting <= FifoWriting;
end architecture rtl;
		
		
		
		