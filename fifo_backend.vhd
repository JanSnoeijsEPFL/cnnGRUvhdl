library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity fifo_backend is
	generic(
		NBITS : natural := 6;
		FRACBITS : natural := 4;
		NBREG : natural := 59007
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
		
		--interface with param reg file
		ParamRegFileDataIn : out std_logic_vector((NBITS-1)*NBITS-1 downto 0);
		ParamRegFileWriteEn : out std_logic;
		ParamRegFileRegNumber : out std_logic_vector(integer(ceil(log2(real(NBREG))))-1 downto 0);
		
		--interface with x reg file
		XRegFileDataIn : out std_logic_vector((NBITS-1)*NBITS-1 downto 0);
		XRegFileWriteEn : out std_logic_vector((NBITS-1)*NBITS-1 downto 0);
		
		-- interface with controller
		CtrlStatusCtrller : in std_logic_vector(2 downto 0)
		--CtrlRegNumber : in std_logic_vector(intege			FifoDataOut : std_logic_vector(31 downto 0);
	);
end entity fifo_backend;

architecture rtl of fifo_backend is
	signal CntrRegNumberReg, CntrRegNumberNext : std_logic_vector(integer(ceil(log2(real(NBREG))))-1 downto 0);
	signal RegData : std_logic_vector(29 downto 0);
	signal RdreqFifo : std_logic;
	constant CntrRegMax : std_logic_vector := std_logic_vector(to_unsigned(NBREG, integer(ceil(log2(real(NBREG))))));
	signal CntrRegNumberEnd : std_logic;
begin

	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			CntrRegNumberReg <= (others => '0');
		elsif rising_edge(clk) then
			CntrRegNumberReg <= CntrRegNumberNext;
		end if;
	end process REG;
	
	READ_FIFO: process(FifoDataOut, FifoRdempty)
	begin
		if FifoRdempty = '0' then
			RdreqFifo <= '1';
			--RegData <= FifoDataOut(29 downto 0);
		end if;
	end process READ_FIFO;
	
	CNTR: process(FifoDataOut, RdreqFifo, CntrRegNumberReg, CntrRegNumberEnd)
	begin
		CntrRegNumberNext <= CntrRegNumberReg;
		ParamRegFileRegNumber <= (others => '0');
		if RdreqFifo = '1' and CntrRegNumberEnd = '0' then
			ParamRegFileRegNumber <= CntrRegNumberReg;
			ParamRegFileWriteEn <= '1';
			ParamRegFileDataIn <= FifoDataOut;
			CntrRegNumberNext <= std_logic_vector(unsigned(CntrRegNumberReg) + 1);
		end if;
	end process CNTR;
	
	CntrRegNumberEnd <= '1' when CntrRegNumberReg = CntrRegMax else '0';
	
	-- output signals
	FifoRdreq <= RdreqFifo;
	
end architecture rtl;