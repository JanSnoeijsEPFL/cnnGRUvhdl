library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity fifo_backend is
	generic(
		NBITS : natural := 6;
		FRACBITS : natural := 4;
		WGruOCRamWordSize : natural := 600;
		WGruOCRamNbWords : natural := 3234;
		UGruOCRamWordSize : natural := 600;
		UGruOCRamNbWords : natural := 307;
		MAX_VAL_buffer : natural := integer(ceil(600/32)); --19
		MAX_VAL_conv : natural := 10;
		--MAX_VAL_GruW : natural :=  integer())
	);
	
	port(
		--base signals 
		clk : in std_logic;
		rstB : in std_logic;
		
		-- interface with fifo
		FifoDataOut : in std_logic_vector(31 downto 0);
		FifoRdreq : out std_logic;
		--FifoRdclk : out std_logic;
		FifoRdempty : in std_logic;
		
		--interface with on chip RAM blocks (write only from this module)
		WGruOCRamAddress_a : out std_logic_vector(integer(ceil(log2(real(WGruOCRamNbWords))))-1 downto 0); --10 bits
		WGruOCRamAddress_b : out std_logic_vector(integer(ceil(log2(real(WGRUOCRamNbWords))))-1 downto 0);
		WGruOCRamDataIn_a : out std_logic_vector(WGruOCRamWordSize -1 downto 0);
		WGruOCRamDataIn_b : out std_logic_vector(WGruOCRamWordSize -1 downto 0);
		WGruOCRamWren_a : out std_logic;
		WGruOCRamWren_b : out std_logic;
		
		UGruOCRamAddress_a : out std_logic_vector(integer(ceil(log2(real(UGruOCRamNbWords))))-1 downto 0); --10 bits
		UGruOCRamAddress_b : out std_logic_vector(integer(ceil(log2(real(UGRUOCRamNbWords))))-1 downto 0);
		UGruOCRamDataIn_a : out std_logic_vector(UGruOCRamWordSize -1 downto 0);
		UGruOCRamDataIn_b : out std_logic_vector(UGruOCRamWordSize -1 downto 0);
	   UGruOCRamWren_a : out std_logic;
		UGruOCRamWren_b : out std_logic;
		
		--interface with x reg file
	--	XRegFileDataIn : out std_logic_vector((NBITS-1)*NBITS-1 downto 0);
		--XRegFileWriteEn : out std_logic_vector((NBITS-1)*NBITS-1 downto 0);
		
		-- interface with controller
		CtrlStatusCtrller : in std_logic_vector(2 downto 0)
		--CtrlRegNumber : in std_logic_vector(intege			FifoDataOut : std_logic_vector(31 downto 0);
	);
end entity fifo_backend;

architecture rtl of fifo_backend is
	--signal CntrRegNumberReg, CntrRegNumberNext : std_logic_vector(integer(ceil(log2(real(NBREG))))-1 downto 0);
	signal RegData : std_logic_vector(29 downto 0);
	signal RdreqFifo : std_logic;
	--constant CntrRegMax : std_logic_vector := std_logic_vector(to_unsigned(NBREG, integer(ceil(log2(real(NBREG))))));
	--signal CntrRegNumberEnd : std_logic;
	type state_type is (idle, convStore, bufferLineW, GruW, bufferLineU, GruU);
	signal stateReg, stateNext : state_type;
	
	--counters
	signal CntrConvEnable : std_logic;
	signal CntrConvEnd : std_logic;
	signal CntrBufferEnable : std_logic;
	signal CntrBufferEnd : std_logic;
	signal CntrBufferReset : std_logic;
	signal CntrGruWEnable : std_logic;
	signal CntrGruWEnd : std_logic;
	signal CntrGruUEnable : std_logic;
	signal CntrGruUEnd : std_logic;
	
begin

	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			CntrRegNumberReg <= (others => '0');
		elsif rising_edge(clk) then
			CntrRegNumberReg <= CntrRegNumberNext;
		end if;
	end process REG;
	
	FSM : process(stateReg, CntrBufferEnd, CntrConvEnd, CntrGruWEnd, CntrGruUEnd, FifoRdempty)
	begin
		CntrConvEnable <= '0';
		CntrBufferEnable <= '0';
		CntrGruWEnable <= '0';
		CntrGruUEnable <= '0';
		CntrBufferReset <= '0';
		stateNext <= stateReg;
		RdreqFifo <= '0';
		case stateReg is
			when idle =>
							if CtrlFifoReadParam = '1' then
								stateNext <= convStore;
			when convStore =>
							if FifoRdempty = '0' then
								RdreqFifo <= '1';
								ConvReg <= FifoDataOut;
								CntrConvEnable <= '1';
							end if;
							if CntrConvEnd = '1' then
								stateNext <= bufferLineW;
							end if;
			when bufferLineW =>
							if FifoRdempty = '0' then
								RdreqFifo <= '1';
								CntrBufferEnable <= '1';
							end if;
							if CntrBufferEnd = '1' then
								stateNext <= GruW;
							end if;
			when GruW =>
							CntrBufferReset <= '1';
							CntrGruWEnable <= '1';
							if CntrGruWEnd = '1' then
								state_next <= bufferLineU;
							else
								state_next <= bufferLineW;
							end if;
			when bufferLineU =>
							if FifoRdempty = '0' then
								RdreqFifo <= '1';
								CntrBufferEnable <= '1';
							end if;
							if CntrBufferEnd = '1' then
								stateNext <= GruU;
							end if;
			when GruU =>
							CntrBufferReset <= '1';
							CntrGruUEnable <= '1';
							if CntrGruUEnd = '1' then
								state_next <= idle; 
							else
								state_next <= bufferLineW;
							end if;
							
	end process FSM;
		
	cntrConv_inst : entity work.counter(rtl)
		generic map(
			MAX_VAL => MAX_VAL_conv
		)
		port map(
			clk => clk,
			rstB => rstB,
			CntrEnable => CntrConvEnable,
			CntrReset => '0',
			CntrEnd => CntrConvEnd
		);
	
	cntrBuffer_inst : entity work.counter(rtl)
		generic map(
			MAX_VAL => MAX_VAL_buffer
		)
		port map(
			clk => clk,
			rstB => rstB,
			CntrEnable => CntrBufferEnable,
			CntrReset => CntrBufferReset,
			CntrEnd => CntrBufferEnd
		);
	
	cntrGruW_inst : entity work.counter(rtl)
		generic map(
			MAX_VAL => WGruOCRamNbWords
		)
		port map(
			clk => clk,
			rstB => rstB,
			CntrEnable => CntrGruWEnable,
			CntrReset => '0',
			CntrEnd => CntrGruWEnd
		);
	
	cntrGruW_inst : entity work.counter(rtl)
		generic map(
			MAX_VAL => UGruOCRamNbWords
		)
		port map(
			clk => clk,
			rstB => rstB,
			CntrEnable => CntrGruUEnable,
			CntrReset => '0',
			CntrEnd => CntrGruUEnd
		);
		
	-- output signals
	FifoRdreq <= RdreqFifo;
	
end architecture rtl;