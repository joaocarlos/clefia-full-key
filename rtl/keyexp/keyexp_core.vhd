-------------------------------------------------------------------------------------
-- Company: Instituto Superior Tecnico de Lisboa
-- Engineer: Joao Carlos Nunes Bittencourt
--
-- Design Name:    CLEFIA implementation of the cipher core with hybrid support
--                 for both GFN_{4,n} and GFN_{8,n}
-- Module Name:    keyexp_core
-- Project Name:   CLEFIA 256
-- Description:
-- 		CLEFIA Key Expansion module wrapper
--
-- Revision:
-- Revision 1.0 -  Initial
-- Revision 2.0 -  Fix minnor bugs for deploy
--
------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity keyexp_core is
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
    	round_key_addr : in std_logic_vector (5 downto 0);
    	key_in 			: in std_logic_vector (31 downto 0);
    	lkey 				: in std_logic_vector (31 downto 0);
     	--
     	key 				: out std_logic_vector (31 downto 0);
     	round_key 		: out std_logic_vector (31 downto 0);
		running 			: out std_logic;
		key_ready 		: out std_logic;
		done 				: out std_logic
	);
end keyexp_core;

architecture behavioral of keyexp_core is
	component keyexp_state_machine is
		port (
			clock 				: in std_logic;
			reset 				: in std_logic;
			enc_dec				: in std_logic;
			expand_key			: in std_logic;
			key_size_192 		: in std_logic;
			key_size_256 		: in std_logic;
			start 				: in std_logic;
			done_clefia 		: in std_logic;
			round_key_raddr	: in std_logic_vector (5 downto 0); -- from cipher module
			-- output signals
			running 				: out std_logic;
			srl32_address		: out std_logic_vector (4 downto 0);
			sel0 					: out std_logic; -- selects lkey input or sigma output
			sigma_op 			: out std_logic_vector (1 downto 0);
			--
			sel3 					: out std_logic; -- selects key output or zeroes (round key computation mux)
			--
			srl16_address 		: out std_logic_vector (3 downto 0);
			srl16_en 			: out std_logic;
			srl16_delay_en 	: out std_logic;
			sel1 					: out std_logic; -- selects
			sel2 					: out std_logic; -- inverts (logic not) srl_output register
			--
			round_key_waddr	: out std_logic_vector (8 downto 0);
			round_key_wen 		: out std_logic_vector (0 downto 0);
			constant_addr 		: out std_logic_vector (8 downto 0);
			--
			key_ready			: out std_logic;
			done 					: out std_logic
		);
	end component;

	component keyexp_datapath is
	   port (
	    	clock 			: in std_logic;
			reset 			: in std_logic;
			key_in 			: in std_logic_vector (31 downto 0);
			lkey 				: in std_logic_vector (31 downto 0);
			srl16_address 	: in std_logic_vector (3 downto 0);
			srl32_address 	: in std_logic_vector (4 downto 0);
			srl16_en 		: in std_logic;
			srl16_delay_en : in std_logic;
			wea 				: in std_logic_vector (0 downto 0);
			sel0 				: in std_logic; -- sel SRL32 source
			sel1 				: in std_logic; -- sel SRL16 source
			sel2 				: in std_logic; -- sel inv key source
			sigma_op 		: in std_logic_vector (1 downto 0);
			sel3 				: in std_logic; -- sel stage 9 input key or zero
			constant_addr 	: in std_logic_vector (8 downto 0);
			round_key_addr : in std_logic_vector (8 downto 0);
			--
			round_key 		: out std_logic_vector (31 downto 0);
			key_out 			: out std_logic_vector (31 downto 0)
		);
	end component;

	-- Internal signals and connections
	signal srl32_address_i 	: std_logic_vector (4 downto 0);
	signal sel0_i 				: std_logic;
	signal sigma_op_i 		: std_logic_vector (1 downto 0);
	signal sel3_i				: std_logic;
	signal srl16_address_i 	: std_logic_vector (3 downto 0);
	signal srl16_en_i 		: std_logic;
	signal srl16_delay_en_i	: std_logic;
	signal sel1_i 				: std_logic;
	signal sel2_i 				: std_logic;

	signal round_key_waddr_i: std_logic_vector (8 downto 0);
	signal round_key_wen_i 	: std_logic_vector (0 downto 0);
	signal constant_addr_i 	: std_logic_vector (8 downto 0);

begin

	keyexp_state_machine_u0 : keyexp_state_machine
	port map (
		clock 				=> clock,
		reset 				=> reset,
		enc_dec				=> enc_dec,
		expand_key			=> expand_key,
		key_size_192 		=> key_size_192,
		key_size_256 		=> key_size_256,
		start 				=> start,
		done_clefia 		=> done_clefia,
		round_key_raddr	=> round_key_addr,
		-- output signals
		running 				=> running,
		srl32_address		=> srl32_address_i,
		sel0 					=> sel0_i,
		sigma_op 			=> sigma_op_i,
		--
		sel3 					=> sel3_i,
		--
		srl16_address 		=> srl16_address_i,
		srl16_en 			=> srl16_en_i,
		srl16_delay_en 		=> srl16_delay_en_i,
		sel1 					=> sel1_i,
		sel2 					=> sel2_i,
		--
		round_key_waddr	=> round_key_waddr_i,
		round_key_wen 		=> round_key_wen_i,
		constant_addr 		=> constant_addr_i,
		--
		key_ready			=> key_ready,
		done 					=> done
	);

	keyexp_datapath_u0 : keyexp_datapath
   port map (
    	clock 			=> clock,
		reset 			=> reset,
		key_in 			=> key_in,
		lkey 				=> lkey,
		srl16_address 	=> srl16_address_i,
		srl32_address 	=> srl32_address_i,
		srl16_en 		=> srl16_en_i,
		srl16_delay_en => srl16_delay_en_i,
		wea 				=> round_key_wen_i,
		sel0 				=> sel0_i,
		sel1 				=> sel1_i,
		sel2 				=> sel2_i,
		sigma_op 		=> sigma_op_i,
		sel3 				=> sel3_i,
		constant_addr 	=> constant_addr_i,
		round_key_addr => round_key_waddr_i,
		--
		round_key 		=> round_key,
		key_out 			=> key
	);

end behavioral;