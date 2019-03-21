library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity counter is
	generic(
		MAX_VAL: natural := 8
	);
	port(
		clk : in std_logic;
		rstB : in std_logic;
		CntrEnable : in std_logic;
		CntrReset : in std_logic;
		CntrVal : out std_logic_vector(integer(ceil(log2(real(MAX_VAL))))-1 downto 0);
		CntrEnd : out std_logic
	);
end entity counter;

architecture rtl of counter is
	constant CntrMax : std_logic_vector(integer(ceil(log2(real(MAX_VAL))))-1 downto 0) := std_logic_vector(to_unsigned(MAX_VAL, integer(ceil(log2(real(MAX_VAL))))));
	signal CntrReg, CntrNext : std_logic_vector(integer(ceil(log2(real(MAX_VAL))))-1 downto 0);
	signal CntrEndInternal : std_logic;
begin
	
	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			CntrReg <= (others => '0');
		elsif rising_edge(clk) then
			CntrReg <= CntrNext;
		end if;
	end process REG;
		
	CNTR: process(CntrReg, CntrEndInternal, CntrEnable, CntrReset)
	begin
		CntrNext <= CntrReg;
		if CntrEnable = '1' and CntrEndInternal = '0' then
			CntrNext <= std_logic_vector(unsigned(CntrReg) + 1);
		elsif CntrReset = '1' or CntrEndInternal = '1' then
			CntrNext <= (others => '0');
		end if;
	end process CNTR;
	
	CntrVal <= CntrReg;
	CntrEndInternal <= '1' when CntrReg = CntrMax else '0';
	CntrEnd <= CntrEndInternal;
end architecture rtl;