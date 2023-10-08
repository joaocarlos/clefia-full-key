-------------------------------------------------------------------------------------
-- Company: Instituto Superior Tecnico de Lisboa
-- Engineer: Joao Carlos Nunes Bittencourt
--
-- Design Name:    CLEFIA implementation of the cipher core with hybrid support
--                 for both GFN_{4,n} and GFN_{8,n}
-- Module Name:    cipher_state_machine
-- Project Name:   CLEFIA 256
-- Description:
-- 		CLEFIA Feistel Dual-Network GFN_4/8,n control unit
--
-- Revision:
-- Revision 1.0 -  Encoding control
-- Revision 2.0 -  Add suport for GFN8 network
-- Revision 3.0 -  Fix minnor bugs for deploy
--
------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;

entity cipher_state_machine is
   port (
		clock 				: in std_logic;
		reset 				: in std_logic;
		enc_dec 				: in std_logic;
		expand_key			: in std_logic;
		key_size_192 		: in std_logic;
		key_size_256 		: in std_logic;
		start 				: in std_logic;
		key_ready 			: in std_logic;
		-- output signals
		running 				: out std_logic;
		sel0 					: out std_logic;
		sel1 					: out std_logic;
		sel2 					: out std_logic;
		sel3 					: out std_logic;
		srl_addr 			: out std_logic_vector (3 downto 0);
		reset_srl 			: out std_logic;
		round_key_addr 	: out std_logic_vector (5 downto 0);
		t0_t1 				: out std_logic;
		done 					: out std_logic
	);
end cipher_state_machine;

architecture behavioral of cipher_state_machine is

	-- states
	type state_type is (
		-- CLEFIA states
		st0_idle, st1_init, st2_prep_block, st3_loop0, st4_loop1, st5_flush, st6_unswap);

	signal state, next_state : state_type;

	-- output register signals
	signal done_i 		: std_logic;
	signal sel0_i 		: std_logic;
	signal sel1_i 		: std_logic;
	signal sel2_i 		: std_logic;
	signal sel3_i 		: std_logic;
	signal t0_t1_i 	: std_logic;
	signal t0_t1_l 	: std_logic;
	signal running_i 	: std_logic;
	signal srl_addr_i : std_logic_vector (3 downto 0);
	signal reset_srl_i: std_logic;

	-- internal counters
	signal round_counter 		: std_logic_vector (5 downto 0);
	signal round_counter_set	: std_logic;
	signal round_counter_en		: std_logic;
	signal round_counter_dir	: std_logic_vector (1 downto 0);
	signal round_number 			: std_logic_vector (5 downto 0); --36 rounds default
	signal cycle_counter 		: std_logic_vector (3 downto 0);
	signal cycle_en 				: std_logic;
	signal reset_cycle 			: std_logic;

	-- GFN8/4
	signal gfn_8_4_net 			: std_logic;

	-- Key expansion round numbers
	constant round24	: bit_vector (5 downto 0) := "011000"; -- 128-bit key
	constant round40 	: bit_vector (5 downto 0) := "101100"; -- 192-256-bit key
	-- Ciphering round numbers
	constant round36	: bit_vector (5 downto 0) := "100100"; -- 36 rounds (128-bit key)
	constant round44	: bit_vector (5 downto 0) := "101100"; -- 44 rounds (192-bit key)
	constant round52	: bit_vector (5 downto 0) := "110100"; -- 52 rounds (256-bit key)
	-- Deciphering round numbers
	constant round34 	: bit_vector (5 downto 0) := "100010";
	constant round42 	: bit_vector (5 downto 0) := "101010";
	constant round50 	: bit_vector (5 downto 0) := "110010";
	constant round0 	: bit_vector (5 downto 0) := "111110";

