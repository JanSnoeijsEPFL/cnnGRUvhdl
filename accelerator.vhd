library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity accelerator is
	generic(
		NBITS : natural := 6;
		NBMAXP : natural := 49;
		NBFRAC : natural := 4;
		NBCONVREG : natural := 10;
		MAC_MAX : natural := 100;
		NACC : natural := 11;
		NBOUT : natural := 100;
		MAXP_IM_HEIGHT : natural := 11;
		RECUR_CNTR_MAX : natural := 10;
		RAM_LINE_SIZE : natural := 600;
		wGruOCRamWordSize : natural := 600;
		wGruOCRamNbWords : natural := 3234;
		wGRUlog2NBWords : natural := 12;
		uGruOCRamWordSize : natural := 600;
		uGruOCRamNbWords : natural := 307;
		uGRUlog2NBWords : natural := 9;
		xOCRamWordSize : natural := 600;
		xOCRamNbWords : natural := 92;
		xlog2NBWords : natural := 7;
		BURST_LENGTH : natural := 8;
		NB_BURSTS : natural := 625;
		MAX_VAL_buffer : natural := 19; --19
		MAX_VAL_conv : natural := 2;--2
		DEBUG : natural := 0
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
		xAddress_hps : in std_logic_vector(11 downto 0);
		
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
		


	);
end entity accelerator;

