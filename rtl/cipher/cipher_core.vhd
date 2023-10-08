-------------------------------------------------------------------------------------
-- Company: Instituto Superior Tecnico de Lisboa
-- Engineer: Joao Carlos Nunes Bittencourt
--
-- Design Name:    CLEFIA implementation of the cipher core with hybrid support
--                 for both GFN_{4,n} and GFN_{8,n}
-- Module Name:    cipher_core
-- Project Name:   CLEFIA 256
-- Description:
-- 		CLEFIA Feistel Dual-Network GFN_4/8,n Wrapper
--
-- Revision:
-- Revision 1.0 -  Begining of tests
-- Revision 2.0 -  Add suport for GFN8 network
-- Revision 3.0 -  Fix minnor bugs for deploy
--
------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity cipher_core is
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
 		data_in 			: in std_logic_vector (31 downto 0);
     	whitening_key	: in std_logic_vector (31 downto 0);
     	---------------------------------------------------------------------------
		-- Comment the line bellow if you are using the Key Expansion module
		---------------------------------------------------------------------------
     	round_key 		: in std_logic_vector (31 downto 0); 	-- without BRAM
     	--
     	data_out 		: out std_logic_vector (31 downto 0);
     	---------------------------------------------------------------------------
		-- Comment the line bellow if you are using the Key Expansion module
		---------------------------------------------------------------------------
     	round_key_addr : out std_logic_vector (5 downto 0); 		-- without BRAM
		running 			: out std_logic;
		done 				: out std_logic
	);
end cipher_core;

architecture behavioral of cipher_core is

	component cipher_datapath is
    port (
		data_in 			: in std_logic_vector (31 downto 0);
		whitening_key 	: in std_logic_vector (31 downto 0);
		round_key 		: in std_logic_vector (31 downto 0);
      clock 			: in std_logic;
		reset 			: in std_logic;
		srl_address 	: in std_logic_vector (3 downto 0);
		reset_srl 		: in std_logic;
		sel0 				: in std_logic;
		sel1 				: in std_logic;
		sel2 				: in std_logic;
		sel3 				: in std_logic;
		t0_t1 			: in std_logic;
		data_out 		: out std_logic_vector (31 downto 0)
	);
	end component;

	component cipher_state_machine is
	   port (
			clock 			: in std_logic;
			reset 			: in std_logic;
			enc_dec 			: in std_logic;
			expand_key		: in std_logic;
			key_size_192 	: in std_logic;
			key_size_256 	: in std_logic;
			start 			: in std_logic;
			key_ready 		: in std_logic;
			-- output signals
			running 			: out std_logic;
			sel0 				: out std_logic;
			sel1 				: out std_logic;
			sel2 				: out std_logic;
			sel3 				: out std_logic;
			srl_addr 		: out std_logic_vector (3 downto 0);
			reset_srl 		: out std_logic;
			round_key_addr : out std_logic_vector (5 downto 0);
			t0_t1 			: out std_logic;
			done 				: out std_logic
		);
	end component;

	---------------------------------------------------------------------------
	-- Uncomment line bellow if you are using only the cipher core
	-- without Key Expansion module
	---------------------------------------------------------------------------
	--signal round_key 		: std_logic_vector (31 downto 0); -- with BRAM

	-- Component RK_BRAM Used only if you are not using the Key Expansion module
	--
	component RK_BRAM
	  	port (
		   clka 	: in std_logic;
		   reset : in std_logic;
		   addra : in std_logic_vector (5 downto 0);
		   douta : out std_logic_vector (31 downto 0)
	  	);
	end component;

	signal round_key_addr_i : std_logic_vector (5 downto 0);
	signal srl_address_i 	: std_logic_vector (3 downto 0);
	signal reset_srl_i 		: std_logic;
	signal sel0_i 				: std_logic;
	signal sel1_i 				: std_logic;
	signal sel2_i 				: std_logic;
	signal sel3_i 				: std_logic;
	signal t0_t1_i 			: std_logic;

begin

	cipher_state_machine_u0 : cipher_state_machine
   port map (
		clock 				=> clock,
		reset 				=> reset,
		enc_dec 			=> enc_dec,
		expand_key			=> expand_key,
		key_size_192 		=> key_size_192,
		key_size_256 		=> key_size_256,
		start 				=> start,
		key_ready 			=> key_ready,
		-- output signals
		running 			=> running,
		sel0 				=> sel0_i,
		sel1 				=> sel1_i,
		sel2 				=> sel2_i,
		sel3 				=> sel3_i,
		srl_addr 			=> srl_address_i,
		reset_srl 			=> reset_srl_i,
		round_key_addr 		=> round_key_addr_i,
		t0_t1 				=> t0_t1_i,
		done 				=> done
	);

	---------------------------------------------------------------------------
	-- Uncomment line bellow if you are using only the cipher core
	-- without Key Expansion module
	---------------------------------------------------------------------------
	--rk_bram_u0 : RK_BRAM
 	--port map (
	--   clka 	=> clock,
	--   reset => reset,
	--   addra => round_key_addr_i,
	--   douta => round_key
	--);

	---------------------------------------------------------------------------
	-- Comment the line bellow if you are using the Key Expansion module
	---------------------------------------------------------------------------
	round_key_addr <= round_key_addr_i;

	cipher_datapath_u0 : cipher_datapath
 	port map (
		data_in 			=> data_in,
		whitening_key 	=> whitening_key,
		round_key 		=> round_key,
   	clock 			=> clock,
		reset 			=> reset,
		srl_address 	=> srl_address_i,
		reset_srl 		=> reset_srl_i,
		sel0 				=> sel0_i,
		sel1 				=> sel1_i,
		sel2 				=> sel2_i,
		sel3 				=> sel3_i,
		t0_t1 			=> t0_t1_i,
		data_out 		=> data_out
	);

end behavioral;