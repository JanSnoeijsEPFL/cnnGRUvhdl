library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity comp_units_ctrl is
	generic(
		MAC_MAX : natural := 100;
		NBITS : natural := 6;
		NACC : natural := 11
	);
	port(
		clk : in std_logic;
		rstB : in std_logic;
		mode : in std_logic_vector(1 downto 0);
		round_line   : in  std_logic_vector(NBITS*MAC_MAX-1 downto 0);
		hs_line      : in  std_logic_vector(NBITS*MAC_MAX-1 downto 0);
		op_line  : out std_logic_vector(NBITS*MAC_MAX-1 downto 0);
		in_min_line  : out std_logic_vector((2*NBITS+NACC)*MAC_MAX-1 downto 0);
		in_max_line  : out std_logic_vector((2*NBITS+NACC)*MAC_MAX-1 downto 0);
		out_min_line : out std_logic_vector(NBITS*MAC_MAX-1 downto 0);
		out_max_line : out std_logic_vector(NBITS*MAC_MAX-1 downto 0)
		--res_line : in std_logic_vector(NBITS*MAC_MAX-1 downto 0)
	);
end entity comp_units_ctrl;

architecture rtl of comp_units_ctrl is

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
					

						
	dispatcher: for i in 0 to MAC_MAX-1 generate
		--op_mux_line(NBITS-1+i*NBITS downto 0+i*NBITS) <= op_mux;
		in_min_line((2*NBITS+NACC)-1+i*(2*NBITS+NACC) downto 0+i*(2*NBITS+NACC)) <= in_min;
		in_max_line((2*NBITS+NACC)-1+i*(2*NBITS+NACC) downto 0+i*(2*NBITS+NACC)) <= in_max;
		out_min_line(NBITS-1+i*NBITS downto 0+i*NBITS) <= out_min;
		out_max_line(NBITS-1+i*NBITS downto 0+i*NBITS) <= out_max;
	end generate;
	
	op_line <= round_line when (mode = "00" or mode = "01" or mode = "11") else
							hs_line when mode = "10" else (others => '0');
end architecture;
 

	
