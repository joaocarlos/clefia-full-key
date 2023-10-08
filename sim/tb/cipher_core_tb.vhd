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

entity cipher_core_tb is
end cipher_core_tb;

architecture behavior OF cipher_core_tb is

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
  	signal key_ready 		: std_logic := '0';
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
  	-- signal data_in_192 : std_logic_vector (255 downto 0) := X"ffeeddcc bbaa9988 77665544 33221100 f0e0d0c0 b0a09080 -- 00112233 44556677";
  	signal shared_key : std_logic_vector (255 downto 0) := X"ffeeddccbbaa99887766554433221100f0e0d0c0b0a090807060504030201000";
	signal plain_text : std_logic_vector (127 downto 0) := X"000102030405060708090a0b0c0d0e0f";
	signal cipher_text: std_logic_vector (127 downto 0) := X"de2bf2fd9b74aacdf1298555459494fd";

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
		wait for clock_period;
		start <= '1';
		wait for clock_period;
		start <= '0';
		--wait for clock_period;
		-- Input block and whitening keys
		if(enc_dec = '0') then
		    data_in 		<= plain_text(127 downto 96); -- P0
		    whitening_key 	<= zeros;
		    wait for clock_period;
		    data_in 		<= plain_text(95 downto 64); -- P1
		    whitening_key 	<= wk_128(127 downto 96); -- WK0
		    wait for clock_period;
		    data_in 		<= plain_text(63 downto 32); -- P2
		    whitening_key 	<= zeros;
		    wait for clock_period;
		    data_in 		<= plain_text(31 downto 0); -- P3
		    whitening_key 	<= wk_128(95 downto 64); -- WK1
		    -- Done feed input block
		    wait for clock_period;
		    whitening_key 	<= zeros;
		    data_in 		<= zeros;
		    wait for clock_period * 35;
		    whitening_key 	<= wk_128(63 downto 32); -- WL2
		    wait for clock_period;
		    --whitening_key 	<= zeros;
		    --wait for clock_period;
		    whitening_key 	<= wk_128(31 downto 0); -- WL3
		    wait for clock_period;
		    whitening_key 	<= zeros;
		else
		    data_in 		<= cipher_text(127 downto 96); -- C0
		    whitening_key 	<= zeros;
		    wait for clock_period;
		    data_in 		<= cipher_text(95 downto 64); -- C1
		    whitening_key 	<= wk_128(63 downto 32); -- WK2
		    wait for clock_period;
		    data_in 		<= cipher_text(63 downto 32); -- C2
		    whitening_key 	<= zeros;
		    wait for clock_period;
		    data_in 		<= cipher_text(31 downto 0); -- C3
		    whitening_key 	<= wk_128(31 downto 0); -- WK3
		    -- Done feed input block
		    wait for clock_period;
		    whitening_key 	<= zeros;
		    data_in 		<= zeros;
		    wait for clock_period * 35;
		    whitening_key 	<= wk_128(95 downto 64); -- WK1
		    wait for clock_period;
		    whitening_key 	<= wk_128(127 downto 96); -- WK0
		    wait for clock_period;
		    whitening_key 	<= zeros;
		end if;
	    wait for clock_period*4;
	    --stop(0);
	    report "end of simulation" severity failure; -- pause simulation
	    -- wait until done = '1';

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