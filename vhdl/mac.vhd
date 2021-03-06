library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mac is
	generic(
		NBITS : natural := 6;
		NACC : natural := 11
	);
	port(
		mul_a  : in std_logic_vector(NBITS-1 downto 0);
		mul_b : in std_logic_vector(NBITS-1 downto 0);
		mac_o : out std_logic_vector(2*NBITS+NACC-1 downto 0);
		
		clk : in std_logic;
	   rstB : in std_logic;
		clear : in std_logic
	);
	
end entity mac;

architecture rtl of mac is
	signal mul_a_reg, mul_a_next : std_logic_vector(NBITS-1 downto 0);
	signal mul_b_reg, mul_b_next : std_logic_vector(NBITS-1 downto 0);
	signal acc_reg, acc_next : std_logic_vector(2*NBITS+NACC-1 downto 0);
	signal mul_o_reg, mul_o_next : std_logic_vector(2*NBITS-1 downto 0);
	--signal mul_o : std_logic_vector(2*NBITS-1 downto 0);
begin
	REG: process(clk, rstB)
	begin
		if rstB ='0' then
			acc_reg <= (others => '0');
			mul_a_reg <= (others => '0');
			mul_b_reg <= (others => '0');
			mul_o_reg <= (others => '0');
		elsif rising_edge(clk) then
			acc_reg <= acc_next;
			mul_a_reg <= mul_a_next;
			mul_b_reg <= mul_b_next;
			mul_o_reg <= mul_o_next;
		end if;
	end process;
	
	mul_a_next <= mul_a;
	mul_b_next <= mul_b;
	mul_o_next <= std_logic_vector(signed(mul_a_reg)*signed(mul_b_reg));
	acc_next <= std_logic_vector(resize(signed(acc_reg),acc_next'length)+resize(signed(mul_o_reg),acc_next'length)) when clear = '0' else
					std_logic_vector(resize(signed(mul_o_reg),acc_next'length));
	mac_o <= acc_reg when clear = '1' else (others => '0');
end architecture rtl;
