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

entity keyexp_core_tb is
end keyexp_core_tb;

architecture behavior of keyexp_core_tb is

	component keyexp_core is
		port (
			clock 			: in std_logic;
	       	reset 			: in std_logic;
	       	start 			: in std_logic;
	       	done_clefia 	: in std_logic;
	       	enc_dec			: in std_logic;
		   	expand_key		: in std_logic;
	       	key_size_192 	: in std_logic;
	       	key_size_256 	: in std_logic;
	       	--
	       	round_key_addr 	: in std_logic_vector (5 downto 0);
	    	key_in 			: in std_logic_vector (31 downto 0);
	    	lkey 			: in std_logic_vector (31 downto 0);
	        --
	        key 			: out std_logic_vector (31 downto 0);
	        round_key 		: out std_logic_vector (31 downto 0);
			running 		: out std_logic;
			done 			: out std_logic
		);
	end component;

	-- Clock period definitions
	constant clock_period : time := 10 ns;

	-- Design signals
  	signal clock 			: std_logic := '1';
  	signal reset 			: std_logic := '0';
  	signal start 			: std_logic := '0';
  	signal done_clefia 		: std_logic := '0';
  	signal round_key_addr 	: std_logic_vector (5 downto 0) := (others => '0');
	signal key_in 			: std_logic_vector(31 downto 0) := (others => '0');
	signal lkey 			: std_logic_vector(31 downto 0) := (others => '0');
	-- Config signals
	signal expand_key 		: std_logic := '0';
  	signal enc_dec 			: std_logic := '0';
	signal key_size_192 	: std_logic := '0';
  	signal key_size_256 	: std_logic := '1';
  	-- output signals
  	signal key 				: std_logic_vector(31 downto 0);
  	signal round_key		: std_logic_vector(31 downto 0);
  	signal done 			: std_logic;
  	signal running 			: std_logic;

  	-- Test Vetors
  	signal zeros 	: std_logic_vector (31 downto 0) := (others => '0');
  	-- Shared key
  	signal shared_key : std_logic_vector (255 downto 0) := X"ffeeddccbbaa99887766554433221100f0e0d0c0b0a090807060504030201000";
	-- L Keys
	signal lkey_128 : std_logic_vector (127 downto 0) := X"8f89a61b9db9d0f393e65627da0d027e";
	signal lkey_192 : std_logic_vector (255 downto 0) := X"db05415a800082db7cb8186cd788c5f31ca9b2e1b4606829c92dd35e2258a432";
	signal lkey_256 : std_logic_vector (255 downto 0) := X"477e8f0966ee53782cc2be04bf55e28fd6c10b894eeab57584bd5663cc933940";
	signal lkey_in 	: std_logic_vector (255 downto 0);
	-- Round counter signal
	signal round_counter : integer := 0;

begin

	dut : keyexp_core
		port map (
			clock 			=> clock,
	       	reset 			=> reset,
	       	start 			=> start,
	       	done_clefia 	=> done_clefia,
	       	enc_dec			=> enc_dec,
		   	expand_key		=> expand_key,
	       	key_size_192 	=> key_size_192,
	       	key_size_256 	=> key_size_256,
	       	--
	       	round_key_addr 	=> round_key_addr,
	    	key_in 			=> key_in,
	    	lkey 			=> lkey,
	        --
	        key 			=> key,
	        round_key 		=> round_key,
			running 		=> running,
			done 			=> done
		);

   	-- Clock
   	clock <= not clock after clock_period/2;

   	lkey_in <= 	lkey_128 & X"00000000000000000000000000000000" when key_size_192 = '0' and key_size_256 = '0' else
   				lkey_192 when key_size_192 = '1' and key_size_256  = '0' else
   				lkey_256;

  	-- Stimulus process
  	stim_proc: process
  	begin
		reset <= '1';
		wait for clock_period * 5;
		-- Configuration
		reset <= '0';
		start <= '1';
		expand_key <= '1';
		wait for clock_period;
		start <= '0';
		wait for clock_period;
		-- Input block and whitening keys
	    key_in 		<= shared_key(255 downto 224); 		-- K0/KL0
	    wait for clock_period;
	    key_in 		<= shared_key(224-1 downto 192); 		-- K1/KL1
	    wait for clock_period;
	    key_in 		<= shared_key(192-1 downto 160); 		-- K2/KL2
	    wait for clock_period;
	    key_in 		<= shared_key(160-1 downto 128); 		-- K3/KL3
	    if (key_size_192 = '1' or key_size_256 = '1') then
	    	wait for clock_period;
	    	key_in 		<= shared_key(128-1 downto 96); 	-- KR0
	    	wait for clock_period;
	    	key_in 		<= shared_key(96-1 downto 64); 	-- KR1
	    	if (key_size_256 = '1') then
	    		wait for clock_period;
	    		key_in 		<= shared_key(64-1 downto 32); -- KR2
	    		wait for clock_period;
	    		key_in 		<= shared_key(32-1 downto 0); 	-- KR3
	    	end if;
	    end if;
	    -- Done feed input block
	    wait for clock_period;
	    key_in 		<= zeros;
	    wait for clock_period*22;
	    done_clefia		<= '1';
	    wait for clock_period;
	    done_clefia		<= '0';
	    wait for clock_period;
		-- Input Lkey
	    lkey 		<= lkey_in(255 downto 224); 		-- L0/LL0
	    wait for clock_period;
	    lkey 		<= lkey_in(224-1 downto 192); 		-- L1/LL1
	    wait for clock_period;
	    lkey 		<= lkey_in(192-1 downto 160); 		-- L2/LL2
	    wait for clock_period;
	    lkey 		<= lkey_in(160-1 downto 128); 		-- L3/LL3
	    if (key_size_192 = '1' or key_size_256 = '1') then
	    	wait for clock_period;
	    	lkey 		<= lkey_in(128-1 downto 96); 	-- LR0
	    	wait for clock_period;
	    	lkey 		<= lkey_in(96-1 downto 64); 	-- LR1
	    	wait for clock_period;
	    	lkey 		<= lkey_in(64-1 downto 32); -- LR2
	    	wait for clock_period;
	    	lkey 		<= lkey_in(32-1 downto 0); 	-- LR3
	    end if;
	    wait for clock_period;
	    lkey <= zeros;
	    --wait for 62*clock_period;
	    wait until done = '1';
	    wait for 5*clock_period;
	    start <= '1';
	    wait for clock_period;
	    start <= '0';
	    wait for 50*clock_period;
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

end;