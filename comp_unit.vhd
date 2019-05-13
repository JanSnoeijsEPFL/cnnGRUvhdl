library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity comp_unit is
	generic(
		NBITS : natural := 6;
		NACC : natural := 11;
		NBFRAC : natural := 4
	);
	port(
		clk : in std_logic;
		rstB : in std_logic;
		--enable : in std_logic;
		in_x : in std_logic_vector(2*NBITS+NACC-1 downto 0);
		op_mux : in std_logic_vector(NBITS-1 downto 0);
		in_max : in std_logic_vector(2*NBITS+NACC-1 downto 0);
		in_min : in std_logic_vector(2*NBITS+NACC-1 downto 0);
		out_max : in std_logic_vector(NBITS-1 downto 0);
		out_min : in std_logic_vector(NBITS-1 downto 0);
		res : out std_logic_vector(NBITS-1 downto 0);
		round_out : out std_logic_vector(NBITS-1 downto 0);
		hs_out : out std_logic_vector(NBITS-1 downto 0)
	);
end entity comp_unit;

architecture rtl of comp_unit is
	signal res_reg, res_next : std_logic_vector(NBITS-1 downto 0);
	signal xtrunc : std_logic_vector(NBITS-1 downto 0);
	signal xfrac_lsb : std_logic;
	signal xEdge_cond : std_logic_vector(NBFRAC-1 downto 0);
	signal xround : std_logic_vector(NBITS-1 downto 0);
	begin

	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			res_reg <= (others => '0');
		elsif rising_edge(clk) then
			res_reg <= res_next;
		end if;
	end process;
	
	comp: process(in_x, in_max, in_min , out_max, out_min, op_mux, res_reg)
		variable x_signed : signed(2*NBITS+NACC-1 downto 0);
	begin
		res_next <= res_reg;
		x_signed := signed(in_x);
		--if enable = '1' then
			if x_signed(2*NBITS+NACC-1) = '0'  then -- positive number, compare to max only
				if x_signed >= signed(in_max) then
					res_next <= out_max;
				else
					res_next <= op_mux;
				end if;
			else
				if signed(in_min) >= x_signed then
					res_next <= out_min;
				else
					res_next <= op_mux;
				end if;
			end if;
		--end if;
	end process;
	
	xfrac_lsb <= in_x(NBFRAC-1); -- 4th Frac LSB
	xEdge_cond <= in_x(NBFRAC)&in_x(NBFRAC-2 downto 0); -- middle range edge condition
	
	xtrunc <= in_x(2*NBITS+NACC-1) & in_x(NBFRAC*2 downto NBFRAC);
	res <= res_reg;
	round: process(xfrac_lsb, xtrunc, xEdge_cond)
	begin
		if xfrac_lsb = '1' and xEdge_cond /= "0000" then
			xround <= std_logic_vector(signed(xtrunc)+1);
		else
			xround <= xtrunc;
		end if;
	end process;

	round_out <= xround;
	hs_out <= std_logic_vector(shift_right(signed(xround), 2)+8) when xround(1) = '0' or xround(2 downto 0) = "010" else
				std_logic_vector(shift_right(signed(xround), 2)+9); -- the shift right operation implies another truncation
	
end architecture;
 

	