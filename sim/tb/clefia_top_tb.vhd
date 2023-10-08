--------------------------------------------------------------------------------
-- Company: Instituto Superior Tcnico de Lisboa
-- Engineer: João Carlos Nunes Bittencourt
--
-- Design Name:   Testbench for CLEFIA with Full Key Expansion
-- Module Name:   clefia_top_tb
-- Project Name:  CLEFIA-256
-- Description:
-- 	Parametrized implementation of the main testbench for CLEFIA 256 projetc.
--    The aim of this test is to serve as a proff of functional compatibility
--    of the proposed implementation against Sony C code for CLEFIA.
--
-- Revision:
-- Revision 1.0 - File Created
-- Revision 2.0 - Test fully rewriten in order to deploy
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity clefia_top_tb is
end clefia_top_tb;

architecture behavior of clefia_top_tb is

	component clefia_top is
	port (
			clock 			: in std_logic;
       	reset 			: in std_logic;
       	start 			: in std_logic;
       	start_keyexp 	: in std_logic;
       	enc_dec			: in std_logic;
	   	expand_key		: in std_logic;
       	key_size_192 	: in std_logic;
       	key_size_256 	: in std_logic;
       	data_in 			: in std_logic_vector(31 downto 0);
       	--
       	data_out 		: out std_logic_vector(31 downto 0);
        	--
        	running_cipher	: out std_logic;
       	running_keyexp	: out std_logic;
       	done_keyexp 	: out std_logic;
			done_cipher		: out std_logic
	);
	end component;

	-- Clock period definitions
	constant clock_period : time := 10 ns;

	-- Design signals
  	signal clock 			: std_logic := '1';
  	signal reset 			: std_logic := '0';
  	signal start 			: std_logic := '0';
  	signal start_keyexp  : std_logic := '0';
  	signal data_in 		: std_logic_vector (31 downto 0) := (others => '0');
	-- Config signals
	signal expand_key 	: std_logic := '1';
  	signal enc_dec 		: std_logic := '0';
	signal key_size_192 	: std_logic := '0';
  	signal key_size_256 	: std_logic := '1';
  	-- output signals
  	signal data_out 		: std_logic_vector(31 downto 0);
  	signal running_cipher: std_logic;
  	signal running_keyexp: std_logic;
  	signal done_keyexp	: std_logic;
  	signal done_cipher	: std_logic;

  	-- Test Vetors
  	signal zeros 				: std_logic_vector (31 downto 0)  := (others => '0');
  	signal plain_text 		: std_logic_vector (127 downto 0) := X"000102030405060708090a0b0c0d0e0f";
	signal cipher_text_128	: std_logic_vector (127 downto 0) := X"de2bf2fd9b74aacdf1298555459494fd";
	signal cipher_text_192	: std_logic_vector (127 downto 0) := X"e2482f649f028dc480dda184fde181ad";
	signal cipher_text_256	: std_logic_vector (127 downto 0) := X"a1397814289de80c10da46d1fa48b38a";
  	-- Shared key
  	signal shared_key : std_logic_vector (255 downto 0) := X"ffeeddccbbaa99887766554433221100f0e0d0c0b0a090807060504030201000";
	-- Round counter signal
	signal round_counter : integer := 0;

