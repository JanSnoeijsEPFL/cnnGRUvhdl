library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity controller is
	port(
		clk : std_logic;
		rstB : std_logic;
		
		--interface with avalon slave
		ASNNParamSet : in std_logic;
		ASRTDataReady : in std_logic
		
		--interface with avalon master
		AMFetchNNParam : out std_logic;
		AMFetchRTData : out std_logic;
		AMFifoWriteAllow : in std_logic; -- allow writing data to FIFO
		AMFifoWriting : out std_logic; -- indicates data is being written in FIFO
		AMWriteResult : in std_logic; -- allows writing result to SDRAM
		AMReadingActive: out std_logic; -- set to indicate Master is reading data from SDRAM	
		
		);
end entity controller;

architecture rtl of controller is	
	type state_type is (init, NNparamFetch, WaitForFifo, idle, RTdataFetch);
	signal state_reg, state_next : state_type;
begin

	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			state_reg <= init;
		elsif rising_edge(clk) then
			state_reg <= state_next;
		end if;
	end process REG;
	
	NSL: process(state_reg, ASNNParamSet, ASRTDataReady)
	begin
		-- default
		state_next <= state_reg;
		case state_reg is
			when init =>
									if ASNNParamSet = '1' then
										state_next <= NNparamFetch;
									end if;
			when NNparamFetch =>
									--depends on value of burst counter here
									if BurstFinished then
										state_next <= WaitForFifo;
									end if;
			when WaitForFifo => 
									if AllParamRead then
										state_next <= idle;
									elsif FifoWrempty = '1' then
										state_next <= NNparamFetch;
									end if;
			when idle =>
									if ASNNRTDataReady = '1' then
										state_next <= RTdataFetch;
									end if;
			when RTdataFetch =>
									if DatastreamRead = '1' then
										state_next <= idle;
									end if;
			when others => state_next <= init;
		end case;			
	end proess NSL;
	
end architecture rtl;