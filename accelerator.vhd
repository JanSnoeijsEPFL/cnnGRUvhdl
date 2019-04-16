library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity accelerator is
	generic(
		NBITS : natural := 6;
		FRACBITS : natural := 4;
		NBCONVREG : natural := 10;
		MAC_MAX : natural := 100;
		NACC : natural := 11;
		wGruOCRamWordSize : natural := 600;
		wGruOCRamNbWords : natural := 3234;
		wGRUlog2NBWords : natural := 12;
		uGruOCRamWordSize : natural := 600;
		uGruOCRamNbWords : natural := 307;
		uGRUlog2NBWords : natural := 9;
		xOCRamWordSize : natural := 600;
		xOCRamNbWords : natural := 46;
		xlog2NBWords : natural := 6;
		BURST_LENGTH : natural := 8;
		NB_BURSTS : natural := 625;
		MAX_VAL_buffer : natural := 19; --19
		MAX_VAL_conv : natural := 2--2
	);
	port(
		clk : in std_logic;
		rstB : in std_logic;
		
		-- avalon master
		--AMburstcount : out std_logic_vector(3 downto 0);
		--AMwaitrequest : in std_logic;
		--AMreadEn : out std_logic;
		--AMwriteEn : out std_logic;
		--AMreaddata : in std_logic_vector(31 downto 0);
		--AMwritedata : out std_logic_vector(31 downto 0);
		--AMaddress : out std_logic_vector(31 downto 0);
		--AMbyteenable : out std_logic_vector(3 downto 0);
		--AMreaddatavalid : in std_logic;
		
		-- avalon slave
		ASreadEn : in std_logic;
		ASwriteEn : in std_logic;
		ASslaveAddr : in std_logic_vector(2 downto 0);
		ASreaddata : out std_logic_vector(31 downto 0);
		ASwritedata : in std_logic_vector(31 downto 0);
		
		uAddress_hps : in std_logic_vector(13 downto 0);
		wAddress_hps : in std_logic_vector(16 downto 0);
		xAddress_hps : in std_logic_vector(10 downto 0);
		
		uDataIn_hps : in std_logic_vector(31 downto 0);
		wDataIn_hps : in std_logic_vector(31 downto 0);
		xDataIn_hps : in std_logic_vector(31 downto 0);
		
		uDataOut_hps : out std_logic_vector(31 downto 0);
		wDataOut_hps : out std_logic_vector(31 downto 0);
		xDataOut_hps : out std_logic_vector(31 downto 0);
		
		uWren_hps : in std_logic;
		wWren_hps : in std_logic;
		xWren_hps : in std_logic;
		
		uReadEn : in std_logic;
		wReadEn : in std_logic;
		xReadEn : in std_logic
		-- to accelerator

	);
end entity accelerator;

