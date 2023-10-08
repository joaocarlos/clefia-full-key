-------------------------------------------------------------------------------------
-- Company: Instituto Superior Tecnico de Lisboa
-- Engineer: Joao Carlos Nunes Bittencourt
--
-- Design Name:    CLEFIA implementation of the cipher core with hybrid support
--                 for both GFN_{4,n} and GFN_{8,n}
-- Module Name:    keyexp_datapath
-- Project Name:   CLEFIA 256
-- Description:
-- 		CLEFIA Key Expansion module data path
--
-- Revision:
-- Revision 1.0 -  Structural datapath
-- Revision 2.0 -  Fix minnor bugs for deploy
--
------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity keyexp_datapath is
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
end keyexp_datapath;

architecture behavioral of keyexp_datapath is
	-- Instantiate components
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

	-- SRL32
	component SRL_32b_32deep
   	port (
			input 		: in std_logic_vector (31 downto 0);
			address 		: in std_logic_vector (4 downto 0);
			clock 		: in std_logic;
			cen 			: in std_logic;
			cen_out 		: in std_logic;
			reset_out	: in std_logic;
			---
			output 		: out std_logic_vector (31 downto 0)
		);
	end component;

	-- Round Keys, Constant Keys and Constants BRAM
	component keyexp_mem
		port (
		   clka 	: in std_logic;
		   wea 		: in std_logic_vector (0 downto 0);
		   addra 	: in std_logic_vector (8 downto 0);
		   dina 	: in std_logic_vector (31 downto 0);
		   douta 	: out std_logic_vector (31 downto 0);
		   clkb 	: in std_logic;
		   web 		: in std_logic_vector (0 downto 0);
		   addrb	: in std_logic_vector (8 downto 0);
		   dinb 	: in std_logic_vector (31 downto 0);
		   doutb 	: out std_logic_vector (31 downto 0)
	  );
	end component;

	component KEY_MEM_BRAM
		port (
		   reset   : in std_logic;
		   clka    : in std_logic;
		   wea     : in std_logic_vector (0 downto 0);
		   addra   : in std_logic_vector (8 downto 0);
		   dina    : in std_logic_vector (31 downto 0);
		   douta   : out std_logic_vector (31 downto 0);
		   clkb    : in std_logic;
		   addrb   : in std_logic_vector (8 downto 0);
		   doutb   : out std_logic_vector (31 downto 0)
		);
	end component;

	-- D-Flipflops
	component data_registry
		port (
			data_in 	: in std_logic_vector (31 downto 0);
			clk 		: in std_logic;
			enable 	: in std_logic;
			reset 	: in std_logic;
			data_out : out std_logic_vector (31 downto 0)
		);
	end component;
	-- End components

	-- Begin signals

	signal srl16_input 		: std_logic_vector (31 downto 0);
	signal srl16_output		: std_logic_vector (31 downto 0);
	signal srl16_delay		: std_logic_vector (31 downto 0);
	signal key_inv 			: std_logic_vector (31 downto 0);
	signal key_i 				: std_logic_vector (31 downto 0);
	signal srl32_input 		: std_logic_vector (31 downto 0);
	signal srl32_output		: std_logic_vector (31 downto 0);
	signal sigma_out 			: std_logic_vector (31 downto 0);
	signal sigma_delay		: std_logic_vector (31 downto 0);
	--
	signal round_key_i		: std_logic_vector (31 downto 0);
	signal constant_ij		: std_logic_vector (31 downto 0);
	-- End signals

begin

	-- Begin Stage 7
	key_inv 	<= 	srl16_output when sel2 = '0' else
				   	not srl16_output;

	srl16_input 	<= key_in 	when sel1 = '1' else
				  			srl16_delay xor key_inv;

	key_srl_bank : SRL_32b_16deep
	port map (
		input 	=> srl16_input,
		address 	=> srl16_address,
		clock 	=> clock,
		cen 		=> srl16_en,
		cen_out 	=> '1',
		reset_out=> reset,
		output 	=> srl16_output
	);

	data_registry_0 : data_registry
	port map (
		data_in 	=> srl16_output,
		clk 		=> clock,
		enable 	=> srl16_delay_en,
		data_out => srl16_delay,
		reset 	=> reset
	);

	key_out 	<= srl16_output;

	-- Begin stage 8
	srl32_input <= lkey when sel0 = '1' else
				   	sigma_out;

	lkey_srl_bank : SRL_32b_32deep
	port map (
		input 	=> srl32_input,
		address 	=> srl32_address,
		clock 	=> clock,
		cen 		=> '1',
		cen_out 	=> '1',
		reset_out=> reset,
		output 	=> srl32_output
	);

	data_registry_1 : data_registry
	port map (
		data_in 	=> srl32_output,
		clk 		=> clock,
		enable 	=> '1',
		data_out => sigma_delay,
		reset 	=> reset
	);

	--	+ The scheduling is as follow:
	--    - Y0 = L[120:92]  | L[91:85]
	--	  - Y2 = L[127:121] | L[63:39]
	--	  - Y3 = L[38:32]   | L[31:7]
	--	  - Y1 = L[6:0]     | L[84:64]
	------------------------------------
	-- #         Permutation
	------------------------------------
	-- 1 	Y = L2(6:0)   & L3(31:7)
	-- 2 	Y = L1(24:0)  & L3(6:0)
	-- 3 	Y = L0(24:0)  & L1(31:25)
	-- 4 	Y = L0(31:25) & L2(31:7)
	------------------------------------
	sigma : process (srl32_output, sigma_op, sigma_delay)
	begin
		case(sigma_op) is
			when "00" =>
				sigma_out <= sigma_delay(6 downto 0) & srl32_output(31 downto 7);
			when "01" =>
				sigma_out <= srl32_output(24 downto 0) & sigma_delay(6 downto 0);
			when "11" =>
				sigma_out <= srl32_output(24 downto 0) & sigma_delay(31 downto 25);
			when "10" =>
				sigma_out <= sigma_delay(31 downto 25) & srl32_output(31 downto 7);
			when others =>
				sigma_out <= (others => '0');
		end case;
	end process;

	-- Begin stage 9
	key_i 	<= srl16_output when sel3 = '0' else
			   (others => '0');

	round_key_i <= key_i xor constant_ij xor  sigma_delay;

	key_memory : KEY_MEM_BRAM
		port map (
			---------------------------
			-- Reset output
			reset => reset,
			---------------------------
			clka 	=> clock,
			wea 	=> wea,
			addra => round_key_addr,
			dina 	=> round_key_i,
			douta => round_key,
			---------------------------
			-- Constants are stored in port b
			clkb 	=> clock,
			addrb => constant_addr,
			doutb => constant_ij
			);

end behavioral;