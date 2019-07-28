library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mac_matrix is
	generic(
		NBITS : natural := 6;
		NACC : natural :=11;
		MAC_MAX : natural :=100
	);
	port(
		in_a : in std_logic_vector(NBITS*MAC_MAX-1 downto 0);
		in_b : in std_logic_vector(NBITS*MAC_MAX-1 downto 0);
		macs_o : out std_logic_vector((2*NBITS+NACC)*MAC_MAX-1 downto 0);
		clk : in std_logic;
		rstB : in std_logic;
		clear : in std_logic_vector(MAC_MAX-1 downto 0)
	);
end entity mac_matrix;

architecture rtl of mac_matrix is
	type MAC_I is array (0 to MAC_MAX-1) of std_logic_vector(NBITS-1 downto 0);
	type MAC_O is array (0 to MAC_MAX-1) of std_logic_vector(2*NBITS+NACC-1 downto 0);
	signal in_a_arr : MAC_I;
	signal in_b_arr : MAC_I;
	signal macs_o_arr : MAC_O;
	
begin
	TO_ARRAY: process(in_a, in_b, macs_o_arr, clear)
	begin
		for i in 0 to MAC_MAX-1 loop
			in_a_arr(i) <= in_a(NBITS-1+i*NBITS downto 0+i*NBITS);
			in_b_arr(i) <= in_b(NBITS-1+i*NBITS downto 0+i*NBITS);
			macs_o(2*NBITS+NACC-1+i*(2*NBITS+NACC) downto 0+i*(2*NBITS+NACC)) <= macs_o_arr(i);
		end loop;
	end process;
	
	MACS : for i in 0 to MAC_MAX-1 generate
		mac_inst : entity work.mac(rtl)
		generic map(
			NBITS => NBITS,
			NACC => NACC
			)
		port map(
			mul_a => in_a_arr(i),
			mul_b => in_b_arr(i),
			mac_o => macs_o_arr(i),
			clk => clk,
			rstB => rstB,
			clear => clear(i)
			);
	end generate;
	
end architecture rtl;
