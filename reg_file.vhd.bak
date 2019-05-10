library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity param_reg_file is
	generic(
		NBITS : natural := 6;
		FRACBITS : natural := 4;
		NBREG : natural := 3600
		--NBPARAM : natural := 354013;
		--NBCONV : natural := 2;
		--NBWGRU : natural :=  17967;  -- x3 -- overlap between lines of matrices
		--NBUGRU : natural := 1667;  -- x3 -- overlap between lines
		--NBBGRU : natural := 17; -- x3
		--NBWDENSE : natural :=50 -- overlap between lines
		--NBBDENSE : natural := 1;
		);
	port(
		clk : in std_logic;
		rstB : in std_logic;
		--addr : in std_logic_vector(integer(ceil(log2(real(NBREG))))-1 downto 0);
		dataIn : in std_logic_vector(NBREG*(NBITS-1)*NBITS-1 downto 0);
		dataOut : out std_logic_vector(NBREG*(NBITS-1)*NBITS-1 downto 0);
		writeEn : in std_logic_vector(NBREG-1 downto 0)
		);
end entity param_reg_file;

architecture rtl of param_reg_file is
	type reg_array is array(NBREG-1 downto 0) of std_logic_vector((NBITS-1)*NBITS-1 downto 0); --31 bits (30 for data + 1 for write Enable)
	signal paramReg, paramNext : reg_array;
begin
	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			paramReg <= (others => (others => '0'));
		elsif rising_edge(clk) then
			paramReg <= paramNext;
		end if;
	end process;
	
	WRITING: process(paramReg, dataIn, writeEn)
	begin
		paramNext <= paramReg;
		for i in 0 to NBREG-1 loop
			if writeEn(i) = '1' then
				paramNext(i) <= dataIn((NBITS-1)*NBITS-1+i*(NBITS-1)*NBITS downto i*(NBITS-1)*NBITS);
			end if;
		end loop;
	end process WRITING;
	
	READING: process(paramReg)
	begin
		for i in 0 to NBREG-1 loop	
			dataOut((NBITS-1)*NBITS-1+i*(NBITS-1)*NBITS downto i*(NBITS-1)*NBITS) <= paramReg(i);
		end loop;
	end process READING;
	
end architecture rtl;