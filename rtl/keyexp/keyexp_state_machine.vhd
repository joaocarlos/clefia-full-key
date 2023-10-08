-------------------------------------------------------------------------------------
-- Company: Instituto Superior Tecnico de Lisboa
-- Engineer: Joao Carlos Nunes Bittencourt
--
-- Design Name:    CLEFIA implementation of the cipher core with hybrid support
--                 for both GFN_{4,n} and GFN_{8,n}
-- Module Name:    keyexp_state_machine
-- Project Name:   CLEFIA 256
-- Description:
-- 		CLEFIA Key Expansion module data path
--
-- Revision:
-- Revision 1.0 -  Initial release without integration
-- Revision 2.0 -  Fix minnor bugs for deploy
--
------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity keyexp_state_machine is
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
end keyexp_state_machine;

architecture behavioral of keyexp_state_machine  is

	-- states
	type state_type is (
		st_idle, st_init, st_key_feed, st_inv_key, st_wkey_gen, st_gfn_feed, st_lkey_idle,
		st_lkey_feed, st_loop0_sigma, st_loop1_sigma, st_lr_loop_init, st_done, st_cipher_idle, st_cipher );

	signal state, next_state : state_type;

	signal running_i 			: std_logic;
	signal srl32_address_i	: std_logic_vector (4 downto 0);
	signal sel0_i 				: std_logic; -- selects lkey input or sigma output
	signal sigma_op_i			: std_logic_vector (1 downto 0);
	--
	signal sel3_i 				: std_logic; -- selects key output or zeroes (round key computation mux)
	--
	signal srl16_address_i	: std_logic_vector (3 downto 0);
	signal srl16_en_i			: std_logic;
	signal srl16_delay_en_i : std_logic;
	signal sel1_i				: std_logic; -- selects
	signal sel2_i 				: std_logic; -- inverts (logic not) srl_output register
	--
	signal round_key_wen_i 	: std_logic_vector (0 downto 0);
	signal constant_addr_i 	: std_logic_vector (8 downto 0);
	signal constant_init 	: std_logic_vector (1 downto 0);
	signal constant_en 		: std_logic;
	--
	signal done_i				: std_logic;
	signal key_ready_i 		: std_logic;

	-- internal counters
	signal round_counter 	: std_logic_vector (5 downto 0);
	signal round_counter_en	: std_logic;
	signal reset_round 		: std_logic;
	signal round_number 		: std_logic_vector (5 downto 0); -- n rounds default
	signal cycle_counter 	: std_logic_vector (3 downto 0);
	signal cycle_en 			: std_logic;
	signal reset_cycle 		: std_logic;

	-- Internal control
	signal gfn_8_4_net 		: std_logic;
	signal left_right			: std_logic;
	signal left_right_i		: std_logic;

