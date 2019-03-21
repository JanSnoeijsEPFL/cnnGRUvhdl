library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity reg_file is
	generic(
		NBITS : natural := 6;
		NBREG : natural := 10
		);
	port(
		clk : in std_logic;
		rstB : in std_logic;
		--addr : in std_logic_vector(integer(ceil(log2(real(NBREG))))-1 downto 0);
		dataIn : in std_logic_vector(NBREG*NBITS-1 downto 0);
		dataOut : out std_logic_vector(NBREG*NBITS-1 downto 0);
		writeEn : in std_logic_vector(NBREG-1 downto 0)
		);
end entity reg_file;

architecture rtl of reg_file is
	type reg_array is array(NBREG-1 downto 0) of std_logic_vector(NBITS-1 downto 0); --6 bits
	signal RegReg, RegNext : reg_array;
begin
	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			RegReg <= (others => (others => '0'));
		elsif rising_edge(clk) then
			RegReg <= RegNext;
		end if;
	end process;
	
	WRITING: process(RegReg, dataIn, writeEn)
	begin
		RegNext <= RegReg;
		for i in 0 to NBREG-1 loop
			if writeEn(i) = '1' then
				RegNext(i) <= dataIn(i*NBITS+NBITS-1 downto i*NBITS);
			end if;
		end loop;
	end process WRITING;
	
	READING: process(RegReg)
	begin
		for i in 0 to NBREG-1 loop	
			dataOut(NBITS-1+i*NBITS downto i*NBITS) <= RegReg(i);
		end loop;
	end process READING;
	
end architecture rtl;