architecture rtl of accelerator is
	
	constant OCramdataZero: std_logic_vector := std_logic_vector(to_unsigned(0, wGruOCRamWordSize)); 
	-- AV master - AV slave
	signal ASReadAddr : std_logic_vector(31 downto 0); -- read address in SDRAM for data fetching
	signal ASWriteAddr : std_logic_vector(31 downto 0); -- write address in SDRAM for writing results of algorithm
	signal ASReadingActive: std_logic; -- set to indicate Master is reading data from SDRAM	
	
	--dcfifo write interface
	signal FifoDataIn : std_logic_vector(31 downto 0);
	signal FifoWrreq : std_logic;
	signal FifoWrclk : std_logic;
	signal FifoWrempty : std_logic;
	signal FifoWrfull : std_logic;
	
	--dcfifo read interface
	signal FifoDataOut : std_logic_vector(31 downto 0);
	signal FifoRdreq : std_logic;
	signal FifoRdclk : std_logic;
	signal FifoRdempty : std_logic;
	
	--AV master - Controller
	signal CtrlFetchNNParam : std_logic; --signal to allow reading parameters from SDRAM (should be kept at 1 for the whole duration)
	signal CtrlFetchRTData : std_logic; --signal to allow fetching RT data
	signal CtrlFifoWriteAllow : std_logic; -- allow writing data to FIFO
	signal CtrlFifoWriting : std_logic; -- indicates data is being written in FIFO
	signal CtrlWriteResult : std_logic; -- allows writing result to SDRAM
	signal CtrlReadingActive: std_logic; -- set to indicate Master is reading data from SDRAM	
	signal CtrlBurstCntrEnd : std_logic;
	signal CtrlNbBurstCntrEnd : std_logic; -- tells controller when NbBursts completed
	signal CtrlInitState : std_logic; -- controller is in init state if this signal equals to 1
	signal CtrlFifoReadParam : std_logic;
	
	--av slave - controller
	signal CtrlNNParamset : std_logic; -- set by proc to indicate parameters are ready in SDRAM
	signal CtrlRTDataReady:  std_logic; -- set by proc to indicate new RT data is ready in SDRAMA
	signal CtrlStatusCtrller : std_logic_vector(2 downto 0); -- status of controller for processor checks
	
	--conv regfile
	signal ConvRegIn : std_logic_vector(NBCONVREG*NBITS-1 downto 0);
	signal ConvRegOut : std_logic_vector(NBCONVREG*NBITS-1 downto 0);
	signal ConvWriteEn : std_logic_vector(NBCONVREG-1 downto 0);

	-- signal from classifier
	signal ClassSeqClass: std_logic; -- sequence classification result
	
	signal uAddress_acc : std_logic_vector(8 downto 0) := (others => '0');
	signal wAddress_acc : std_logic_vector(11 downto 0) := (others => '0');
	signal xAddress_acc : std_logic_vector(5 downto 0) := (others => '0');
		
	signal uDataIn_acc : std_logic_vector(599 downto 0) := (others => '0');
	signal wDataIn_acc : std_logic_vector(599 downto 0) := (others => '0');
	signal xDataIn_acc : std_logic_vector(599 downto 0) := (others => '0');
		
	signal uDataOut_acc : std_logic_vector(599 downto 0);
	signal wDataOut_acc : std_logic_vector(599 downto 0);
	signal xDataOut_acc : std_logic_vector(599 downto 0);
		
	signal uWren_acc : std_logic := '0';
	signal wWren_acc : std_logic := '0';
	signal xWren_acc : std_logic := '0';
	
	--signal IntRegNb : integer;
	---component fifo_1
	--	port
	--	(
	--		data		: in std_logic_vector(31 downto 0);
	--		rdclk		: in std_logic ;
	---	rdreq		: in std_logic ;
	---		wrclk		: in std_logic ;
	--		wrreq		: in std_logic ;
	--		q		: out std_logic_vector(31 downto 0);
	---		rdempty		: out std_logic ;
	--		wrfull		: out std_logic 
	--	);
	--end component;

begin
	--fifo_1_inst : fifo_1 port map (
	--	data	 => FifoDataIn,
	--	rdclk	 => clk,
	--	rdreq	 => FifoRdreq,
	--	wrclk	 => clk,
	--	wrreq	 => FifoWrreq,
	--	q	 => FifoDataOut,
	--	rdempty	 => FifoRdempty,
	--	wrfull	 => FifoWrfull
	--);
	
	--av_master_inst : entity work.av_master(rtl) 
