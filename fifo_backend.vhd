library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity fifo_backend is
	generic(
		NBITS : natural := 6;
		FRACBITS : natural := 4;
		NBCONVREG : natural := 10;
		wGruOCRamWordSize : natural := 600;
		wGruOCRamNbWords : natural := 3234;
		uGruOCRamWordSize : natural := 600;
		uGruOCRamNbWords : natural := 307;
		xOCRamWordSize : natural := 600;
		xOCRamNbWords : natural := 307;
		MAX_VAL_buffer : natural :=  20; -- integer(ceil(600* 1 / 30)); --20
		MAX_VAL_conv : natural := 2 --integer(ceil(10*6* 1 / 32)) --2 
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
		wGruOCRamAddress_a : out std_logic_vector(integer(ceil(log2(real(wGruOCRamNbWords))))-1 downto 0); --10 bits
		wGruOCRamDataIn_a : out std_logic_vector(wGruOCRamWordSize -1 downto 0);
		wGruOCRamWren_a : out std_logic;
		wGruOCRamWren_b : out std_logic;
		
		uGruOCRamAddress_a : out std_logic_vector(integer(ceil(log2(real(uGruOCRamNbWords))))-1 downto 0); --10 bits
		uGruOCRamDataIn_a : out std_logic_vector(uGruOCRamWordSize -1 downto 0);
	   uGruOCRamWren_a : out std_logic;
		uGruOCRamWren_b : out std_logic;
		
		xOCRamAddress_a : out std_logic_vector(integer(ceil(log2(real(xOCRamNbWords))))-1 downto 0); --10 bits
		xOCRamDataIn_a : out std_logic_vector(xOCRamWordSize -1 downto 0);
	   xOCRamWren_a : out std_logic;
		xOCRamWren_b : out std_logic;
		-- interface with conv Reg File
		ConvRegIn : out std_logic_vector(NBCONVREG*NBITS-1 downto 0);
		--ConvRegOut : in std_logic_vector(NBCONVREG*NBITS-1 downto 0);
		ConvWriteEn : out std_logic_vector(NBCONVREG-1 downto 0);
		
		-- interface with controller
		CtrlFifoReadParam : in std_logic;
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
	type state_type is (idle, setRdreq1, convStore,setRdreq2, bufferLineW, GruW, setRdreq3, bufferLineU, GruU);
	signal stateReg, stateNext : state_type;
	signal BufferReg, BufferNext : std_logic_vector(WGruOCRamWordSize-1 downto 0);
	--counters
	signal CntrConvEnable : std_logic;
	signal CntrConvEnd : std_logic;
	signal CntrConvVal : std_logic_vector(integer(ceil(log2(real(MAX_VAL_conv))))-1 downto 0);
	signal CntrBufferEnable : std_logic;
	signal CntrBufferEnd : std_logic;
	signal CntrBufferReset : std_logic;
	signal CntrBufferVal : std_logic_vector(integer(ceil(log2(real(MAX_VAL_buffer))))-1 downto 0);
	signal CntrGruWEnable : std_logic;
	signal CntrGruWEnd : std_logic;
	signal CntrGruWVal : std_logic_vector(integer(ceil(log2(real(WGruOCRamNbWords))))-1 downto 0);
	signal CntrGruUEnable : std_logic;
	signal CntrGruUEnd : std_logic;
	signal CntrGruUVal : std_logic_vector(integer(ceil(log2(real(UGruOCRamNbWords))))-1 downto 0);
	
	constant CntrBufferZero : std_logic_vector(integer(ceil(log2(real(MAX_VAL_buffer))))-1 downto 0) := (others => '0');
	
begin

	REG: process(clk, rstB)
	begin
		if rstB = '0' then 
			stateReg <= idle;
			BufferReg <= (others => '0');
		elsif rising_edge(clk) then
			BufferReg <= BufferNext;
			stateReg <= stateNext;
		end if;
	end process REG;
	
	FSM : process(stateReg, CntrBufferEnd, CntrConvEnd, CntrGruWEnd, CntrGruUEnd, FifoRdempty,CtrlFifoReadParam,CntrConvVal,FifoDataOut)
	begin
		CntrConvEnable <= '0';
		CntrBufferEnable <= '0';
		CntrGruWEnable <= '0';
		CntrGruUEnable <= '0';
		CntrBufferReset <= '0';
		stateNext <= stateReg;
		RdreqFifo <= '0';
		ConvWriteEn <= (others => '0');
		case stateReg is
			when idle =>
							if CtrlFifoReadParam = '1' then
								stateNext <= convStore;
							end if;
			when setRdreq1 => 
							if FifoRdempty = '0' then
								RdreqFifo <= '1';
								stateNext <= convStore;
							end if;
			when convStore =>
							if FifoRdempty = '1' then
								RdreqFifo <= '0';
								stateNext <= setRdreq1;
							else
								RdreqFifo <= '1';
								ConvWriteEn <= std_logic_vector(shift_left(to_unsigned(1+2+4+8+16, NBCONVREG),5*to_integer(unsigned(CntrConvVal))));
								ConvRegIn(29+30*to_integer(unsigned(CntrConvVal)) downto 30*to_integer(unsigned(CntrConvVal))) <= FifoDataOut(29 downto 0);
								CntrConvEnable <= '1';
							end if;
							if CntrConvEnd = '1' then
								stateNext <= bufferLineW;
							end if;
			when setRdreq2 =>
							if FifoRdempty = '0' then
								RdreqFifo <= '1';
								stateNext <= bufferLineW;
							end if;
			when bufferLineW =>
							if FifoRdempty = '1' then
								stateNext <= setRdreq2;
							else
								CntrBufferEnable <= '1';
							end if;
							if CntrBufferEnd = '1' then
								RdreqFifo <= '0';
								stateNext <= GruW;
							elsif FifoRdempty = '1' then
								RdreqFifo <= '0';
							else
								RdreqFifo <= '1';
							end if;
			when GruW =>
							CntrBufferReset <= '1';
							CntrGruWEnable <= '1';
							if FifoRdempty = '0' then
								RdreqFifo <= '1';
								if CntrGruWEnd = '1' then
									stateNext <= bufferLineU;
								else
									stateNext <= bufferLineW;
								end if;
							end if;
			when setRdreq3 =>
							if FifoRdempty = '0' then
								RdreqFifo <= '1';
								stateNext <= bufferLineU;
							end if;
			when bufferLineU =>
							if FifoRdempty = '1' then
								RdreqFifo <= '0';
								stateNext <= setRdreq3;
							else
								RdreqFifo <= '1';
								CntrBufferEnable <= '1';
							end if;
							if CntrBufferEnd = '1' then
								stateNext <= GruU;
							end if;
			when GruU =>
							CntrBufferReset <= '1';
							CntrGruUEnable <= '1';
							if FifoRdempty = '0' then
								RdreqFifo <= '1';
								if CntrGruUEnd = '1' then
									stateNext <= idle;
								else
									stateNext <= bufferLineU;
								end if;
							end if;
		end case;	
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
			CntrVal => CntrConvVal,
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
			CntrVal => CntrBufferVal,
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
			CntrVal => CntrGruWVal,
			CntrEnd => CntrGruWEnd
		);
	
	cntrGruU_inst : entity work.counter(rtl)
		generic map(
			MAX_VAL => UGruOCRamNbWords
		)
		port map(
			clk => clk,
			rstB => rstB,
			CntrEnable => CntrGruUEnable,
			CntrReset => '0',
			CntrVal => CntrGruUVal,
			CntrEnd => CntrGruUEnd
		);
		
	BUFFERING: process(CntrBufferEnable, stateReg, CntrBufferVal, FifoDataOut)
	begin
		BufferNext <= BufferReg;
		if CntrBufferEnable = '1' then
				BufferNext(29+to_integer(unsigned(CntrBufferVal))*30 downto 30*to_integer(unsigned(CntrBufferVal))) <= FifoDataOut(29 downto 0);
		else
			BufferNext <= (others => '0');
		end if;
	end process BUFFERING;
	
	RAM_WRITE : process(stateReg, CntrGruWVal, CntrGruUVal, BufferReg)
	begin
		wGruOCRamWren_a <= '0';
		uGruOCRamWren_a <= '0';
		xOCRamWren_a <= '0';
		wGruOCRamAddress_a <= (others => '0');
		uGruOCRamAddress_a <= (others => '0');
		xOCRamAddress_a <= (others => '0');
		wGruOCRamDataIn_a <= (others => '0');
		uGruOCRamDataIn_a <= (Others => '0');
		xOCRamDataIn_a <= (Others => '0');
		if stateReg = GruW then
			wGruOCRamWren_a <= '1';
			wGruOCRamAddress_a <= CntrGruWVal;
		elsif stateReg = GruU then
			uGruOCRamWren_a <= '1';
			uGruOCRamAddress_a <= CntrGruUVal;
		end if;
		wGruOCRamDataIn_a <= BufferReg; 
		uGruOCRamDataIn_a <= BufferReg;
	end process RAM_WRITE;
	-- output signals
	FifoRdreq <= RdreqFifo;
	
end architecture rtl;