architecture rtl of accelerator is
	
	constant ZEROS_306 : std_logic_vector(51*NBITS-1 downto 0) := (others => '0');
	constant OCramdataZero: std_logic_vector := std_logic_vector(to_unsigned(0, wGruOCRamWordSize)); 
	-- AV master - AV slave
	signal ASReadAddr : std_logic_vector(31 downto 0); -- read address in SDRAM for data fetching
	signal ASWriteAddr : std_logic_vector(31 downto 0); -- write address in SDRAM for writing results of algorithm
	signal ASReadingActive: std_logic; -- set to indicate Master is reading data from SDRAM	
	

	signal FifoDataIn : std_logic_vector(NBITS-1 downto 0);
	signal FifoWrreq : std_logic;
	signal FifoEmpty : std_logic;
	signal FifoFull : std_logic;
	signal FifoDataOut : std_logic_vector(NBITS-1 downto 0);
	signal FifoRdreq : std_logic;
	signal FifoClear : std_logic;
	
	--av slave - controller
	signal start_algo : std_logic; -- set by proc to indicate parameters are ready in SDRAM
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
	signal xAddress_a : std_logic_vector(6 downto 0) := (others => '0');
	signal xAddress_b : std_logic_vector(6 downto 0) := (others => '0');
		
	signal uDataIn_acc : std_logic_vector(599 downto 0) := (others => '0');
	signal wDataIn_acc : std_logic_vector(599 downto 0) := (others => '0');
	signal xDataIn_a : std_logic_vector(599 downto 0) := (others => '0');
	signal xDataIn_b : std_logic_vector(599 downto 0) := (others => '0');
		
	signal uDataOut_acc : std_logic_vector(599 downto 0);
	signal wDataOut_acc : std_logic_vector(599 downto 0);
	signal xDataOut_a : std_logic_vector(599 downto 0) := (others => '0');
	signal xDataOut_b : std_logic_vector(599 downto 0);
		
	signal uWren_acc : std_logic := '0';
	signal wWren_acc : std_logic := '0';
	signal xWren_a : std_logic := '0';
	signal xWren_b : std_logic := '0';
	
	signal xOCRAM_b_mode : std_logic; -- 0: HPS mode, 1: FPGA mode.
	signal xAddress_a_CONV : std_logic_vector(6 downto 0);
	--signal xDataOut_a_CONV : std_logic_vector(599 downto 0);
	signal xAddress_a_GRU : std_logic_vector (6 downto 0);
	--signal xDataOut_a_GRU : std_logic_vector(599 downto 0);
	signal conv2d_end : std_logic;
	signal gru_end : std_logic;
	signal dense_end : std_logic;
	signal algo_state : std_logic_vector(2 downto 0);
	
	signal macs_x_conv : std_logic_vector(MAC_MAX*NBITS-1 downto 0);
	signal macs_w_conv : std_logic_vector(MAC_MAX*NBITS-1 downto 0);
	signal macs_o_conv : std_logic_vector((2*NBITS+NACC)*MAC_MAX-1 downto 0); 
	signal macs_clear_conv : std_logic_vector(MAC_MAX-1 downto 0);
	
	signal macs_x_gru : std_logic_vector(MAC_MAX*NBITS-1 downto 0);
	signal macs_w_gru : std_logic_vector(MAC_MAX*NBITS-1 downto 0);
	--signal macs_o_conv : std_logic_vector((2*NBITS+NACC)*MAC_MAX-1 downto 0); 
	signal macs_clear_gru : std_logic_vector(MAC_MAX-1 downto 0);
	
	signal macs_a: std_logic_vector(MAC_MAX*NBITS-1 downto 0);
	signal macs_b : std_logic_vector(MAC_MAX*NBITS-1 downto 0);
	signal macs_o : std_logic_vector((2*NBITS+NACC)*MAC_MAX-1 downto 0); 
	signal macs_clear : std_logic_vector(MAC_MAX-1 downto 0);
	
	signal comp_mode : std_logic_vector(1 downto 0);
	signal op_line : std_logic_vector(MAC_MAX*NBITS-1 downto 0);
	signal round_line : std_logic_vector(MAC_MAX*NBITS-1 downto 0);
	signal hs_line : std_logic_vector(MAC_MAX*NBITS-1 downto 0);
	signal in_max_line : std_logic_vector(MAC_MAX*(2*NBITS+NACC)-1 downto 0);
	signal in_min_line : std_logic_vector(MAC_MAX*(2*NBITS+NACC)-1 downto 0);
	signal out_max_line : std_logic_vector(MAC_MAX*NBITS-1 downto 0);
	signal out_min_line : std_logic_vector(MAC_MAX*NBITS-1 downto 0);
	signal res_line:  std_logic_vector(MAC_MAX*NBITS-1 downto 0);
	signal x_comp_line : std_logic_vector((2*NBITS+NACC)*MAC_MAX-1 downto 0); 
	
	signal start_sampling : std_logic;
	signal start_conv2d : std_logic;
	
	signal maxp_in1_line : std_logic_vector(NBMAXP*NBITS-1 downto 0);
	signal maxp_in2_line : std_logic_vector(NBMAXP*NBITS-1 downto 0);
	signal maxp_out_line : std_logic_vector(NBMAXP*NBITS-1 downto 0);
	signal sample : std_logic;
	signal trig_serializer : std_logic;
	---signal maxp_in1_line : std_logic_vector( downto );
	signal comp_mode_gru : std_logic_vector(1 downto 0);
	signal trigger_gru : std_logic;
	signal gru_finished_products : std_logic;
	signal algo_recur_iter : std_logic_vector(3 downto 0);

	signal comp_line_gru : std_logic_vector(NBOUT*NBITS-1 downto 0);
	signal res_line_gru : std_logic_vector(NBOUT*NBITS-1 downto 0);
	signal s_out : std_logic_vector(NBOUT*NBITS-1 downto 0);
	
	signal x_ocram_DEBUG_addr_b : std_logic_vector(xlog2NBWords-1 downto 0);
	signal x_ocram_DEBUG_data_b : std_logic_vector(RAM_LINE_SIZE-1 downto 0);
	signal x_ocram_DEBUG_wren_b : std_logic;
	
	signal xAddress_b_maxp : std_logic_vector(xlog2NBWords-1 downto 0);
	signal xWren_b_maxp : std_logic;
	
	signal hps_write_new_batch : std_logic;
	signal hps_DEBUG_read : std_logic;
	
	component fifo_x
		PORT
		(
			clock		: IN STD_LOGIC ;
			data		: IN STD_LOGIC_VECTOR (5 DOWNTO 0);
			rdreq		: IN STD_LOGIC ;
			sclr		: IN STD_LOGIC ;
			wrreq		: IN STD_LOGIC ;
			empty		: OUT STD_LOGIC ;
			full		: OUT STD_LOGIC ;
			q		: OUT STD_LOGIC_VECTOR (5 DOWNTO 0)
		);
	end component;
