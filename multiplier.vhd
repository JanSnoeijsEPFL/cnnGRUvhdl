library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity multiplier is
	generic(
		NBITS : natural := 6;
		NACC : natural := 11;
		FRACBITS : natural := 4
		);
	port(
		clk : in std_logic;
		rstB : in std_logic;
		x : in std_logic_vector(NBITS-1 downto 0); -- needs to be synchronous (assuming this signal is a register's output)
		w: in std_logic_vector(NBITS-1 downto 0); -- needs to be synchronous (output of register)
		i : in std_Logic_vector(integer(ceil(log2(real(NBITS-1))))-1 downto 0)
		resOut : out std_logic_vector(2*(NBITS-1) downto 0);
	);
	
end entity multiplier;

architecture rtl of multiplier
	signal prodReg, prodNext : std_logic_vector(2*(NBITS-1) downto 0);
	--type partialprods is array(NBITS-2 downto 0) of std_logic_vector(2*(NBITS-1) downto 0);
	--signal x_shifted : partialprods;
	signal partprod : unsigned(2*(NBITS-1) downto 0);
	signal signextend : std_logic_vector(NBITS-1 downto 0);
begin

	REG : process(clk, rstB)
	begin
		if rstB = '0' then
			prodReg <= (others => '0');
		elsif rising_edge(clk) then
			prodReg <= ProdNext;
	end process REG;
	
	PP : process(x, w, i)
	begin -- partprod is no register but is assumed synchronous
			-- inputs should be maintained for 1 clock cycle
			if w(i) = '1' then
				partprod <= shift_left(signed(signextend & x(NBITS-1 downto 0)),i);
			else
				partprod <= (others => '0');
			end if;
	end process PP;
	
	signextend <= (others => x(NBITS-1));
	
	Prod: process(partprod, prodReg)
	prodNext <= prodReg
	begin
		prodNext <= std_logic_vector(signed(partprod) + signed(prodReg));
	end process;
	
	resOut <= prodReg;
		
end architecture rtl;