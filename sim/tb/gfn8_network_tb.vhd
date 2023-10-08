--------------------------------------------------------------------------------
-- Company: Instituto Superior Tcnico de Lisboa
-- Engineer: Ricardo Chaves
--
-- Create Date:   00:15:17 05/07/2012
-- Design Name:   Core Testbench for 256 key
-- Module Name:   Core_256key_TB
-- Project Name:  CLEFIA
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: Core
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 1.0 - File Created
-- Additional Comments:
--
-- Notes: 
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity gfn8_network_tb is
end gfn8_network_tb;

architecture behavior OF gfn8_network_tb is

	component cipher_core is
	    port ( 
			clock 			: in std_logic;
	       	reset 			: in std_logic;
	       	start 			: in std_logic;
	       	key_ready 		: in std_logic;       	
	       	enc_dec			: in std_logic;
		   	expand_key		: in std_logic;
	       	key_size_192 	: in std_logic;
	       	key_size_256 	: in std_logic;
	       	--	
	    	data_in 		: in std_logic_vector (31 downto 0);
	        whitening_key	: in std_logic_vector(31 downto 0);
	        --
	        data_out 		: out std_logic_vector (31 downto 0);		
			running 		: out std_logic;
			done 			: out std_logic 
		);
	end component;

	-- Clock period definitions
	constant clock_period : time := 10 ns;	

	-- Design signals
  	signal clock 			: std_logic := '1';
  	signal reset 			: std_logic := '0';
  	signal whitening_key	: std_logic_vector(31 downto 0) := (others => '0');
  	signal start 			: std_logic := '0';
  	signal key_ready 		: std_logic := '1';
	signal data_in 			: std_logic_vector(31 downto 0) := (others => '0');
	-- Config signals
	signal expand_key 		: std_logic := '0';
  	signal enc_dec 			: std_logic := '0';
	signal key_size_192 	: std_logic := '0';
  	signal key_size_256 	: std_logic := '0';
  	-- output signals
  	signal data_out 		: std_logic_vector(31 downto 0);
  	signal done 			: std_logic;
  	signal running 			: std_logic;

  	-- Test Vetors
  	signal zeros 	: std_logic_vector ( 31 downto 0) := (others => '0');
  	signal wk_128 	: std_logic_vector (127 downto 0) := X"ffeeddccbbaa99887766554433221100";
  	signal wk_192 	: std_logic_vector (127 downto 0) := X"ffeeddccbbaa99887766554433221100" xor X"f0e0d0c0b0a090800011223344556677";
  	signal wk_256 	: std_logic_vector (127 downto 0) := X"ffeeddccbbaa99887766554433221100" xor X"f0e0d0c0b0a090807060504030201000";

  	-- Shared key
  	-- signal data_in_128 : std_logic_vector (255 downto 0) := X"ffeeddccbbaa9988776655443322110000000000000000000000000000000000";
  	-- signal data_in_192 : std_logic_vector (255 downto 0) := X"ffeeddccbbaa99887766554433221100f0e0d0c0b0a090800011223344556677";
  	signal shared_key : std_logic_vector (255 downto 0) := X"ffeeddccbbaa99887766554433221100f0e0d0c0b0a090807060504030201000";
	signal plain_text : std_logic_vector (127 downto 0) := X"000102030405060708090a0b0c0d0e0f";  	
	
	-- Round counter signal
	signal round_counter : integer := 0;	

begin

	clefia_core_dut : cipher_core
	    port map ( 
			clock 			=> clock,
	       	reset 			=> reset,
	       	start 			=> start,
	       	key_ready 		=> key_ready,	
	       	enc_dec			=> enc_dec,
		   	expand_key		=> expand_key,
	       	key_size_192 	=> key_size_192,
	       	key_size_256 	=> key_size_256,
	       	--	
	    	data_in 		=> data_in,
	        whitening_key	=> whitening_key,
	        --
	        data_out 		=> data_out,
			running 		=> running,
			done 			=> done
		);

   	-- Clock 
   	clock <= not clock after clock_period/2;

  	-- Stimulus process
  	stim_proc: process  
  	begin
		reset <= '1';
		wait for clock_period * 5;
		-- Configuration
		reset <= '0';
		start <= '1';
		expand_key <= '1';
		key_size_256 <= '1';
		wait for clock_period;
		start <= '0';
		wait for clock_period;
		-- Input shared key
		whitening_key 		<= shared_key(255 downto 224); -- KL0
		wait for clock_period;
		whitening_key 		<= shared_key(223 downto 192); -- KL1
		wait for clock_period;
		whitening_key 		<= shared_key(191 downto 160); -- KL2
		wait for clock_period;
		whitening_key 		<= shared_key(159 downto 128); -- KL3
		wait for clock_period;
	    whitening_key 		<= shared_key(127 downto 96);  -- KR0
	    wait for clock_period;
	    whitening_key 		<= shared_key(95 downto 64);   -- KR1
	    wait for clock_period;
	    whitening_key 		<= shared_key(63 downto 32);   -- KR2
	    wait for clock_period;
	    whitening_key 		<= shared_key(31 downto 0);    -- KR3
	    -- Done feed input shared key
	    wait for clock_period;
	    whitening_key 		<= zeros;
	    wait for clock_period * 50;
	   	wait until done = '1';
	    report "end of simulation" severity failure; -- pause simulation
	  	
	end process;

	-- Round counter process
	rcounter : process 
	begin
		if (start = '1') then
			round_counter <= round_counter + 1;
		elsif (round_counter /= 0) then 
			round_counter <= round_counter + 1;
		end if;
		wait for clock_period;
	end process;

  	-- Cyphered Output data
  	-- ciphertext: de2bf2fd 9b74aacd f1298555 459494fd (128 bits)
	-- ciphertext: e2482f64 9f028dc4 80dda184 fde181ad (192 bits)
	-- ciphertext: a1397814 289de80c 10da46d1 fa48b38a (256 bits)

	-- Key Expand expected results: 
	-- Expected Lkey for 128 bit key   = 8f89a61b 9db9d0f3 93e65627 da0d027e
	-- Expected Lkey L for 192 bit key = db05415a 800082db 7cb8186c d788c5f3
	-- Expected Lkey R for 192 bit key = 1ca9b2e1 b4606829 c92dd35e 2258a432	
	-- Expected Lkey L for 256 bit key = 477e8f09 66ee5378 2cc2be04 bf55e28f
	-- Expected Lkey R for 256 bit key = d6c10b89 4eeab575 84bd5663 cc933940 
end;