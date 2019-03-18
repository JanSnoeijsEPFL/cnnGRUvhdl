library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity accelerator is
	generic(
		NBITS : natural := 6;
		FRACBITS : natural := 4;
		NACC : natural := 11;
		NBREG : natural := 59007
	);
	port(
		clk : in std_logic;
		rstB : in std_logic;
		
		-- avalon master
		AMburstcount : out std_logic_vector(3 downto 0);
		AMwaitrequest : in std_logic;
		AMreadEn : out std_logic;
		AMwriteEn : out std_logic;
		AMreaddata : in std_logic_vector(31 downto 0);
		AMwritedata : out std_logic_vector(31 downto 0);
		AMaddressRead : out std_logic_vector(31 downto 0);
		AMaddressWrite : out std_logic_vector(31 downto 0);
		AMbyteenable : out std_logic_vector(3 downto 0);
		
		-- avalon slave
		ASreadEn : in std_logic;
		ASwriteEn : in std_logic;
		ASregAddress : in std_logic_vector(2 downto 0);
		ASreaddata : out std_logic_vector(31 downto 0);
		ASwritedata : in std_logic_vector(31 downto 0)
	);
end entity accelerator;

architecture rtl of accelerator is

	component fifo
	generic (
		add_ram_output_register	:	string := "OFF";
		add_usedw_msb_bit	:	string := "OFF";
		clocks_are_synchronized	:	string := "FALSE";
		delay_rdusedw	:	natural := 1;
		delay_wrusedw	:	natural := 1;
		intended_device_family	:	string := "unused";
		enable_ecc	:	string := "FALSE";
		lpm_numwords	:	natural;
		lpm_showahead	:	string := "OFF";
		lpm_width	:	natural;
		lpm_widthu	:	natural := 1;
		overflow_checking	:	string := "ON";
		rdsync_delaypipe	:	natural := 0;
		read_aclr_synch	:	string := "OFF";
		underflow_checking	:	string := "ON";
		use_eab	:	string := "ON";
		write_aclr_synch	:	string := "OFF";
		wrsync_delaypipe	:	natural := 0;
		lpm_hint	:	string := "UNUSED";
		lpm_type	:	string := "dcfifo"
	);
	port(
		aclr	:	in std_logic := '0';
		data	:	in std_logic_vector(lpm_width-1 downto 0);
		eccstatus	:	out std_logic_vector(2-1 downto 0);
		q	:	out std_logic_vector(lpm_width-1 downto 0);
		rdclk	:	in std_logic;
		rdempty	:	out std_logic;
		rdfull	:	out std_logic;
		rdreq	:	in std_logic;
		rdusedw	:	out std_logic_vector(lpm_widthu-1 downto 0);
		wrclk	:	in std_logic;
		wrempty	:	out std_logic;
		wrfull	:	out std_logic;
		wrreq	:	in std_logic;
		wrusedw	:	out std_logic_vector(lpm_widthu-1 downto 0)
	);
end component;
begin
	
end architecture rtl;