--	generic map(
	--	NBITS => NBITS,
	--	FRACBITS => FRACBITS,
	--	BURST_LENGTH => BURST_LENGTH,
		--NB_BURSTS => NB_BURSTS
	--	)
	--port map(
		--avalon interface
		--clk => clk,
		--rstB => rstB,
		--burstcount => AMburstcount,
		--waitrequest => AMwaitrequest,
		--readEn => AMreadEn,
		--writeEn => AMwriteEn,
		--readdata => AMreaddata,
		--writedata => AMwritedata,
		--address => AMaddress,
		--byteenable => AMbyteenable,
		--readdatavalid => AMreaddatavalid,
		--ASReadAddr => ASReadAddr,
		--ASWriteAddr => ASWriteAddr,
		--ASReadingActive => ASReadingActive,
		
		--FifoDataIn => FifoDataIn,
		--FifoWrreq => FifoWrreq,
		--FifoWrfull => FifoWrfull,
		
		--CtrlFetchNNParam => CtrlFetchNNParam,
		--CtrlFetchRTData => CtrlFetchRTData,
		--CtrlFifoWriteAllow => CtrlFifoWriteAllow,
		--CtrlFifoWriting => CtrlFifoWriting,
		--CtrlWriteResult => CtrlWriteResult,
		--CtrlReadingActive => CtrlReadingActive,
		--CtrlBurstCntrEnd => CtrlBurstCntrEnd,
		--CtrlNbBurstCntrEnd => CtrlNbBurstCntrEnd,
		--CtrlInitState => CtrlInitState,
		--ClassSeqClass => ClassSeqClass
	--	);
	
	av_slave_inst : entity work.av_slave(rtl)
	port map(
		clk => clk,
		rstB => rstB,
		readEn => ASreadEn,
		writeEn => ASwriteEn,
		slaveAddr => ASslaveAddr,
		readdata => ASreaddata,
		writedata => ASwritedata,
	
		AMWriteAddr => ASWriteAddr,
		AMReadAddr => ASReadAddr,
		AMReadingActive => ASReadingActive,	
		
		CtrlNNParamset => CtrlNNParamset,
		CtrlRTDataReady => CtrlRTDataReady,
		CtrlStatusCtrller => CtrlStatusCtrller,
		
		ConvIn => ConvRegIn,
		ConvOut => ConvRegOut,
		ConvWriteEn => ConvWriteEn
	);
	
	--fifo_backend_inst : entity work.fifo_backend(rtl)
	--generic map(
	--	NBITS => NBITS,
	--	FRACBITS => FRACBITS,
	--	NBCONVREG => NBCONVREG,
	--	wGruOCRamWordSize => wGruOCRamWordSize,
	--	wGruOCRamNbWords => wGruOCRamNbWords,
	--	uGruOCRamWordSize => uGruOCRamWordSize,
	--	uGruOCRamNbWords => uGruOCRamNbWords,
	--	xOCRamWordSize => xOCRamWordSize,
	--	xOCRamNbWords => xOCRamNbWords,
	--	MAX_VAL_buffer => MAX_VAL_buffer,
	--	MAX_VAL_conv => MAX_VAL_conv
	--)
	--port map(
		--clk => clk,
		--rstB => rstB,
		
	--	FifoDataOut => FifoDataOut,
		--FifoRdreq => FifoRdreq,
		--FifoRdempty => FifoRdempty,
		--wGruOCRamAddress_a => wGruOCRamAddress_a,
		--wGruOCRamDataIn_a => wGruOCRamDataIn_a,
		--wGruOCRamWren_a => wGruOCRamWren_a,
		--wGruOCRamWren_b => wGruOCRamWren_b,
		
	--	uGruOCRamAddress_a => uGruOCRamAddress_a,
	--	uGruOCRamDataIn_a => uGruOCRamDataIn_a,
	 --  uGruOCRamWren_a => uGruOCRamWren_a,
	--	uGruOCRamWren_b => uGruOCRamWren_b,
		
	--	xOCRamAddress_a => xOCRamAddress_a,
	--	xOCRamDataIn_a => xOCRamDataIn_a,
	 --  xOCRamWren_a => xOCRamWren_a,
	--	xOCRamWren_b => xOCRamWren_b,
		
	--	ConvRegIn => ConvRegIn,
		--ConvRegOut => ConvRegOut,
	--	ConvWriteEn => ConvWriteEn,
	--	CtrlFifoReadParam => CtrlFifoReadParam,
	--	CtrlStatusCtrller => CtrlStatusCtrller
	--);
	
	controller_inst : entity work.controller(rtl)
	generic map(
		NBITS => NBITS,
		FRACBITS => FRACBITS
	)
	port map(
		clk => clk,
		rstB => rstB,
		
		ASNNParamSet => CtrlNNParamSet,
		ASRTDataReady => CtrlRTDataReady,
		
		AMFetchNNParam => CtrlFetchNNParam,
		AMFetchRTData => CtrlFetchRTData,
		AMFifoWriteAllow => CtrlFifoWriteAllow,
		AMFifoWriting => CtrlFifoWriting,
		AMWriteResult => CtrlWriteResult,
		AMReadingActive => CtrlReadingActive,
		AMBurstCntrEnd => CtrlBurstCntrEnd,
		AMNbBurstCntrEnd => CtrlNbBurstCntrEnd,
		AMCtrlInitState => CtrlInitState,
		
		FifoRdempty => FifoRdempty,
		FBFifoReadParam => CtrlFifoReadParam,
		CtrlStatusCtrller => CtrlStatusCtrller
	);
	
	conv_reg_file_inst : entity work.reg_file(rtl)
	generic map(
		NBITS => NBITS,
		NBREG => NBCONVREG
	)
	port map(
		clk => clk,
		rstB => rstB,
		dataIn => ConvRegIn,
		dataOut => ConvRegOut,
		writeEn => ConvWriteEn
	);
	
	ram_wapper_inst : entity work.ram_wrapper(rtl)
	port map(
		uAddress_hps => uAddress_hps,
		wAddress_hps => wAddress_hps,
		xAddress_hps => xAddress_hps,
		
		uDataIn_hps => uDataIn_hps,
		wDataIn_hps => wDataIn_hps,
		xDataIn_hps => xDataIn_hps,
		
		uDataOut_hps => uDataOut_hps,
		wDataOut_hps => wDataOut_hps,
		xDataOut_hps => xDataOut_hps,
		
		uWren_hps => uWren_hps,
		wWren_hps => wWren_hps,
		xWren_hps => xWren_hps,
		
		uReadEn  => uReadEn,
		wReadEn  => wReadEn,
		xReadEn  => xReadEn,
		
		clk   => clk,
		rstB => rstB,
		
		-- to accelerator
		uAddress_acc => uAddress_acc,
		wAddress_acc => wAddress_acc,
		xAddress_acc => xAddress_acc,
		
		uDataIn_acc => uDataIn_acc,
		wDataIn_acc => wDataIn_acc,
		xDataIn_acc => xDataIn_acc,
		
		uDataOut_acc => uDataOut_acc,
		wDataOut_acc => wDataOut_acc,
		xDataOut_acc => xDataOut_acc
		
		uWren_acc => uWren_acc,
		wWren_acc => wWren_acc,
		xWren_acc => xWren_acc
		
	);
	
	mac_matrix_inst : entity work.mac_matrix(rtl)
	generic map(
		NBITS => NBITS,
		NACC => NACC,
		MAC_MAX => MAC_MAX
	)
	port map(
		in_a => macs_a,
		in_b => macs_b,
		macs_o => macs_o,
		clk => clk,
		rstB => rstB,
		clear => macs_clear
	);
	
	
	--DEBUG_OCRAMWdataIsNull_a <= '1' when WGruOCRamDataOut_a =  OCramdataZero else '0';
	--DEBUG_OCRAMUdataIsNull_a <= '1' when UGruOCRamDataOut_a = OCramdataZero else '0';
	--DEBUG_OCRAMWdataIsNull_b <= '1' when WGruOCRamDataOut_b = OCramdataZero else '0';
	--DEBUG_OCRAMUdataIsNull_b <= '1' when UGruOCRamDataOut_b = OCramdataZero else '0';
	--IntRegNb <= to_integer(unsigned(ParamRegFileRegNumber));
end architecture rtl;
