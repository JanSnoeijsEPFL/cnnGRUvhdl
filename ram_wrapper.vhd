library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ram_wrapper is
	port(
		--avalon
		uAddress_hps : in std_logic_vector(13 downto 0);
		wAddress_hps : in std_logic_vector(16 downto 0);
		xAddress_hps : in std_logic_vector(10 downto 0);
		
		uDataIn_hps : in std_logic_vector(31 downto 0);
		wDataIn_hps : in std_logic_vector(31 downto 0);
		xDataIn_hps : in std_logic_vector(31 downto 0);
		
		uDataOut_hps : out std_logic_vector(31 downto 0);
		wDataOut_hps : out std_logic_vector(31 downto 0);
		xDataOut_hps : out std_logic_vector(31 downto 0);
		
		uWren_hps : in std_logic;
		wWren_hps : in std_logic;
		xWren_hps : in std_logic;
		
		uReadEn : in std_logic;
		wReadEn : in std_logic;
		xReadEn : in std_logic;
		
		clk  : in std_logic;
		rstB : in std_logic;
		
		-- to accelerator
		uAddress_acc : in std_logic_vector(8 downto 0);
		wAddress_acc : in std_logic_vector(11 downto 0);
		xAddress_acc : in std_logic_vector(5 downto 0);
		
		uDataIn_acc : in std_logic_vector(599 downto 0);
		wDataIn_acc : in std_logic_vector(599 downto 0);
		xDataIn_acc : in std_logic_vector(599 downto 0);
		
		uDataOut_acc : out std_logic_vector(599 downto 0);
		wDataOut_acc : out std_logic_vector(599 downto 0);
		xDataOut_acc : out std_logic_vector(599 downto 0);
		
		uWren_acc : in std_logic;
		wWren_acc : in std_logic;
		xWren_acc : in std_logic
	);
end entity ram_wrapper;

architecture rtl of ram_wrapper is


	component gruURAM
		PORT
		(
			address_a		: IN STD_LOGIC_VECTOR (8 DOWNTO 0);
			address_b		: IN STD_LOGIC_VECTOR (8 DOWNTO 0);
			clock		: IN STD_LOGIC  := '1';
			data_a		: IN STD_LOGIC_VECTOR (599 DOWNTO 0);
			data_b		: IN STD_LOGIC_VECTOR (599 DOWNTO 0);
			wren_a		: IN STD_LOGIC  := '0';
			wren_b		: IN STD_LOGIC  := '0';
			q_a		: OUT STD_LOGIC_VECTOR (599 DOWNTO 0);
			q_b		: OUT STD_LOGIC_VECTOR (599 DOWNTO 0);
			byteena_b		: IN STD_LOGIC_VECTOR (59 DOWNTO 0) :=  (OTHERS => '1')
		);
	end component gruURAM;
		
	component gruWRAM
		PORT
		(
			address_a		: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
			address_b		: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
			clock		: IN STD_LOGIC  := '1';
			data_a		: IN STD_LOGIC_VECTOR (599 DOWNTO 0);
			data_b		: IN STD_LOGIC_VECTOR (599 DOWNTO 0);
			wren_a		: IN STD_LOGIC  := '0';
			wren_b		: IN STD_LOGIC  := '0';
			q_a		: OUT STD_LOGIC_VECTOR (599 DOWNTO 0);
			q_b		: OUT STD_LOGIC_VECTOR (599 DOWNTO 0);
			byteena_b		: IN STD_LOGIC_VECTOR (59 DOWNTO 0) :=  (OTHERS => '1')
		);
		end component gruWRAM;
		
		component xRAM
		PORT
		(
			address_a		: IN STD_LOGIC_VECTOR (5 DOWNTO 0);
			address_b		: IN STD_LOGIC_VECTOR (5 DOWNTO 0);
			clock		: IN STD_LOGIC  := '1';
			data_a		: IN STD_LOGIC_VECTOR (599 DOWNTO 0);
			data_b		: IN STD_LOGIC_VECTOR (599 DOWNTO 0);
			wren_a		: IN STD_LOGIC  := '0';
			wren_b		: IN STD_LOGIC  := '0';
			q_a		: OUT STD_LOGIC_VECTOR (599 DOWNTO 0);
			q_b		: OUT STD_LOGIC_VECTOR (599 DOWNTO 0);
			byteena_b		: IN STD_LOGIC_VECTOR (59 DOWNTO 0) :=  (OTHERS => '1')
		);
	end component xRAM;
	
	constant ZERO: std_logic_vector(569 downto 0) := (others => '0');
	constant mask : std_logic_vector(59 downto 0) := (0|1|2 => '1', others => '0');
