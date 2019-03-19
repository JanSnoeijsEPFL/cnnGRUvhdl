library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity controller is
	generic(
		NBITS : natural := 6;
		FRACBITS : natural := 4;
		NBREG : natural := 59007
	);
	port(
		clk : std_logic;
		rstB : std_logic;
		
		--interface with avalon slave
		ASNNParamSet : in std_logic;
		ASRTDataReady : in std_logic;
		ASStatusCtrller : out std_logic_vector(2 downto 0);
		
		--interface with avalon master
		AMFetchNNParam : out std_logic;
		AMFetchRTData : out std_logic;
		AMFifoWriteAllow : out std_logic; -- allow writing data to FIFO
		AMFifoWriting : in std_logic; -- indicates data is being written in FIFO
		AMWriteResult : out std_logic; -- allows writing result to SDRAM
		AMReadingActive: in std_logic; -- set to indicate Master is reading data from SDRAM
		AMBurstCntrEnd : in std_logic;
		AMNbBurstCntrEnd : in std_logic;
		AMCtrlInitState : out std_logic;
		
		--interface with FIFO
		FifoRdempty: in std_logic;	
		
		--interface with fifo backend (FB)
		FBStatusCtrller : out std_logic_vector(2 downto 0)
		-- done in fifo backend
		--FBRegNumber : out std_logic_vector(integer(ceil(log2(real(NBREG))))-1 downto 0)
		
		);
end entity controller;

architecture rtl of controller is	
	type state_type is (init, NNparamFetch, incParamCounter, WaitForFifo, idle, RTdataFetch);
	signal state_reg, state_next : state_type;
	signal RTDataCntrEnd : std_logic;
	signal paramCntrEnd : std_logic;
	signal paramCntrReg, paramCntrNext : std_logic_vector(3 downto 0);
	signal RTDataCntrReg, RTDataCntrNext : std_logic_vector(8 downto 0);
	signal RTDataCntrEnable : std_logic;
	signal StatusCtrller : std_logic_vector(2 downto 0);
	--signal BurstFinished : std_logic;
begin

	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			state_reg <= init;
			paramCntrReg <= "1100";
			RTDataCntrReg <= "100100000"; --288 = int(2300/8)+1
		elsif rising_edge(clk) then
			state_reg <= state_next;
			paramCntrReg <= paramCntrNext;
			RTDataCntrReg <= RTDataCntrNext;
		end if;
	end process REG;
	
	NSL: process(state_reg, ASNNParamSet, ASRTDataReady, paramCntrEnd, RTDataCntrEnd, AMNbBurstCntrEnd)
	begin
		-- default
		state_next <= state_reg;
		AMCtrlInitState <= '0';
		RTDataCntrEnable <= '0';
		AMFifoWriteAllow <= '0';
		AMFetchNNParam <= '0';
		AMFetchRTData <= '0';
		case state_reg is
			when init =>
									AMCtrlInitState <= '1';
									StatusCtrller <= "000";
									if ASNNParamSet = '1' then
										state_next <= NNparamFetch;
									end if;
			when NNparamFetch =>
									AMFetchNNParam <= '1';
									AMFifoWriteAllow <= '1';
									StatusCtrller <= "001";
									if AMNbBurstCntrEnd = '1' then
										state_next <= incParamCounter;
									end if;
			when incParamCounter =>
									StatusCtrller <= "010";
									state_next <= WaitForFifo;
			when WaitForFifo => 
									StatusCtrller <= "011";
									if paramCntrEnd = '1' and FifoRdempty = '1' then
										state_next <= idle;
									elsif FifoRdempty = '1' then
										state_next <= NNparamFetch;
									end if;
			when idle =>
									StatusCtrller <= "100";
									if ASRTDataReady = '1' then
										state_next <= RTdataFetch;
									end if;
			when RTdataFetch =>
									StatusCtrller <= "101";
									AMFetchRTData <= '1';
									AMFifoWriteAllow <= '1';
									RTDataCntrEnable <= '1';
									if RTDataCntrEnd = '1' then
										state_next <= idle;
									end if;
			when others => state_next <= init;
		end case;			
	end process NSL;
	
	PARAM_CNTR: process(state_reg, paramCntrEnd, paramCntrReg)
	begin
		paramCntrNext <= paramCntrReg;
		if state_reg = incParamCounter and paramCntrEnd = '0' then
			paramCntrNext <= std_logic_vector(unsigned(paramCntrReg)-1);
		end if;
	end process PARAM_CNTR;
	
	paramCntrEnd <= '1' when paramCntrReg = "0000" else '0';
	
	RT_CNTR: process(RTDataCntrEnd, RTDataCntrReg, AMBurstCntrEnd, RTDataCntrEnable)
	begin
		RTDataCntrNext <= RTDataCntrReg;
		if AMBurstCntrEnd = '1' and RTDataCntrEnable = '1' and RTDataCntrEnd = '0' then
			RTDataCntrNext <= std_logic_vector(unsigned(RTDataCntrReg)-1);
		elsif RTDataCntrEnd = '1' then
			RTDataCntrNext <= "100100000"; -- 288 
		end if;
	end process RT_CNTR;
	
	-- distribute output signals
	ASStatusCtrller <= StatusCtrller;
	FBStatusCtrller <= StatusCtrller;
	
end architecture rtl;