begin
	round_number <=	to_stdlogicvector(round24) when expand_key = '1' and (key_size_192 = '0' and key_Size_256 = '0') else
							to_stdlogicvector(round40) when expand_key = '1' and (key_size_192 = '1' or  key_Size_256 = '1') else
							to_stdlogicvector(round44) when expand_key = '0' and key_size_192 = '1' else
							to_stdlogicvector(round52) when expand_key = '0' and key_Size_256 = '1' else
							to_stdlogicvector(round36) when enc_dec = '0' else
							"111110";

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
			if (reset = '1' or state = st5_flush) then
				round_counter <= (others => '0');
			elsif(round_counter_set = '1') then
				if (key_size_192 = '0' and key_size_256 = '0') then
					round_counter <= to_stdlogicvector(round34);
				elsif (key_size_192 = '1') then
					round_counter <= to_stdlogicvector(round42);
				elsif (key_size_256 = '1') then
					round_counter <= to_stdlogicvector(round50);
				end if ;
			elsif (round_counter_en = '1') then
				case (round_counter_dir & enc_dec) is
					when "10" & '1' =>
						round_counter <= round_counter - 1;
					when "11" & '1' =>
						round_counter <= round_counter - 2;
					when others =>
						round_counter <= round_counter + 1;
				end case;
			end if;
		end if;
	end process;

	round_key_addr <= round_counter;

	-- State register
	state_reg_proc : process (clock)
	begin
		if (clock'event and clock = '1') then
			if (reset = '1') then
				state <= st0_idle;
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
				done 			<= '0';
				sel0 			<= '0';
				sel1 			<= '0';
				sel2 			<= '0';
				sel3 			<= '0';
				t0_t1 		<= '0';
				running 		<= '0';
				srl_addr 	<= (others => '0');
				reset_srl 	<= '1';
				-- internal register
				gfn_8_4_net <= '0';
				t0_t1_l 		<= '0';
			else
				-- assign output registers
				done 			<= done_i;
				sel0 			<= sel0_i;
				sel1 			<= sel1_i;
				sel2 			<= sel2_i;
				sel3 			<= sel3_i;
				t0_t1 		<= t0_t1_i;
				running 		<= running_i;
				srl_addr 	<= srl_addr_i;
				reset_srl 	<= reset_srl_i;
				-- internal register
				gfn_8_4_net <= (key_size_192 or key_size_256) and expand_key;
				t0_t1_l 		<= t0_t1_i;
			end if;
		end if;
	end process;

	output_decode: process (state, gfn_8_4_net, round_number, cycle_counter, t0_t1_l, enc_dec, round_counter)
	begin
		done_i 				<= '0';
		sel0_i 				<= '0';
		sel1_i 				<= '0';
		sel2_i 				<= '0';
		sel3_i 				<= '0';
		t0_t1_i				<= gfn_8_4_net;
		running_i			<= '1';
		round_counter_en	<= '0';
		round_counter_dir <= "00";
		cycle_en 			<= '0';
		reset_cycle 		<= '0';
		srl_addr_i 			<= (others => '1');
		reset_srl_i 		<= '0';
		round_counter_set <= '0';
		case(state) is
			when st0_idle =>
				running_i 			<= '0';
				reset_cycle 		<= '1';
				sel1_i 				<= '1';
				round_counter_set <= enc_dec;
			when st1_init =>
				sel1_i 					<= '1';
				--round_counter_set 	<= enc_dec;
			when st2_prep_block =>
				cycle_en 	<= '1';
				sel1_i 		<= '1';
				t0_t1_i 	<= not t0_t1_l;
				round_counter_en <= '1';
				case (gfn_8_4_net & cycle_counter) is
					-- GFN4 network
					when "00000" | "00011" =>
						sel1_i 				<= not cycle_counter(0);
						sel0_i 				<= cycle_counter(0);
						sel3_i 				<= cycle_counter(0);
						srl_addr_i 			<= "0001";
						round_counter_dir <= cycle_counter(1 downto 0);
						if(enc_dec = '1') then
							t0_t1_i <= cycle_counter(0);
						end if;
					when "00001" =>
						sel1_i 				<= '1';
						srl_addr_i 			<= "0000";
						round_counter_dir <= "11";
						if(enc_dec = '1') then
							t0_t1_i <= '0';
						end if;
					when "00010" =>
						sel1_i 				<= '1';
						srl_addr_i 			<= "0010";
						round_counter_dir <= "10";
					--
					when "00100" =>
						sel1_i 		<= '0';
						sel0_i 		<= '1';
						sel3_i 		<= '1';
						srl_addr_i 	<= "0011";
					when "00101" =>
						sel0_i 		<= '1';
						sel1_i 		<= '0';
						sel3_i 		<= '1';
						reset_cycle <= '1';
						srl_addr_i 	<= "0110";
						if(enc_dec = '1') then
							t0_t1_i <= cycle_counter(1);
						end if;
						round_counter_dir <= "11";
					-- GFN8 network
					when "10000" =>
						sel0_i 				<= '0';
						round_counter_en 	<= '0';
					when "10001" =>
						sel0_i 				<= '0';
						round_counter_en 	<= '0';
					when "10010" =>
						sel0_i 				<= '0';
						round_counter_en 	<= '0';
					when "10011" =>
						sel0_i 				<= '0';
						srl_addr_i 			<= "0100";
					when "10100" =>
						sel0_i 				<= '0';
						srl_addr_i 			<= "0011";
					when "10101" =>
						sel0_i 				<= '0';
						srl_addr_i 			<= "0010";
					when "10110" =>
						sel0_i 				<= '1';
						sel1_i 				<= '0';
						srl_addr_i 			<= "0001";
					when "10111" =>
						sel0_i 				<= '1';
						sel1_i 				<= '0';
						srl_addr_i 			<= "0111";
					when "11000" =>
						sel0_i 				<= '1';
						sel1_i 				<= '0';
						sel2_i 				<= gfn_8_4_net;
						sel3_i 				<= gfn_8_4_net;
						srl_addr_i 			<= "0110";
					when "11001" =>
						sel0_i 				<= '1';
						sel1_i 				<= '0';
						sel2_i 				<= gfn_8_4_net;
						sel3_i 				<= gfn_8_4_net;
						srl_addr_i 			<= "0101";
					when "11010" =>
						sel0_i 				<= '1';
						sel1_i 				<= '0';
						sel2_i 				<= gfn_8_4_net;
						sel3_i 				<= gfn_8_4_net;
						srl_addr_i 			<= "0100";
					when "11011" =>
						sel0_i 				<= '1';
						sel1_i 				<= '0';
						sel2_i 				<= gfn_8_4_net;
						sel3_i 				<= gfn_8_4_net;
						srl_addr_i 			<= "1010";
					when "11100" =>
						sel0_i 				<= '1';
						sel1_i 				<= '0';
						sel2_i 				<= gfn_8_4_net;
						sel3_i 				<= gfn_8_4_net;
						srl_addr_i 			<= "1001";
					when "11101" =>
						sel0_i 				<= '1';
						sel1_i 				<= '0';
						sel2_i 				<= gfn_8_4_net;
						sel3_i 				<= gfn_8_4_net;
						srl_addr_i 			<= "1000";
					when "11110" =>
						sel0_i 				<= '1';
						sel1_i 				<= '0';
						sel2_i 				<= gfn_8_4_net;
						sel3_i 				<= gfn_8_4_net;
						srl_addr_i 			<= "1111";
						reset_cycle 		<= '1';
					when others =>
						sel0_i 				<= '1';
				end case;
			when st3_loop0 =>
				round_counter_en 	<= '1';
				t0_t1_i 				<= not t0_t1_l;
				sel0_i 				<= '1';
				sel2_i 				<= gfn_8_4_net;
				sel3_i 				<= '1';
				----
				round_counter_dir <= not cycle_counter(0) & cycle_counter(0);
				--
				if(gfn_8_4_net = '0') then
					srl_addr_i 	<= "0001";
				-- remove later
				elsif (round_counter(5 downto 2) = "1011") then
					srl_addr_i 	<= "0110"; -- final flush
				else
					srl_addr_i 	<= "0101";
				end if;
			when st4_loop1 =>
				round_counter_en 	<= '1';
				sel0_i 				<= '1';
				sel2_i 			<= gfn_8_4_net;
				sel3_i 			<= '1';
				t0_t1_i			<= not t0_t1_l;
				--
				if(enc_dec = '1') then
					t0_t1_i 		<= not cycle_counter(0);
				end if;
				cycle_en 				<= enc_dec;
				round_counter_dir 	<= "11";
				--
				if(gfn_8_4_net = '0') then
					srl_addr_i 	<= "0011";
				elsif(round_counter(1 downto 0) = "11") then
					srl_addr_i 	<= "1001";
				else
					srl_addr_i 	<= "0101";
				end if;
			when st5_flush =>
				round_counter_en <= '1';
				sel0_i 		<= '1';
				sel3_i 		<= '1';
				reset_cycle <= '1';
				t0_t1_i 	<= not t0_t1_l or enc_dec;
				if(gfn_8_4_net = '0') then
					srl_addr_i 	<= "0011";
				else
					srl_addr_i 	<= "0111";
				end if;
				done_i 		<= gfn_8_4_net;
				--
			when st6_unswap =>
				cycle_en 	<= '1';
				sel0_i 		<= '1';
				case(gfn_8_4_net & cycle_counter & enc_dec) is
					when "00000" & '0' | "00011" & '0' =>
						srl_addr_i <= "0010";
						done_i 		<= not cycle_counter(0);
					when "00001" & '0' =>
						srl_addr_i <= "0001";
					when "00010" & '0' =>
						srl_addr_i <= "0011";
					-- decoding unswap
					when "00000" & '1' =>
						srl_addr_i <= "0001";
						done_i 		<= not cycle_counter(0);
						sel3_i <= '1';
					when "00001" & '1' =>
						done_i 		<= '1';
						srl_addr_i <= "0000";
					when "00010" & '1' =>
						srl_addr_i <= "0100";
					when "00011" & '1' =>
						srl_addr_i <= "0011";
					-- gfn8
					when "10000" & '0' =>
						srl_addr_i <= "0100";
					when "10001" & '0' =>
						srl_addr_i <= "1000";
					when "10010" & '0' =>
						srl_addr_i <= "0101";
					when "10011" & '0' =>
						srl_addr_i <= "1001";
					when "10100" & '0' =>
						srl_addr_i <= "0110";
					when "10101" & '0' =>
						srl_addr_i <= "1010";
					when "10110" & '0' =>
						srl_addr_i <= "0111";
					when others =>
						srl_addr_i <= "0000";
				end case;
			when others =>
				null;

		end case;

	end process;

	next_state_decode: process (state, enc_dec, start, round_counter, round_number, gfn_8_4_net, cycle_counter, expand_key, key_ready)
	begin
		--default state for next_state to avoid latches
		next_state <= state;
		--decode next state
		case (state) is
			-- code states
			when st0_idle =>
				if ((start = '1' and expand_key = '0') or key_ready = '1') then
					next_state <= st1_init;
				end if;
			when st1_init =>
				next_state <= st2_prep_block;
			when st2_prep_block =>
				if (gfn_8_4_net & cycle_counter = "00101" or gfn_8_4_net & cycle_counter = "11110") then
					next_state <= st3_loop0;
				end if;
			when st3_loop0 =>
				if ( round_counter = round_number or round_counter = to_stdlogicvector(round0) ) then
					next_state <= st5_flush;
				else
					next_state <= st4_loop1;
				end if;
			when st4_loop1 =>
				next_state <= st3_loop0;
			when st5_flush =>
					next_state <= st6_unswap;
			when st6_unswap =>
				if(gfn_8_4_net & cycle_counter = "00011" or gfn_8_4_net & cycle_counter = "10111") then
					if(start = '1') then
						next_state <= st1_init;
					else
						next_state <= st0_idle;
					end if;
				end if;
			---- just in case
			when others =>
				next_state <= st0_idle;
		end case;
	end process;

end behavioral;