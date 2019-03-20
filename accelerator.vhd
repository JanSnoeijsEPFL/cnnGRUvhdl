library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity accelerator is
	generic(
		NBITS : natural := 6;
		FRACBITS : natural := 4;
		NACC : natural := 11;
		WGruOCRamWordSize : natural := 600;
		WGruOCRamNbWords : natural := 3234;
		UGruOCRamWordSize : natural := 600;
		UGruOCRamNbWords : natural := 302
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
		AMaddress : out std_logic_vector(31 downto 0);
		AMbyteenable : out std_logic_vector(3 downto 0);
		AMreaddatavalid : in std_logic;
		
		-- avalon slave
		ASreadEn : in std_logic;
		ASwriteEn : in std_logic;
		ASslaveAddr : in std_logic_vector(2 downto 0);
		ASreaddata : out std_logic_vector(31 downto 0);
		ASwritedata : in std_logic_vector(31 downto 0)
	);
end entity accelerator;

architecture rtl of accelerator is
	
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
	
	--av slave - controller
	signal CtrlNNParamset : std_logic; -- set by proc to indicate parameters are ready in SDRAM
	signal CtrlRTDataReady:  std_logic; -- set by proc to indicate new RT data is ready in SDRAM
	signal CtrlStatusCtrller : std_logic_vector(2 downto 0); -- status of controller for processor checks
	
	-- fifo backend
	signal WGruOCRamAddress_a : std_logic_vector(integer(ceil(log2(real(WGruOCRamNbWords))))-1 downto 0); --10 bits
	signal WGruOCRamAddress_a : std_logic_vector(integer(ceil(log2(real(WGRUOCRamNbWords))))-1 downto 0);
	signal WGruOCRamDataIn_a : std_logic_vector(WGruOCRamWordSize -1 downto 0);
	signal WGruOCRamDataIn_b : std_logic_vector(WGruOCRamWordSize -1 downto 0);
	signal WGruOCRamWren_a : std_logic;
	signal WGruOCRamWren_b : std_logic;
	
	signal UGruOCRamAddress_a : std_logic_vector(integer(ceil(log2(real(UGruOCRamNbWords))))-1 downto 0); --10 bits
	signal UGruOCRamAddress_a : std_logic_vector(integer(ceil(log2(real(UGRUOCRamNbWords))))-1 downto 0);
	signal UGruOCRamDataIn_a : std_logic_vector(UGruOCRamWordSize -1 downto 0);
	signal UGruOCRamDataIn_b : std_logic_vector(UGruOCRamWordSize -1 downto 0);
	signal UGruOCRamWren_a : std_logic;
	signal UGruOCRamWren_b : std_logic;
	
	-- RAMs outputs
	signal WGruOCRamDataOut_a : std_logic_vector(WGruOCramWordSize -1 downto 0);
	signal WGruOCRamDataOut_b : std_logic_vector(WGruOCramWordSize -1 downto 0);
	signal UGruOCRamDataOut_a : std_logic_vector(UGruOCramWordSize -1 downto 0);
	signal UGruOCRamDataOut_b : std_logic_vector(UGruOCramWordSize -1 downto 0);
	
	
	-- param reg file (debug regfile data)
	--signal ParamRegFileDataOut : std_logic_vector((NBITS-1)*NBITS-1 downto 0);
	
	--signal XRegFileDataIn : std_logic_vector((NBITS-1)*NBITS-1 downto 0);
	--signal XRegFileWriteEn : std_logic_vector((NBITS-1)*NBITS-1 downto 0);
	-- signal from classifier
	signal ClassSeqClass: std_logic; -- sequence classification result
	
	signal IntRegNb : integer;
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
	
	component gruWRAM
		port
		(
			address_a		: in std_logic_vector (8 downto 0);
			address_b		: in std_logic_vector (8 downto 0);
			clock		: in std_logic  := '1';
			data_a		: in std_logic_vector (99 downto 0);
			data_b		: in std_logic_vector (99 downto 0);
			wren_a		: in std_logic  := '0';
			wren_b		: in std_logic  := '0';
			q_a		: out std_logic_vector (99 downto 0);
			q_b		: out std_logic_vector (99 downto 0)
		);
	end component;
	
	component gruURAM
		port
		(
			address_a		: in std_logic_vector (8 downto 0);
			address_b		: in std_logic_vector (8 downto 0);
			clock		: in std_logic  := '1';
			data_a		: in std_logic_vector (99 downto 0);
			data_b		: in std_logic_vector (99 downto 0);
			wren_a		: in std_logic  := '0';
			wren_b		: in std_logic  := '0';
			q_a		: out std_logic_vector (99 downto 0);
			q_b		: out std_logic_vector (99 downto 0)
		);
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
	
	gruWRAM_inst : gruWRAM port map(
		address_a	 => WGruOCRamAddress_a,
		address_b	 => WGruOCRamAddress_b,
		clock	 => clk,
		data_a	 => WGruOCRamDataIn_a,
		data_b	 => WGruOCRamDataIn_b,
		wren_a	 => WGruWren_a,
		wren_b	 => WGruWren_b,
		q_a	 => WGruOCRamDataOut_a,
		q_b	 => WGruOCRamDataOut_b
	);
		
	gruURAM : gruURAM port map(
		address_a	 => UGruOCRamAddress_a,
		address_b	 => UGruOCRamAddress_b,
		clock	 => clk,
		data_a	 => UGruOCRamDataIn_a,
		data_b	 => UGruOCRamDataIn_b,
		wren_a	 => UGruWren_a,
		wren_b	 => UGruWren_b,
		q_a	 => UGruOCRamDataOut_a,
		q_b	 => UGruOCRamDataOut_b
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
		waitrequest => AMwaitrequest,
		readEn => AMreadEn,
		writeEn => AMwriteEn,
		readdata => AMreaddata,
		writedata => AMwritedata,
		address => AMaddress,
		byteenable => AMbyteenable,
		readdatavalid => AMreaddatavalid,
		ASReadAddr => ASReadAddr,
		ASWriteAddr => ASWriteAddr,
		ASReadingActive => ASReadingActive,
		
		FifoDataIn => FifoDataIn,
		FifoWrreq => FifoWrreq,
		FifoWrfull => FifoWrfull,
		
		CtrlFetchNNParam => CtrlFetchNNParam,
		CtrlFetchRTData => CtrlFetchRTData,
		CtrlFifoWriteAllow => CtrlFifoWriteAllow,
		CtrlFifoWriting => CtrlFifoWriting,
		CtrlWriteResult => CtrlWriteResult,
		CtrlReadingActive => CtrlReadingActive,
		CtrlBurstCntrEnd => CtrlBurstCntrEnd,
		CtrlNbBurstCntrEnd => CtrlNbBurstCntrEnd,
		CtrlInitState => CtrlInitState,
		ClassSeqClass => ClassSeqClass
		);
	
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
		WGruOCRamWordSize : natural := 539,
		WGruOCRamNbWords : natural := 600,
		UGruOCRamWordSize : natural := 100,
		UGruOCRamNbWords : natural := 303
	)
	port map(
		clk => clk,
		rstB => rstB,
		
		FifoDataOut => FifoDataOut,
		FifoRdreq => FifoRdreq,
		FifoRdempty => FifoRdempty,
		WGruOCRamAddress_a => WGruOCRamAddress_a,
		WGruOCRamAddress_b => WGruOCRamAddress_b,
		WGruOCRamDataIn_a => WGruOCRamDataIn_a,
		WGruOCRamDataIn_b => WGruOCRamDataIn_b,
		WGruOCRamWren_a => WGruOCRamWren_a,
		WGruOCRamWren_b => WGruOCRamWren_b,
		
		UGruOCRamAddress_a => UGruOCRamAddress_a,
		UGruOCRamAddress_b => UGruOCRamAddress_b,
		UGruOCRamDataIn_a => UGruOCRamDataIn_a,
		UGruOCRamDataIn_b => UGruOCRamDataIn_b,
	   UGruOCRamWren_a => UGruOCRamWren_a,
		UGruOCRamWren_b => UGruOCRamWren_b,
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
		
		ASNNParamSet => CtrlNNParamSet,
		ASRTDataReady => CtrlRTDataReady,
		ASStatusCtrller => CtrlStatusCtrller,
		
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
		
		FBStatusCtrller => CtrlStatusCtrller
	);
	
	--param_reg_file_inst : entity work.param_reg_file(rtl)
	--generic map(
	--	NBITS => NBITS,
	--	FRACBITS => FRACBITS,
		--NBREG => NBREG
	--)
	--port map(
		--clk => clk,
		--rstB => rstB,
		--dataIn(IntRegNb*(NBITS-1)*NBITS-1+(NBITS-1)*NBITS downto IntRegNb*(NBITS-1)*NBITS) => ParamRegFileDataIn,
		--dataOut(IntRegNb*(NBITS-1)*NBITS-1+(NBITS-1)*NBITS downto IntRegNb*(NBITS-1)*NBITS) => ParamRegFileDataOut,
		--writeEn(IntRegNb) => ParamRegFileWriteEn
	--);
	

	IntRegNb <= to_integer(unsigned(ParamRegFileRegNumber));
end architecture rtl;