begin

	dut : clefia_top
	port map (
			clock 			=> clock,
       	reset 			=> reset,
       	start 			=> start,
       	start_keyexp 	=> start_keyexp,
       	enc_dec			=> enc_dec,
	   	expand_key		=> expand_key,
       	key_size_192 	=> key_size_192,
       	key_size_256 	=> key_size_256,
       	--
       	data_in 			=> data_in,
        	--
        	data_out 		=> data_out,
        	running_cipher => running_cipher,
        	running_keyexp => running_keyexp,
        	done_keyexp 	=> done_keyexp,
        	done_cipher		=> done_cipher
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
		-- Configure before start (registers in a SoC)
		--expand_key <= '1';
		--key_size_192 <= '0';
		--key_size_256 <= '0';
		wait for clock_period;
		start <= '0';
		wait for clock_period;
		-- Input block and whitening keys
	    data_in 		<= shared_key(255 downto 224); 		-- K0/KL0
	    wait for clock_period;
	    data_in 		<= shared_key(224-1 downto 192); 		-- K1/KL1
	    wait for clock_period;
	    data_in 		<= shared_key(192-1 downto 160); 		-- K2/KL2
	    wait for clock_period;
	    data_in 		<= shared_key(160-1 downto 128); 		-- K3/KL3
	    if (key_size_192 = '1' or key_size_256 = '1') then
	    	wait for clock_period;
	    	data_in 		<= shared_key(128-1 downto 96); 	-- KR0
	    	wait for clock_period;
	    	data_in 		<= shared_key(96-1 downto 64); 	-- KR1
	    	if (key_size_256 = '1') then
	    		wait for clock_period;
	    		data_in 		<= shared_key(64-1 downto 32); -- KR2
	    		wait for clock_period;
	    		data_in 		<= shared_key(32-1 downto 0); 	-- KR3
	    	end if;
	    end if;
	    -- Done feed input block
	    wait for clock_period;
	    data_in 		<= zeros;
	    wait until done_keyexp = '1';
	    expand_key <= '0';
	    wait for 2*clock_period;
	    start <= '1';
	    enc_dec <= '0';
	    wait for clock_period;
	    start <= '0';
	    --wait for clock_period;
		if(enc_dec = '0') then
		    data_in 		<= plain_text(127 downto 96); -- P0
		    wait for clock_period;
		    data_in 		<= plain_text(95 downto 64); -- P1
		    wait for clock_period;
		    data_in 		<= plain_text(63 downto 32); -- P2
		    wait for clock_period;
		    data_in 		<= plain_text(31 downto 0); -- P3
		    -- Done feed input block
		    wait for clock_period;
		    data_in 		<= zeros;
		else
			if (key_size_192 = '0' and key_size_256 = '0') then
				data_in 		<= cipher_text_128(127 downto 96); -- C0
			   wait for clock_period;
			   data_in 		<= cipher_text_128(95 downto 64); -- C1
			   wait for clock_period;
			   data_in 		<= cipher_text_128(63 downto 32); -- C2
			   wait for clock_period;
			   data_in 		<= cipher_text_128(31 downto 0); -- C3
			elsif (key_size_192 = '1' and key_size_256 = '0') then
				data_in 		<= cipher_text_192(127 downto 96); -- C0
			   wait for clock_period;
			   data_in 		<= cipher_text_192(95 downto 64); -- C1
			   wait for clock_period;
			   data_in 		<= cipher_text_192(63 downto 32); -- C2
			   wait for clock_period;
			   data_in 		<= cipher_text_192(31 downto 0); -- C3
			else
				data_in 		<= cipher_text_256(127 downto 96); -- C0
			   wait for clock_period;
			   data_in 		<= cipher_text_256(95 downto 64); -- C1
			   wait for clock_period;
			   data_in 		<= cipher_text_256(63 downto 32); -- C2
			   wait for clock_period;
			   data_in 		<= cipher_text_256(31 downto 0); -- C3
			end if ;
		    -- Done feed input block
		    wait for clock_period;
		    data_in 		<= zeros;
		end if;
		-- second cipher
		wait until done_cipher = '1';

	   wait for 3*clock_period;
	   start <= '1';
	   enc_dec <= '0';
	   wait for clock_period;
	   start <= '0';
	    --wait for clock_period;
		if(enc_dec = '0') then
		    data_in 		<= plain_text(127 downto 96); -- P0
		    wait for clock_period;
		    data_in 		<= plain_text(95 downto 64); -- P1
		    wait for clock_period;
		    data_in 		<= plain_text(63 downto 32); -- P2
		    wait for clock_period;
		    data_in 		<= plain_text(31 downto 0); -- P3
		    -- Done feed input block
		    wait for clock_period;
		    data_in 		<= zeros;
		else
			if (key_size_192 = '0' and key_size_256 = '0') then
				data_in 		<= cipher_text_128(127 downto 96); -- C0
			   wait for clock_period;
			   data_in 		<= cipher_text_128(95 downto 64); -- C1
			   wait for clock_period;
			   data_in 		<= cipher_text_128(63 downto 32); -- C2
			   wait for clock_period;
			   data_in 		<= cipher_text_128(31 downto 0); -- C3
			elsif (key_size_192 = '1' and key_size_256 = '0') then
				data_in 		<= cipher_text_192(127 downto 96); -- C0
			   wait for clock_period;
			   data_in 		<= cipher_text_192(95 downto 64); -- C1
			   wait for clock_period;
			   data_in 		<= cipher_text_192(63 downto 32); -- C2
			   wait for clock_period;
			   data_in 		<= cipher_text_192(31 downto 0); -- C3
			else
				data_in 		<= cipher_text_256(127 downto 96); -- C0
			   wait for clock_period;
			   data_in 		<= cipher_text_256(95 downto 64); -- C1
			   wait for clock_period;
			   data_in 		<= cipher_text_256(63 downto 32); -- C2
			   wait for clock_period;
			   data_in 		<= cipher_text_256(31 downto 0); -- C3
			end if ;
		    -- Done feed input block
		    wait for clock_period;
		    data_in 		<= zeros;
		end if;

		wait until done_cipher = '1';
	   wait for clock_period*5;
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

	-- Just in case...
	--
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