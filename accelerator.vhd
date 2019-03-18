library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity accelerator is
	generic(
		NBITS : natural := 6;
		FRACBITS : natural := 4;
		NACC : natural := 11;
		NBREG : natural := 59007
	);
	port(
		clk : in std_logic;
		rstB : in std_logic;
		
		-- avalon master
		AMburstcount : out std_logic_vector(3 downto 0);
		AMwaitrequest : in std_logic;
		AMreadEn : out std_logic;
		AMwriteEn : out std_logic;
		AMreaddata : in std_logic_vector(31 downto 0);
		AMwritedata : out std_logic_vector(31 downto 0);
		AMaddressRead : out std_logic_vector(31 downto 0);
		AMaddressWrite : out std_logic_vector(31 downto 0);
		AMbyteenable : out std_logic_vector(3 downto 0);
		
		-- avalon slave
		ASreadEn : in std_logic;
		ASwriteEn : in std_logic;
		ASregAddress : in std_logic_vector(2 downto 0);
		ASreaddata : out std_logic_vector(31 downto 0);
		ASwritedata : in std_logic_vector(31 downto 0)
	);
end entity accelerator;

architecture rtl of accelerator is
	
	-- AV master - AV slave
	ASReadAddr : std_logic_vector(31 downto 0); -- read address in SDRAM for data fetching
	ASWriteAddr : std_logic_vector(31 downto 0); -- write address in SDRAM for writing results of algorithm
	ASReadingActive: std_logic; -- set to indicate Master is reading data from SDRAM	
	
	--dcfifo write interface
	FifoDataIn : std_logic_vector(31 downto 0);
	FifoWrreq : std_logic;
	FifoWrclk : std_logic;
	FifoWrempty : std_logic;
	FifoWrfull : std_logic;
	
	--dcfifo read interface
	FifoDataOut : std_logic_vector(31 downto 0);
	FifoRdreq : std_logic;
	FifoRdclk : std_logic;
	FifoRdempty : std_logic;
	
	--AV master - Controller
	CtrlFetchNNParam : std_logic; --signal to allow reading parameters from SDRAM (should be kept at 1 for the whole duration)
	CtrlFetchRTData : std_logic; --signal to allow fetching RT data
	CtrlFifoWriteAllow : std_logic; -- allow writing data to FIFO
	CtrlFifoWriting : std_logic; -- indicates data is being written in FIFO
	CtrlWriteResult : std_logic; -- allows writing result to SDRAM
	CtrlReadingActive: std_logic; -- set to indicate Master is reading data from SDRAM	
	CtrlBurstCntrEnd : std_logic;
	CtrlNbBurstCntrEnd : std_logic; -- tells controller when NbBursts completed
	CtrlInitState : std_logic; -- controller is in init state if this signal equals to 1
	
	--av slave - controller
	CtrlNNParamset : std_logic; -- set by proc to indicate parameters are ready in SDRAM
	CtrlRTDataReady:  std_logic; -- set by proc to indicate new RT data is ready in SDRAM
	CtrlStatusCtrller : std_logic_vector(2 downto 0) -- status of controller for processor checks
	
	-- fifo backend
	ParamRegFileDataIn : std_logic_vector((NBITS-1)*NBITS-1 downto 0);
	ParamRegFileWriteEn : std_logic;
	ParamRegFileRegNumber : std_logic_vector(integer(ceil(log2(real(NBREG))))-1 downto 0);
	
	XRegFileDataIn : std_logic_vector((NBITS-1)*NBITS-1 downto 0);
	XRegFileWriteEn : std_logic_vector((NBITS-1)*NBITS-1 downto 0);
	-- signal from classifier
	ClassSeqClass: std_logic; -- sequence classification result
	
	component fifo_1
		port
		(
			data		: in std_logic_vector(31 downto 0);
			rdclk		: in std_logic ;
			rdreq		: in std_logic ;
			wrclk		: in std_logic ;
			wrreq		: in std_logic ;
			q		: out std_logic_vector(31 downto 0);
			rdempty		: out std_logic ;
			wrfull		: out std_logic 
		);
	end component;

