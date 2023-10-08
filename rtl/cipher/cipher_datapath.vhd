-------------------------------------------------------------------------------------
-- Company: Instituto Superior Tecnico de Lisboa
-- Engineer: Joao Carlos Nunes Bittencourt
--
-- Design Name:    CLEFIA implementation of the cipher core with hybrid support
--                 for both GFN_{4,n} and GFN_{8,n}
-- Module Name:    cipher_datapath
-- Project Name:   CLEFIA 256
-- Description:
-- 		CLEFIA Feistel Dual-Network GFN_4/8,n circuit datapath
--
-- Revision:
-- Revision 1.0 -  Structural datapath
-- Revision 2.0 -  Add suport for GFN8 network
-- Revision 3.0 -  Fix minnor bugs for deploy
--
------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_unsigned.all;

entity cipher_datapath is
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
		data_out 		: out  std_logic_vector (31 downto 0)
	);
end cipher_datapath;

architecture behavioral of cipher_datapath is
	-- SRL16
	component SRL_32b_16deep
	port (
		input 		: in std_logic_vector (31 downto 0);
		address 		: in std_logic_vector (3 downto 0);
		clock 		: in std_logic;
		cen 			: in std_logic;
		cen_out 		: in std_logic;
		reset_out	: in std_logic;
		---
		output 		: out std_logic_vector (31 downto 0)
	);
	end component;

	-- TBOX 0/1 BRAM
	component TBOX_BRAM
	port (
	   addr1a 		: in std_logic_vector(8 downto 0);
	   addr1b 		: in std_logic_vector(8 downto 0);
	   addr2a 		: in std_logic_vector(8 downto 0);
	   addr2b 		: in std_logic_vector(8 downto 0);

	   reset_out 	: in std_logic;
	   clock 		: in std_logic;

	   mults1a_00 	: out std_logic_vector(31 downto 0);
	   mults1b_22 	: out std_logic_vector(31 downto 0);
	   mults2a_11 	: out std_logic_vector(31 downto 0);
	   mults2b_33 	: out std_logic_vector(31 downto 0)
	);
	end component;

	-- D Flip-flop
	component data_registry
	port(
		data_in 	: in std_logic_vector (31 downto 0);
		clk 		: in std_logic;
		enable 		: in std_logic;
		reset 		: in std_logic;
		data_out 	: out std_logic_vector (31 downto 0) );
	end component;
   -- End components

   -- Signal declaration
	-- Internal passthrough signals
	signal i0, i1, i2 						: std_logic_vector (31 downto 0);
	signal u0, u1, u2, u3 					: std_logic_vector (31 downto 0);
	signal x0	 							: std_logic_vector (31 downto 0);
	-- Registers output
	signal r0, r1							: std_logic_vector (31 downto 0);
	-- BRAM input address
	signal addr0, addr1, addr2, addr3 		: std_logic_vector (8 downto 0);
	-- Output of tbox final registry
	signal rt0, rt1, rt2, rt3 				: std_logic_vector (31 downto 0);
	signal srl_output 						: std_logic_vector (31 downto 0);

-- Begin architecture (datapath)
begin
	-- Stage 2 (32xLUT6)
	u1	<= data_in when sel1 = '1' else -- used also as key input in L key generation process
			srl_output;

	u2	<= r1 when sel2 = '1' else -- selects r1 when working on gfn8 and u0 otherwise
			u0;

	i0 	<= u1 xor u2; -- xorring between the whitening key or the swaped word
	-- End of Stage 2

	-- Stage 3 - CLEFIA Swap Module (32xSRL16)
	shift_register_bank : SRL_32b_16deep
	port map (
		input 		=> i0,
		address 		=> srl_address,
		clock 		=> clock,
		cen 			=> '1',
		cen_out 		=> '1',
		reset_out 	=> reset_srl,
		output 		=> srl_output
	);
	-- End of Stage 3

	-- Stage 4 (32xLUT4)
	-- reduce critical path --
	i1 	<= r1 xor srl_output when sel2 = '1' else
		   	u0 xor srl_output;
	--

	u3 	<= srl_output when sel3 = '0' else
		   	i1;
		   --u0 xor srl_output;--i0;


	i2	<= u3 xor round_key;
	-- End of Stage 4

	-- Address switch from T0/T1
	--
	addr0 <= t0_t1 & i2 (31 downto 24);
	addr1 <= t0_t1 & i2 (23 downto 16);
	addr2 <= t0_t1 & i2 (15 downto 8);
	addr3 <= t0_t1 & i2 (7 downto 0);

	-----------------------------------------------------
	-- TBOX BRAM implementation
	-----------------------------------------------------
	TBOX_BRAM_u0 : TBOX_BRAM
	port map (
	   addr1a => addr0,
	   addr1b => addr2,
	   addr2a => addr1,
	   addr2b => addr3,

	   reset_out => reset,
	   clock => clock,

	   mults1a_00 => rt0,
	   mults1b_22 => rt2,
	   mults2a_11 => rt1,
	   mults2b_33 => rt3
	);

	--- Input/Forwarding Stage 1 (32 LUT6)
	--- Reorganizing XOR operations
	x0 (31 downto 24) <= (rt0 (31 downto 24) xor rt2 (15 downto 8)) xor
						 (rt1 (31 downto 24) xor rt3 (15 downto 8));
	x0 (23 downto 16) <= (rt0 (23 downto 16) xor rt2 (7  downto 0)) xor
						 (rt1 (23 downto 16) xor rt3 (7  downto 0));
	x0 (15 downto 8)  <= (rt0 (15 downto  8) xor rt2 (31 downto 24)) xor
						 (rt1 (15 downto  8) xor rt3 (31 downto 24));
	x0 (7 downto 0)   <= (rt0 (7  downto  0) xor rt2 (23 downto 16)) xor
						 (rt1 (7  downto  0) xor rt3 (23 downto 16));

	--- Input multiplex
	---
	u0	<= x0 xor whitening_key when sel0 = '1' else
		   whitening_key;--data_in;
	-- End of Stage 1

	-- GFN8 delay slots
	data_registry_0 : data_registry
	port map (
		data_in 	=> u0,
		clk 		=> clock,
		enable 		=> '1',
		data_out 	=> r0,
		reset 		=> reset
	);

	data_registry_1 : data_registry
	port map (
		data_in 	=> r0,
		clk 		=> clock,
		enable 		=> '1',
		data_out 	=> r1,
		reset 		=> reset
	);

	-- Output Stage
	data_out <= srl_output;

end behavioral;
