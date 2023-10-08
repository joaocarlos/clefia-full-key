-------------------------------------------------------------------------------------
-- Engineer		: 	Joao Carlos Nunes Bittencourt
--
-- Design Name	:   Clefia 128 bits Block Cypher pipeline for 256 bits Key Scheduling
-- Module Name	:   keyexp_core
-- Project Name	:	Clefia 128 bits Block Cypher with Full Key Expansion
-- Description	:   CLEFIA Cipher Core Top Level entity
--
------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity clefia_top is
	port (
		clock 			: in std_logic;
		reset 			: in std_logic;
		start 			: in std_logic;
		enc_dec			: in std_logic;
		expand_key		: in std_logic;
		key_size_192 	: in std_logic;
		key_size_256 	: in std_logic;
		data_in 		: in std_logic_vector(31 downto 0);
		--
		data_out 		: out std_logic_vector(31 downto 0);
		--
		running_cipher	: out std_logic;
		running_keyexp	: out std_logic;
		done_keyexp 	: out std_logic;
		done_cipher		: out std_logic
	);
end clefia_top;

architecture behavioral of clefia_top is
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
			key_ready 		: out std_logic;
			done 			: out std_logic );
	end component;

	component cipher_core is
		port (
			clock 			: in std_logic;
			reset 			: in std_logic;
			start 			: in std_logic;
			enc_dec			: in std_logic;
			expand_key		: in std_logic;
			key_ready 		: in std_logic;
			key_size_192 	: in std_logic;
			key_size_256 	: in std_logic;
			--
			data_in 			: in std_logic_vector (31 downto 0);
			whitening_key	: in std_logic_vector (31 downto 0);
			round_key 		: in std_logic_vector (31 downto 0); -- without BRAM
			--
			data_out 		: out std_logic_vector (31 downto 0);
			round_key_addr : out std_logic_vector (5 downto 0); -- without BRAM
			running 			: out std_logic;
			done 				: out std_logic );
	end component;

	-- D-Flipflops
	component data_registry
		port(
			data_in 	: in std_logic_vector (31 downto 0);
			clk 		: in std_logic;
			enable 		: in std_logic;
			reset 		: in std_logic;
			data_out 	: out std_logic_vector (31 downto 0) );
	end component;

	-- Signals
	signal round_key_addr_i 	: std_logic_vector (5 downto 0);
	signal lkey_i 				: std_logic_vector (31 downto 0);
	signal lkey 				: std_logic_vector (31 downto 0);
	signal key_i 				: std_logic_vector (31 downto 0);
	signal round_key_i 			: std_logic_vector (31 downto 0);

	signal key_ready_i 			: std_logic;
	signal done_clefia_i 		: std_logic;

	begin
	keyexp_core_u0 : keyexp_core
	port map (
		clock 			=> clock,
		reset 			=> reset,
		start 			=> start,
		done_clefia 	=> done_clefia_i,
		enc_dec			=> enc_dec,
		expand_key		=> expand_key,
		key_size_192 	=> key_size_192,
		key_size_256 	=> key_size_256,
		--
		round_key_addr => round_key_addr_i,
		key_in 			=> data_in,
		lkey 				=> lkey_i,
		--
		key 				=> key_i,
		round_key 		=> round_key_i,
		running 			=> running_keyexp,
		key_ready 		=> key_ready_i,
		done 				=> done_keyexp
	);

	data_registry_0 : data_registry
	port map (
		data_in 		=> lkey,
		clk 			=> clock,
		enable 		=> '1',
		data_out 	=> lkey_i,
		reset 		=> reset
	);

	cipher_core_u0 : cipher_core
	port map (
		clock 			=> clock,
		reset 			=> reset,
		start 			=> start,
		key_ready 		=> key_ready_i,
		enc_dec			=> enc_dec,
		expand_key		=> expand_key,
		key_size_192 	=> key_size_192,
		key_size_256 	=> key_size_256,
		--
		data_in 			=> data_in,
		whitening_key	=> key_i,
		round_key 		=> round_key_i,
		--
		data_out 		=> lkey,
		round_key_addr => round_key_addr_i,
		running 			=> running_cipher,
		done 				=> done_clefia_i
	);

	done_cipher <= done_clefia_i;
	data_out 	<= lkey_i;

end;