end component;
begin
	fifo_1_inst : fifo_1 port map (
		data	 => FifoDataIn,
		rdclk	 => clk,
		rdreq	 => FifoRdreq,
		wrclk	 => clk,
		wrreq	 => FifoWrreq,
		q	 => FifoDataOut,
		rdempty	 => FifoRdempty,
		wrfull	 => FifoWrfull
	);
	
	av_master_inst : entity work.av_master(rtl) 
	generic map(
		NBITS => NBITS,
		FRACBITS => FRACBITS
		)
	port map(
		--avalon interface
		clk => clk,
		rstB => rstB,
		burstcount => AMburstcount,
		waitrequest => AMwaitrequest
		readEn => AMreadEn,
		writeEn => AMwriteEn,
		readdata => AMreaddata,
		writedata => AMwritedata,
		addressRead => AMaddressRead,
		addressWrite => AMaddressWrite,
		byteenable => AMbyteenable,
		
		ASReadAddr => ASReadAddr,
		ASWriteAddr => ASWriteAddr,
		ASReadingActive => ASReadingActive,
		
		FifoDataIn => FifoDataIn,
		FifoWrreq => FifoWrreq,
		FifoWrfull => FifoWrfull,

		CtrlFetchRTData => CtrlFetchRTData,
		CtrlFifoWriteAllow => CtrlFifoWriteAllow,
		CtrlFifoWriting => CtrlFifoWriting,
		CtrlWriteResult => CtrlWriteResult,
		CtrlReadingActive => CtrlReadingActive,
		CtrlBurstCntrEnd => CtrlBurstCntrEnd,
		CtrlNbBurstCntrEnd => CtrlNbBurstCntrEnd,
		CtrlInitState => CntrlInitState,
		ClassSeqClass => ClassSeqClass
		);
	
	av_slave_inst : entity work.av_slave(rtl)
	port map(
		clk => clk,
		rstB => rstB,
		readEn => ASreadEn,
		writeEn => ASwriteEn,
		regAddress => ASregAddress,
		readdata => ASreaddata,
		writedata => ASwritedata,
	
		AMWriteAddr => ASWriteAddr,
		AMReadAddr => ASWriteAddr,
		AMReadingActive => ASReadingActive,	
		
		CtrlNNParamset => CtrlNNParamset,
		CtrlRTDataReady => CtrlRTDataReady,
		CtrlStatusCtrller => CtrlStatusCtrller	
	);
	
	fifo_backend_inst : entity work.fifo_backend(rtl)
	generic map(
		NBITS => NBITS,
		FRACBITS => FRACBITS,
		NBREG => NBREG
	)
	port map(
		clk => clk,
		rstB => rstB,
		
		FifoDataOut => FifoDataOut,
		FifoRdreq => FifoRdreq,
		FifoRdempty => FifoRdempty,
	
		ParamRegFileDataIn => ParamRegFileDataIn,
		ParamRegFileWriteEn => ParamRegFileWriteEn,
		ParamRegFileRegNumber => ParamRegFileRegNumber,
	
		XRegFileDataIn => XRegFileDataIn,
		XRegFileWriteEn => XRegFileWriteEn,

		CtrlStatusCtrller => CtrlStatusCtrller
	);
	
	controller_inst : entity work.controller(rtl)
	generic map(
		NBITS => NBITS,
		FRACBITS => FRACBITS,
		NBREG => NBREG
	)
	port map(
		clk => clk,
		rstB => rstB,
		
		ASNNParamSet => CtrlNNParamSet;
		ASRTDataReady => CtrlDataready;
		ASStatusCtrller => CtrlStatusCtrller;
		
		AMFetchNNParam => CtrlFetchNNParam,
		AMFetchRTData => CtrlFecthRTData,
		AMFifoWriteAllow => CtrlFifoWriteAllow,
		AMFifoWriting => CtrlFifoWriting,
		AMWriteResult => CtrlWriteResult,
		AMReadingActive => CtrlReadingActive,
		AMBurstCntrEnd => CtrlBurstCntrEnd,
		AMNbBurstCntrEnd => CtrlNbBurstCntrEnd,
		AMCtrlInitState => CtrlInitState,
		
		FifoRdempty => FifoRdempty,
		
		FBStatusCtrller => CtrlStatusCtrller
	);
end architecture rtl;
