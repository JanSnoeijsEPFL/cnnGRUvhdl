library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity shift_acc is
	generic(
		NBITS : natural := 6;
		FRACBITS : natural := 4;
		NACC : natural := 11;
	port(
		x : in std_logic_vector((NBITS-1)*NBITS-1 downto 0);
		w : in std_logic_vector((NBITS-1)*NBITS-1 downto 0);
		clk : in std_logic;
		rstB : in std_logic;
		
end entity shift_acc;

architecture rtl of shift_acc is
	type in_array is array(NBITS-2 downto 0) of std_logic_vector(NBITS-1 downto 0);
	type prod_array is array(NBITS-2 downto 0) of std_logic_vector(2*(NBITS-1) downto 0);
	type cntr_array is array(NBITS-2 downto 0) of std_logic_vector(2 downto 0);
	signal x_arr : in_array;
	signal w_arr : in_array;
	signal prod : prod_array; -- already registered in multiplier
	signal accReg, accNext : std_logic_vector(2*(NBITS-1)+NACC-1 downto 0);
	signal prodCntrReg, prodCntrNext :cntr_array;
	constant CntrMax : std_logic_vector(2 downto 0) := "101"; -- 5
	signal prodCntrEnd : std_logic;
	signal prodCntrFirstLoopReg, prodCntrFirstLoopNext: std_logic;
	
begin
	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			prodCntrReg <= (others => CntrMax);
			accReg <= (others => '0');
			prodCntrFirstLoopReg <= '0';
		elsif rising_edge(clk) then
			prodCntrReg <= prodCntrNext;
			accReg <= accNext;
			prodCntrFirstLoopReg <= prodCntrFirstLoopNext;
		end if;
	end process REG;
	
	CNTR: process(prodCntrReg)
	begin
		if prodCntrEnd = '0' then
			prodCntrNext(0) <= std_logic_vector(unsigned(prodCntrReg(0)) - 1);
		else
			prodCntrNext(0) <= CntrMax;
		end if;
		for i in 0 to NBITS-3 loop ---shift register to produce bit position for each multiplier
			prodCntrNext(i+1) <= prodCntrReg(i);
		end loop;
	end process CNTR;
	
	prodCntrEnd <= '1' when prodCntrReg(i) = "000" else '0';
	prodCntrFirstLoopNext <= '1' when prodCntrEnd = '1' else prodCntrFirstLoopReg;
	-- transfer vectorial format to array of std_logic_vect
	ARR: process(x, w)
	begin
		for i in 0 to NBITS-2 loop
			x_arr(i) <= x((NBITS-1)+NBITS*i downto NBITS*i);
			w_arr(i) <= w((NBITS-1)+NBITS*i downto NBITS*i);
		end loop;
	end process arr;
	
	SHIFT:
	for i in 0 to NBITS-2 generate
		multiplier: entity work.multiplier(rtl)
		generic map(
			NBITS => NBITS,
			NACC => NACC,
			FRACBITS => FRACBITS
		)
		port map(
			clk => clk,
			rstB => rstB,
			x => x_arr(i),-- needs to be synchronous (assuming this signal is a register's output)
			w => w_arr(i),-- needs to be synchronous (output of register)
			i => prodCntrReg(i),
			resOut => prod(i)
		);
	end generate MUL;
	
	ACC: process(prod, prodCntrReg, accReg, prodCntrFristLoopReg)
	variable i : integer;
	accNext <= accReg;
	begin
		i = to_integer(unsigned(prodCntrReg));
		if prodCntrFirstLoopReg = '1' then
			accNext <= std_logic_vector(signed(accReg)+signed(prod(NBITS-1-i)));
		end if;
	end process ACC;
end architecture rtl;