--	signal maskShift : integer;
	signal uAddress_b : std_logic_vector(8 downto 0);
	signal wAddress_b : std_logic_vector(11 downto 0);
	signal xAddress_b : std_logic_vector(5 downto 0);
	
	signal uDataIn_b : std_logic_vector(599 downto 0);
	signal wDataIn_b : std_logic_vector(599 downto 0);
	signal xDataIn_b : std_logic_vector(599 downto 0);
	
	signal uDataOut_b : std_logic_vector(599 downto 0);
	signal wDataOut_b : std_logic_vector(599 downto 0);
	signal xDataOut_b : std_logic_vector(599 downto 0);
	
	signal uByteEnable : std_logic_vector(59 downto 0);
	signal wByteEnable : std_logic_vector(59 downto 0);
	signal xByteEnable : std_logic_vector(59 downto 0);
begin
	
	uOCRAM : component gruURAM
	port map(
			address_a => uAddress_acc,
			address_b => uAddress_b,
			clock		=> clk,
			data_a   => uDataIn_acc,
			data_b	=> uDataIn_b,
			wren_a	=> uWren_acc,
			wren_b	=> uWren_hps,
			q_a		=> uDataOut_acc,
			q_b		=> uDataOut_b,
			byteena_b => uByteEnable
			
	);
	
	wOCRAM : component gruWRAM
	port map(
			address_a => wAddress_acc,
			address_b => wAddress_b,
			clock		=> clk,
			data_a   => wDataIn_acc,
			data_b	=> wDataIn_b,
			wren_a	=> wWren_acc,
			wren_b	=> wWren_hps,
			q_a		=> wDataOut_acc,
			q_b		=> wDataOut_b,
			byteena_b => wByteEnable
	);
	
	xOCRAM : component xRAM
	port map(
			address_a => xAddress_acc,
			address_b => xAddress_b,
			clock		=> clk,
			data_a   => xDataIn_acc,
			data_b	=> xDataIn_b,
			wren_a	=> xWren_acc,
			wren_b	=> xWren_hps,
			q_a		=> xDataOut_acc,
			q_b		=> xDataOut_b,
			byteena_b => xByteEnable
	);
		
	
	uDataIn_b <= std_logic_vector(shift_left(unsigned(ZERO&uDataIn_hps(29 downto 0)), to_integer(unsigned(uAddress_hps(4 downto 0)))*30)) when uWren_hps = '1';
	wDataIn_b <= std_logic_vector(shift_left(unsigned(ZERO&wDataIn_hps(29 downto 0)), to_integer(unsigned(wAddress_hps(4 downto 0)))*30)) when wWren_hps = '1';
	xDataIn_b <= std_logic_vector(shift_left(unsigned(ZERO&xDataIn_hps(29 downto 0)), to_integer(unsigned(xAddress_hps(4 downto 0)))*30)) when xWren_hps = '1';
	
	
	uAddress_b <= uAddress_hps(13 downto 5);
	wAddress_b <= wAddress_hps(16 downto 5);
	xAddress_b <= xAddress_hps(10 downto 5);
	
	uByteEnable <= std_logic_vector(shift_left(unsigned(mask),3*to_integer(unsigned(uAddress_hps(4 downto 0))))) when uWren_hps = '1' else (others => '0');
	wByteEnable <= std_logic_vector(shift_left(unsigned(mask),3*to_integer(unsigned(wAddress_hps(4 downto 0))))) when wWren_hps = '1' else (others => '0');
	xByteEnable <= std_logic_vector(shift_left(unsigned(mask),3*to_integer(unsigned(xAddress_hps(4 downto 0))))) when xWren_hps = '1' else (others => '0');
	
	uread: process(uDataOut_b, uReadEn)
	begin
		uDataOut_hps <= (others => '0');
		if uReadEn = '1' then
			uDataOut_hps(29 downto 0) <= uDataOut_b( 29+to_integer(unsigned(uAddress_hps(4 downto 0)))*30 downto 0+to_integer(unsigned(uAddress_hps(4 downto 0)))*30);
		end if;
	end process;
	
	wread: process(wDataOut_b, wReadEn)
	begin
		 wDataOut_hps <= (others => '0');
		 if wReadEn = '1' then
			wDataOut_hps(29 downto 0) <= wDataOut_b( 29+to_integer(unsigned(wAddress_hps(4 downto 0)))*30 downto 0+to_integer(unsigned(wAddress_hps(4 downto 0)))*30);
		end if;
	end process;
	
	xread: process(xDataOut_b, xReadEn)
	begin
		 xDataOut_hps <= (others => '0');
		 if xReadEn = '1' then
			xDataOut_hps(29 downto 0) <= xDataOut_b( 29+to_integer(unsigned(xAddress_hps(4 downto 0)))*30 downto 0+to_integer(unsigned(xAddress_hps(4 downto 0)))*30);
		end if;
	end process;

end architecture rtl;



