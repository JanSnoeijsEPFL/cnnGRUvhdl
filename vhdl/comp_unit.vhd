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
		mode : in std_logic_vector(1 downto 0);
		in_x : in std_logic_vector(2*NBITS+NACC-1 downto 0);
		res : out std_logic_vector(NBITS-1 downto 0)
	);
end entity comp_unit;

architecture rtl of comp_unit is
	signal res_reg, res_next : std_logic_vector(NBITS-1 downto 0);
	signal xtrunc : std_logic_vector(NBITS-1 downto 0);
	signal xfrac_lsb : std_logic;
	signal xEdge_cond : std_logic_vector(NBFRAC-1 downto 0);
	signal round_out : std_logic_vector(NBITS-1 downto 0);
	signal hs_out : std_logic_vector(NBITS-1 downto 0);
	
	constant QUANT_MAX_IN : std_logic_vector(2*NBITS+NACC-1 downto 0) := std_logic_vector(to_signed(496, 2*NBITS+NACC)); -- 1.9375 * 2^8
	constant QUANT_MIN_IN : std_logic_vector(2*NBITS+NACC-1 downto 0) := std_logic_vector(to_signed(-512, 2*NBITS+NACC)); -- -2 * 2^8
	constant HT_MAX_IN    : std_logic_vector(2*NBITS+NACC-1 downto 0) := std_logic_vector(to_signed(256, 2*NBITS+NACC)); -- 1 * 2^8
	constant HT_MIN_IN	 : std_logic_vector(2*NBITS+NACC-1 downto 0) := std_logic_vector(to_signed(-256, 2*NBITS+NACC)); -- -1 * 2^8
	
	constant QUANT_MAX_OUT : std_logic_vector(NBITS-1 downto 0) := std_logic_vector(to_signed(31, NBITS)); -- 1.9375 * 2^4
	constant QUANT_MIN_OUT : std_logic_vector(NBITS-1 downto 0) := std_logic_vector(to_signed(-32, NBITS)); -- -2 * 2^4
	constant HS_MAX 	 : std_logic_vector(NBITS-1 downto 0) := std_logic_vector(to_signed(16, NBITS)); -- 1 * 2^4 (FOR OUT MUX)
	constant HS_MIN    : std_logic_vector(NBITS-1 downto 0) := std_logic_vector(to_signed(0, NBITS)); -- 0 * 2^4 (FOR OUT MUX)
	constant HT_MAX_OUT    : std_logic_vector(NBITS-1 downto 0) := std_logic_vector(to_signed(16, NBITS)); -- 1 * 2^4
	constant HT_MIN_OUT	 : std_logic_vector(NBITS-1 downto 0) := std_logic_vector(to_signed(-16, NBITS)); -- -1 * 2^4
	 -- branched to accumulators with output registers --> no need to add an input register
	 --mode : "00" --> quantize
	 --       "01" --> relu & quantize
	 --       "10" --> hard_sigmoid 
	 --		 "11" --> hard_tanh
	--signal mode : std_logic_vector(1 downto 0);
	signal in_max : std_logic_vector(2*NBITS+NACC-1 downto 0);
	signal in_min : std_logic_vector(2*NBITS+NACC-1 downto 0);
	signal out_max : std_logic_vector(NBITS-1 downto 0);
	signal out_min : std_logic_vector(NBITS-1 downto 0);
	
	begin

	REG: process(clk, rstB)
	begin
		if rstB = '0' then
			res_reg <= (others => '0');
		elsif rising_edge(clk) then
			res_reg <= res_next;
		end if;
	end process;
	
	comp: process(in_x, in_max, in_min , out_max, out_min, round_out, hs_out, res_reg, mode)
		variable x_signed : signed(2*NBITS+NACC-1 downto 0);
	begin
		res_next <= res_reg;
		x_signed := signed(in_x);
		--if enable = '1' then
			if x_signed(2*NBITS+NACC-1) = '0'  then -- positive number, compare to max only
				if x_signed >= signed(in_max) then
					res_next <= out_max;
				elsif mode = "10" then
					res_next <= hs_out;
				else
					res_next <= round_out;
				end if;
			else
				if signed(in_min) >= x_signed then
					res_next <= out_min;
				elsif mode = "10" then
					res_next <= hs_out;
				else
					res_next <= round_out;
				end if;
			end if;
		--end if;
	end process;
	
		
	in_max <=  QUANT_MAX_IN when mode = "00" else
				  QUANT_MAX_IN when mode = "01" else
				  QUANT_MAX_IN when mode = "10" else
				  HT_MAX_IN when mode = "11" else (others => '0');
					  
				
	in_min <=  QUANT_MIN_IN when mode = "00" else
				  (others => '0') when mode = "01" else
				  QUANT_MIN_IN when mode = "10" else
				  HT_MIN_IN when mode = "11" else (others => '0');

					  
	out_max <=  QUANT_MAX_OUT when mode = "00" else
					QUANT_MAX_OUT when mode = "01" else
					HS_MAX when mode = "10" else
					HT_MAX_OUT when mode = "11" else (others => '0');
	
	out_min <=  QUANT_MIN_OUT when mode = "00" else
					(others => '0') when mode = "01" else
					HS_MIN when mode = "10" else
					HT_MIN_OUT when mode = "11" else (others => '0');
	
	
	xfrac_lsb <= in_x(NBFRAC-1); -- 4th Frac LSB
	xEdge_cond <= in_x(NBFRAC)&in_x(NBFRAC-2 downto 0); -- middle range edge condition
	
	xtrunc <= in_x(2*NBITS+NACC-1) & in_x(NBFRAC*2 downto NBFRAC);
	res <= res_reg;
	round: process(xfrac_lsb, xtrunc, xEdge_cond)
	begin
		if xfrac_lsb = '1' and xEdge_cond /= "0000" then
			round_out <= std_logic_vector(signed(xtrunc)+to_signed(1, round_out'length));
		else
			round_out <= xtrunc;
		end if;
	end process;
	
	hs_out <= std_logic_vector(shift_right(signed(xtrunc), 2)+to_signed(8, hs_out'length)) when (in_x(NBFRAC+2-1)= '0' or in_x(NBFRAC+2 downto 0) = "0100000") else
				std_logic_vector(shift_right(signed(xtrunc), 2)+to_signed(9, hs_out'length)); -- the shift right operation implies another truncation
	
end architecture;
 

	