begin
	
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
	
		--AMWriteAddr => ASWriteAddr,
		--AMReadAddr => ASReadAddr,
		
		start_algo => start_algo,
		algo_state => algo_state,
		hps_write_new_batch => hps_write_new_batch,
		hps_DEBUG_read => hps_DEBUG_read,
		
		ConvIn => ConvRegIn,
		ConvOut => ConvRegOut,
		ConvWriteEn => ConvWriteEn,
		xOCRAM_b_mode => xOCRAM_b_mode
	);
	
	
	--controller_inst : entity work.controller(rtl)
	---generic map(
	--	NBITS => NBITS,
	--	FRACBITS => FRACBITS
	--)
	--port map(
	--	clk => clk,
	--	rstB => rstB,
	--	-
	--	ASNNParamSet => CtrlNNParamSet,
	--	ASRTDataReady => CtrlRTDataReady,
	--	
	--	AMFetchNNParam => CtrlFetchNNParam,
	--	AMFetchRTData => CtrlFetchRTData,
	--	AMFifoWriteAllow => CtrlFifoWriteAllow,
		--AMFifoWriting => CtrlFifoWriting,
	--	AMWriteResult => CtrlWriteResult,
		--AMReadingActive => CtrlReadingActive,
		--AMBurstCntrEnd => CtrlBurstCntrEnd,
	--	AMNbBurstCntrEnd => CtrlNbBurstCntrEnd,
	--	AMCtrlInitState => CtrlInitState,
		
		--FifoRdempty => FifoRdempty,
	--	FBFifoReadParam => CtrlFifoReadParam,
		--CtrlStatusCtrller => CtrlStatusCtrller
	--);

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
		xAddress_acc => xAddress_a,
		xAddress_acc_b => xAddress_b,
		uDataIn_acc => uDataIn_acc,
		wDataIn_acc => wDataIn_acc,
		xDataIn_acc => xDataIn_a,
		xDataIn_acc_b => xDataIn_b,
		uDataOut_acc => uDataOut_acc,
		wDataOut_acc => wDataOut_acc,
		xDataOut_acc => xDataOut_a,
		xDataOut_acc_b => xDataOut_b,
		uWren_acc => uWren_acc,
		wWren_acc => wWren_acc,
		xWren_acc => xWren_a,
		xWren_acc_b => xWren_b,
		xOCRAM_b_mode => xOCRAM_b_mode
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
	--ALGO CONTROL
	algo_control_inst : entity work.algo_control(rtl)
	generic map(
		RECUR_CNTR_MAX => RECUR_CNTR_MAX,
		DEBUG => DEBUG
	)
	port map(
		clk => clk,
		rstB => rstB,
		start_algo => start_algo,
		conv2d_end => conv2d_end,
		gru_end => gru_finished_products,
		dense_end => dense_end,
		algo_state => algo_state,
		start_conv2d => start_conv2d,
		trig_serializer => trig_serializer,
		recur_iter => algo_recur_iter,
		trigger_gru => trigger_gru,
		hps_write_new_batch => hps_write_new_batch,
		hps_DEBUG_read => hps_DEBUG_read
	);
	
	--CONV2D
	conv2d_control_inst : entity work.conv2d_control(rtl)
	generic map(
		RAM_LINE_SIZE => RAM_LINE_SIZE,
		xlog2NBWords => xlog2NBWords,
		NBITS => NBITS,
		MAC_MAX => MAC_MAX
	)
	port map(
		clk => clk,
		rstB => rstB,
	   x_ocram_data => xDataOut_a, --read from port A
	   x_ocram_address => xAddress_a_CONV, --address for port A
		start_sampling => start_sampling,
		--algo_state => algo_state,
		start_conv2d => start_conv2d,
		conv2d_reg => ConvRegOut,
		macs_x => macs_x_conv,
		macs_w => macs_w_conv
		--macs_clear => macs_clear_conv
	);
	
	conv2d_output_control_inst : entity work.conv2d_output_control(rtl)
	generic map(
		xlog2NBWords => xlog2NBWords,
		MAC_MAX => MAC_MAX
	)
	port map(
		clk => clk,
		rstB => rstB,
		conv2d_end => conv2d_end,
		--x_ocram_address_b => xAddress_b, -- write to port B
		--x_ocram_wren_b => xWren_b,
		start_sampling => start_sampling,
		macs_clear => macs_clear_conv
		--trig_serializer => trig_serializer
	);
	--COMP UNIT
	comp_unit_matrix_inst: entity work.comp_unit_matrix(rtl)
	generic map(
		MAC_MAX => MAC_MAX,
		NBITS => NBITS,
		NACC => NACC,
		NBFRAC => NBFRAC
	)
	port map(
		clk => clk,
		rstB => rstB,
		x_line => x_comp_line,
		mode => comp_mode,
		res_line => res_line -- output to write to port B
	);
	-- COMP UNIT CTRL
	
	--comp_units_ctrl_inst : entity work.comp_units_ctrl(rtl)
	--generic map(
	--	MAC_MAX => MAC_MAX,
	--	NBITS => NBITS,
	--	NACC => NACC
	--)
	--port map(
	--	clk => clk,
	--	rstB => rstB,
	--	mode => comp_mode,
	--	round_line => round_line,
	--	hs_line => hs_line,
	--	op_line => op_line,
	--	in_max_line => in_max_line,
	--	in_min_line => in_min_line,
	--	out_max_line => out_max_line,
	--	out_min_line => out_min_line
   --	);

	maxp_matrix_inst : entity work.maxp_matrix(rtl)
	generic map(
		NBITS => NBITS,
		NBMAXP => NBMAXP
	)
	port map(
		clk => clk,
		rstB => rstB,
		in_1_line => maxp_in1_line,
		in_2_line => maxp_in2_line,
		sample =>  macs_clear_conv(0),
		maxp_line => maxp_out_line
		--xocram_wren_b => xWren_b
	);
	-- MAC DATA MUX
	process(macs_x_conv, macs_w_conv, macs_clear_conv, macs_o, algo_state, macs_clear_gru, macs_x_gru, macs_w_gru)
	begin
		macs_a <= (others => '0');
		macs_b <= (others => '0');
		macs_clear <= (others => '0');
		if algo_state = "010" then
			macs_a <= macs_x_conv;
			macs_b <= macs_w_conv;
			macs_clear <= macs_clear_conv;
		elsif algo_state = "011" then
			macs_a <= macs_x_gru;
			macs_b <= macs_w_gru; 
			macs_clear <= macs_clear_gru;
		end if;
	end process;
	
	fifo_x_inst : fifo_x 
	port map (
		clock => clk,
		data	 => FifoDataIn,
		rdreq	 => FifoRdreq,
		sclr	 => FifoClear,
		wrreq	 => FifoWrreq,
		empty	 => FifoEmpty,
		full	 => FifoFull,
			q	 => FifoDataOut
	);
	
	serializer_inst : entity work.serializer(rtl)
	generic map(
		NBITS => NBITS,
		NBMAXP => NBMAXP,
		RAM_LINE_SIZE => RAM_LINE_SIZE,
		MAXP_IM_HEIGHT => MAXP_IM_HEIGHT
	)
	port map(
		clk => clk, 
		rstB => rstB,
		trigger => trig_serializer,
		start_sampling => start_sampling,
		xocram_addr_a  =>  xAddress_a_GRU,
		xocram_data_a  => xDataOut_a,
		xocram_addr_b => xAddress_b_maxp,
		xocram_wren_b => xWren_b_maxp,
		--fifo write interface
		clear_fifo => FifoClear,
		fifo_empty => FifoEmpty,
		fifo_full  => FifoFull,
		fifo_wrreq => FifoWrreq,
		fifo_data => FifoDataIn,
		recur_iter => algo_recur_iter
	);
	
	gru_control_inst : entity work.gru_control(rtl)
	generic map(
		NBITS => NBITS,
		RAM_LINE_SIZE => RAM_LINE_SIZE,
		NBOUT => NBOUT,
		wlog2NbWords => wGRUlog2NBWords,
		ulog2NbWords => uGRUlog2NBWords,
		xlog2NbWords => xlog2NbWords,
		MAC_MAX => MAC_MAX,
		NACC => NACC
	)
	port map(
		clk => clk,
		rstB => rstB,

		trigger_gru => trigger_gru,
		recur_CntrVal => algo_recur_iter,
		finished_products => gru_finished_products,
		
		--interface to fifo
		fifo_rdreq => FifoRdreq,
		fifo_data => FifoDataOut,
		
		macs_x_gru => macs_x_gru,
		macs_w_gru => macs_w_gru,
		macs_clear_gru => macs_clear_gru,
		macs_o_gru => macs_o,
	
		res_line => res_line,
		
		wocram_addr => wAddress_acc,
		wocram_data => wDataOut_acc,
		uocram_addr => uAddress_acc,
		uocram_data => uDataOut_acc,
		-- output data
		s_out => s_out,
		comp_mode => comp_mode_gru,
		x_ocram_DEBUG_addr_b => x_ocram_DEBUG_addr_b,
		x_ocram_DEBUG_data_b => x_ocram_DEBUG_data_b,
		x_ocram_DEBUG_wren_b => x_ocram_DEBUG_wren_b
	);
	
	xAddress_a <= xAddress_a_CONV when algo_state = "010" else
						xAddress_a_GRU;
	xAddress_b <= x_ocram_DEBUG_addr_b when algo_state = "011" else
						xAddress_b_maxp;
	xWren_b <= x_ocram_DEBUG_wren_b when algo_state ="011" else
					xWren_b_maxp;
	xDataIn_b <= x_ocram_DEBUG_data_b when algo_state = "011" else
					ZEROS_306 & maxp_out_line;		
			
	--MAX POOL INPUT ROUTING
	maxp_route : for i in 0 to NBMAXP-1 generate
		maxp_in1_line(NBITS+NBITS*i-1 downto 0+NBITS*i) <= res_line(NBITS+NBITS*2*i-1 downto 0+NBITS*2*i);
		maxp_in2_line(NBITS+NBITS*i-1 downto 0+NBITS*i) <= res_line(NBITS+NBITS*(2*i+1)-1 downto 0+NBITS*(2*i+1));
	end generate;
	
	-- COMP UNIT DATA MUX
	comp_mode <= "01" when algo_state = "010" else comp_mode_gru; --conv2d or GRU;
	x_comp_line <= macs_o;
	
end architecture rtl;