begin

	-- Cycle counter
	cycle_counter_proc : process(clock)
	begin
		if (clock'event and clock = '1') then
			if (reset_cycle = '1' or reset = '1') then
				cycle_counter <= (others=>'0');
			elsif (cycle_en = '1') then
				cycle_counter <= cycle_counter + 1;
			end if;
		end if;
	end process;

	-- Round counter
	round_counter_proc : process(clock)
	begin
		if (clock'event and clock = '1') then
			if (reset_round = '1') then
				round_counter <= (others=>'0');
			elsif (round_counter_en = '1') then
				round_counter <= round_counter + 1;
			end if;
		end if;
	end process;

	constant_init <= 	"01" when key_size_192 = '0' and key_size_256 = '0' else
					 		"10" when key_size_192 = '1' and key_size_256 = '0' else
					 		"11";

	constant_addr_proc : process(clock)
	begin
		if (clock'event and clock = '1') then
			if (reset = '1') then -- need to fix so there is no need to reset (low priority)
				constant_addr_i <= constant_init & "0000000";
			elsif (constant_en = '1') then
				constant_addr_i <= constant_addr_i + 1;
			end if;
		end if;
	end process;

	constant_addr <= constant_addr_i;

	round_key_waddr <= 	"000" & round_key_raddr when state = st_cipher else
								"000" & round_counter 	when running_i = '1' else -- run round key generation
					 			"001" & round_key_raddr when key_size_192 = '0' and key_size_256 = '0' else
								"011" & round_key_raddr when key_size_192 = '1' and key_size_256 = '0' else
					 			"101" & round_key_raddr;

	round_number 	<= 	"101011" when key_size_192 = '1' and key_size_256 = '0' else
								"110011" when key_size_192 = '0' and key_size_256 = '1' else
								"100011";

	-- State register
	state_reg_proc : process (clock)
	begin
		if (clock'event and clock = '1') then
			if (reset = '1') then
				state <= st_idle;
			else
				state <= next_state;
			end if;
		end if;
	end process;

	sync_proc : process (clock)
	begin
		if (clock'event and clock = '1') then
			if (reset = '1') then
				-- assign default outputs
				running 			<= '0';
				srl32_address	<= (others => '0');
				sel0 				<= '0';
				sigma_op 		<= (others => '0');
				sel3 				<= '0';
				srl16_address	<= (others => '0');
				srl16_en 		<= '0';
				srl16_delay_en <= '0';
				sel1 				<= '0';
				sel2 				<= '0';
				round_key_wen 	<= (others => '0');
				done 				<= '0';
				key_ready 		<= '0';
				-- internal register
				gfn_8_4_net 	<= '0';
				left_right 		<= '1';
			else
				-- assign output registers
				running 			<= running_i;
				srl32_address	<= srl32_address_i;
				sel0 				<= sel0_i;
				sigma_op 		<= sigma_op_i;
				sel3 				<= sel3_i;
				srl16_address	<= srl16_address_i;
				srl16_en 		<= srl16_en_i;
				srl16_delay_en <= srl16_delay_en_i;
				sel1 				<= sel1_i;
				sel2 				<= sel2_i;
				round_key_wen 	<= round_key_wen_i;
				done 				<= done_i;
				key_ready 		<= key_ready_i;
				-- internal register
				gfn_8_4_net 	<= (key_size_192 or key_size_256) and expand_key;
				left_right 		<= left_right_i;
			end if;
		end if;
	end process;

	output_decode: process (state, gfn_8_4_net, round_number, cycle_counter, left_right, round_counter, constant_addr_i, key_size_192, key_size_256, start, enc_dec)
	begin
		running_i 			<= '1';
		srl32_address_i	<= (others => '0');
		sel0_i 				<= '0';
		sigma_op_i 			<= (others => '0');
		sel3_i 				<= '0';
		srl16_address_i	<= (others => '1');
		srl16_en_i 			<= '0';
		srl16_delay_en_i	<= '0';
		sel1_i 				<= '0';
		sel2_i 				<= '0';
		round_key_wen_i	<= (others => '0');
		done_i 				<= '0';
		key_ready_i 		<= '0';
		--
		reset_cycle 		<= '0';
		reset_round 		<= '0';
		cycle_en 			<= '0';
		constant_en 		<= '0';
		left_right_i 		<= left_right;
		round_counter_en	<= '0';
		case(state) is
			when st_idle =>
				running_i 	<= '0';
				reset_round <= '1';
				reset_cycle <= '1';
			when st_init =>
				sel1_i 		<= '1';
				srl16_en_i 	<= '1';
			when st_key_feed =>
			 	sel1_i 		<= '1';
			 	srl16_en_i 	<= '1';
			 	cycle_en 	<= '1';
		 		srl16_address_i <= cycle_counter;
				case(key_size_256 & key_size_192 & cycle_counter(2 downto 0)) is
					when "00" & "011" | "10" & "110" | "01" & "100" =>
						reset_cycle		<= '1';
						srl16_en_i 		<= gfn_8_4_net;
					when others =>
						reset_cycle		<= '0';
				end case;
			when st_inv_key =>
			 	cycle_en 	<= '1';
			 	case(cycle_counter(0)) is
			 		when '0' =>
			 			srl16_en_i 		<= '1';
			 			sel2_i 			<= '1';
			 			srl16_address_i <= "0100";
			 		when '1' =>
			 			srl16_en_i 		<= '1';
			 			sel2_i 			<= '1';
			 			srl16_address_i <= "0110";
			 			reset_cycle 	<= '1';
			 		when others =>
			 			srl16_address_i <= "1111";
			 	end case;
			 when st_wkey_gen =>
			 	cycle_en 			<= '1';
			 	srl16_delay_en_i	<= '1';
			 	reset_cycle 		<= cycle_counter(3);
			 	case (cycle_counter(0)) is
			 		when '0' =>
			 			srl16_en_i 		<= cycle_counter(0); --not srl16_en_i;
			 			if(cycle_counter(3) = '0') then
			 				srl16_address_i <= "0011";
			 			else
			 				srl16_address_i <= "1011";
			 			end if;
			 		when '1' =>
						srl16_en_i 		<= cycle_counter(0); --not srl16_en_i;
			 			srl16_address_i <= "0110";
			 		when others =>
			 			srl16_address_i <= "1111";
			 	end case;
			when st_gfn_feed =>
				cycle_en 	<= '1';
				case(cycle_counter) is
					when "0000" =>
						key_ready_i 		<= gfn_8_4_net;
						srl16_address_i 	<= "1011";
					when "0001" =>
						if(gfn_8_4_net = '1') then
							srl16_address_i <= "1010";
						else
							srl16_address_i <= "0011";
							key_ready_i 	 <= '1';
						end if;
					when "0010" =>
						if(gfn_8_4_net = '1') then
							srl16_address_i <= "1001";
						else
							running_i <= '0';
							srl16_address_i <= "0010";
						end if;
					when "0011" =>
						if(gfn_8_4_net = '1') then
							srl16_address_i <= "1000";
						else
							running_i <= '0';
							srl16_address_i <= "0001";
						end if;
					when "0100" =>
						if(gfn_8_4_net = '1') then
							srl16_address_i <= "0111";
						else
							running_i <= '0';
							srl16_address_i <= "0000";
						end if;
					when "0101" =>
						srl16_address_i <= "0110";
					when "0110" =>
						running_i 	<= '0';
						srl16_address_i <= "0101";
					when "0111" =>
						running_i 		 <= '0';
						srl16_address_i <= "0100";
					when others =>
						running_i 		 <= '0';
						srl16_address_i <= "1111";
				end case;
			when st_lkey_idle =>
				running_i 	<= '0';
				reset_cycle <= '1';
			when st_lkey_feed =>
				cycle_en 	<= '1';
				sel0_i 		<= (not cycle_counter(3) and gfn_8_4_net) or (not cycle_counter(2) and not gfn_8_4_net);
				constant_en <= '1';
				sel3_i 		<= '1';
				case(cycle_counter) is
					when "0000" =>
						constant_en <= '0';
					when "0010" =>
						round_key_wen_i <= "1";
					when "0011" | "0100" =>
						round_counter_en<= '1';
						round_key_wen_i <= "1";
					when "0101"  =>
						round_counter_en<= '1';
						round_key_wen_i <= "1";
						constant_en 	<= '0';
						if(gfn_8_4_net = '0') then
							sigma_op_i <= "01";
							srl32_address_i <= "00011";
						end if;
					when "0110" =>
						round_counter_en<= '1';
						constant_en 	<= '0';
						if(gfn_8_4_net = '0') then
							sigma_op_i <= "11";
							srl32_address_i <= "00101";
						end if;
					when "0111" =>
						constant_en 	<= '0';
						srl32_address_i <= "00100";
						if(gfn_8_4_net = '0') then
							sigma_op_i <= "10";
						end if;
					when "1000" =>
						constant_en 	<= '0';
						srl32_address_i <= "00100";
						if(gfn_8_4_net = '0') then
							srl32_address_i <= "00001";
							srl16_address_i <= "0011";
							constant_en 	<= '1';
							reset_cycle 	<= '1';
						end if;
					when "1001" =>
						constant_en 	<= '0';
						sigma_op_i 		<= "01";
						srl32_address_i <= "00111";
					when "1010" =>
						constant_en 	<= '0';
						sigma_op_i 		<= "11";
						srl32_address_i <= "01001";
					when "1011" =>
						constant_en 	<= '0';
						sigma_op_i 		<= "10";
						srl32_address_i <= "01000";
					when "1100" =>
						reset_cycle 	<= '1';
						srl32_address_i <= "00001";
						constant_en 	<= '1';
						sel3_i 			<= '0';
						srl16_address_i <= "0111";
					when others =>
						null;
				end case;
			when st_loop0_sigma =>
				cycle_en 	<= '1';
				sel3_i 		<= not gfn_8_4_net and not round_counter(2);
				case (cycle_counter) is
					when "0000" =>
						round_key_wen_i	<= "1";
						constant_en 		<= '1';
						srl32_address_i 	<= "00011";
						if(gfn_8_4_net = '0') then
							srl16_address_i <= "0010";
						elsif(left_right = '1') then
							srl16_address_i <= "0110";
						else
							srl16_address_i <= "1010";
						end if;
					when "0001" =>
						round_key_wen_i	<= "1";
						round_counter_en	<= '1';
						constant_en 		<= '1';
						srl32_address_i 	<= "00010";
						if(gfn_8_4_net = '0') then
							srl16_address_i <= "0001";
						elsif(left_right = '1') then
							srl16_address_i <= "0101";
						else
							srl16_address_i <= "1001";
						end if;
					when "0010" =>
						round_key_wen_i	<= "1";
						round_counter_en	<= '1';
						constant_en 		<= '1';
						srl32_address_i 	<= "00110";
						left_right_i 		<= not left_right;
						if(gfn_8_4_net = '0') then
							srl16_address_i <= "0000";
						elsif(left_right = '1') then
							srl16_address_i <= "0100";
						else
							srl16_address_i <= "1000";
						end if;
					-- Sigma
					when "0011" =>
						round_key_wen_i	<= "1";
						round_counter_en	<= '1';
						srl32_address_i 	<= "00110";
						sigma_op_i 			<= "01";
					when "0100" =>
						round_counter_en	<= '1';
						srl32_address_i 	<= "00110";
						sigma_op_i 			<= "11";
					when "0101" =>
						srl32_address_i 	<= "00110";
						sigma_op_i 			<= "10";
					when "0110" =>
						reset_cycle 		<= '1';
						if(gfn_8_4_net & constant_addr_i(5 downto 3) = "1" & "001") then --constant_addr_i(3 downto 0) = "1" & "1000") then
							srl32_address_i <= "01110";
						elsif(gfn_8_4_net = '1') then
							srl32_address_i <= "01111";
						else
							srl32_address_i <= "00001";
							srl16_address_i <= "0011";
						end if;
						constant_en 	<= '1';
					when others =>
						reset_cycle 	<= '1';
				end case;
			when st_lr_loop_init =>
				cycle_en 		<= '1';
				case(cycle_counter) is
					when "0000" =>
						round_key_wen_i 	<= "1";
						constant_en 		<= '1';
						srl32_address_i 	<= "01110";
					when "0001" =>
						round_key_wen_i 	<= "1";
						round_counter_en	<= '1';
						constant_en 		<= '1';
						srl32_address_i 	<= "01110";
					when "0010" =>
						round_key_wen_i 	<= "1";
						round_counter_en	<= '1';
						constant_en 		<= '1';
						srl32_address_i 	<= "01110";
					-- Sigma
					when "0011" =>
						constant_en 		<= '0';
						round_key_wen_i	<= "1";
						round_counter_en	<= '1';
						sigma_op_i 			<= "01";
						srl32_address_i 	<= "10001";
					when "0100" =>
						constant_en 		<= '0';
						round_key_wen_i	<= "0";
						round_counter_en	<= '1';
						sigma_op_i 			<= "11";
						srl32_address_i 	<= "10011";
					when "0101" =>
						constant_en 		<= '0';
						round_key_wen_i	<= "0";
						sigma_op_i 			<= "10";
						srl32_address_i 	<= "10010";
					when "0110" =>
						constant_en 		<= '1';
						round_key_wen_i	<= "0";
						sigma_op_i 			<= "11";
						srl16_address_i 	<= "1011";
						srl32_address_i 	<= "00001";
						reset_cycle 		<= '1';
					when others =>
						round_key_wen_i 	<= "1";
						constant_en 		<= '1';
						srl32_address_i 	<= "01110";
				end case;
			when st_loop1_sigma =>
				cycle_en 	<= '1';
				sel3_i 		<= '1';
				case (cycle_counter) is
					when "0000" =>
						round_key_wen_i	<= "1";
						constant_en 		<= '1';
						srl32_address_i 	<= "10001";
					when "0001" =>
						round_key_wen_i	<= "1";
						round_counter_en	<= '1';
						constant_en 		<= '1';
						srl32_address_i 	<= "10000";
					when "0010" =>
						round_key_wen_i	<= "1";
						round_counter_en	<= '1';
						constant_en 		<= '1';
						srl32_address_i 	<= "10100";
					-- Sigma
					when "0011" =>
						round_key_wen_i	<= "1";
						round_counter_en	<= '1';
						srl32_address_i 	<= "10100";
						sigma_op_i 			<= "01";
					when "0100" =>
						round_counter_en	<= '1';
						srl32_address_i 	<= "10100";
						sigma_op_i 			<= "11";
					when "0101" =>
						srl32_address_i 	<= "10100";
						sigma_op_i 			<= "10";
					when "0110" =>
						reset_cycle 		<= '1';
						srl32_address_i 	<= "00001";
						constant_en 		<= '1';
						if(left_right = '1') then
							srl16_address_i <= "0111";
						else
							srl16_address_i <= "1011";
						end if;
					when others =>
						reset_cycle 	<= '1';
				end case;
			when st_done =>
				done_i 		<= '1';
				reset_round <= '1';
			when st_cipher_idle =>
				running_i 	<= '0';
				reset_round <= '1';
				if(start = '1') then
					if(enc_dec = '0') then
							srl16_address_i <= "0011"; -- WK0
						else
							srl16_address_i <= "0001"; -- WK2
					end if;
				else
					srl16_address_i <= (others => '1');
				end if;
			when st_cipher =>
				running_i 			<= '0';
				round_counter_en	<= '1';
				key_ready_i 	  	<= '1';
				--
				case (key_size_192 & key_size_256 & round_counter) is
					when "00" & "000001" | "01" & "000001" | "10" & "000001" =>
						if(enc_dec = '0') then
							srl16_address_i <= "0010"; -- WK1
						else
							srl16_address_i <= "0000"; -- WK3
						end if;
					when "00" & "100101" | "10" & "101101" | "01" & "110101" =>
						if(enc_dec = '0') then
							srl16_address_i <= "0001"; -- WK2
						else
							srl16_address_i <= "0010"; -- WK1
						end if;
					when "00" & "100110" | "10" & "101110" | "01" & "110110" =>
						if(enc_dec = '0') then
							srl16_address_i <= "0000"; -- WK3
						else
							srl16_address_i <= "0011"; -- WK0
						end if;
					when others =>
						srl16_address_i <= (others => '1');
				end case;
			when others =>
				running_i <= '0';
				reset_round <= '1';
		end case;
	end process;

	next_state_decode: process (state, enc_dec, start, round_counter, round_number, gfn_8_4_net, cycle_counter, key_size_192, key_size_256, constant_addr_i, expand_key, done_clefia)
	begin
		--default state for next_state to avoid latches
		next_state <= state;
		--decode next state
		case (state) is
			when st_idle =>
				if (start = '1' and expand_key = '1') then
					next_state <= st_init;
				end if;
			when st_init =>
				next_state <= st_key_feed;
			when st_key_feed =>
				case(key_size_256 & key_size_192 & cycle_counter(2 downto 0)) is
					when "00" & "011" =>
						next_state <= st_gfn_feed;
					when "10" & "110" =>
						next_state <= st_wkey_gen;
					when "01" & "100" =>
						next_state <= st_inv_key;
					when others =>
						next_state <= state;
				end case;
			when st_inv_key =>
				if (cycle_counter(0) = '1') then
					next_state <= st_wkey_gen;
				end if;
			when st_wkey_gen =>
				if(cycle_counter(3) = '1') then
					next_state <= st_gfn_feed;
				end if;
			when st_gfn_feed =>
				if((cycle_counter(3 downto 2) = gfn_8_4_net & not gfn_8_4_net) and (cycle_counter(0) = gfn_8_4_net)) then
					next_state <= st_lkey_idle;
				end if;
			--
			when st_lkey_idle =>
				if(done_clefia = '1') then
					next_state <= st_lkey_feed;
				end if;
			when st_lkey_feed =>
				if(cycle_counter = '1' & gfn_8_4_net & "00") then
					next_state <= st_loop0_sigma;
				end if;
			when st_loop0_sigma =>
				if(cycle_counter = "0110") then
					if(round_counter = "01000" and gfn_8_4_net = '1') then
						next_state <= st_lr_loop_init;
					elsif(gfn_8_4_net = '1') then
						next_state <= st_loop1_sigma;
					end if;
				elsif(cycle_counter = "0100") then
					if(round_counter = round_number) then
						next_state <= st_done;
					end if;
				end if;
			when st_lr_loop_init =>
				if(cycle_counter = "0110") then
					next_state <= st_loop0_sigma;
				end if;
			when st_loop1_sigma =>
				if(cycle_counter = "0110") then
					next_state <= st_loop0_sigma;
				end if;
				if(round_counter = round_number) then
					next_state <= st_done;
				end if;
			when st_done =>
				next_state <= st_cipher_idle;
			when st_cipher_idle =>
				if(start = '1') then
					next_state <= st_cipher;
				end if;
			when st_cipher =>
				if(start = '1' and expand_key = '1') then
					next_state <= st_init;
				elsif (done_clefia = '1') then
					next_state <= st_cipher_idle;
				else
					next_state <= st_cipher;
				end if;
			when others =>
				next_state <= st_idle;
		end case;
	end process;

end behavioral;