----------------------------------------------------------------------------------
-- Engineer: João Carlos Cabrita Resende
--
-- Create Date:    03/2015
-- Module Name:    SRL_32b_16deep - Behavioral
-- Target Devices: The following code should be able to be implemented in any XILINX
--						 FPGA from series 5, 6 and 7. However, due to differences in technology,
--						 the code may result in differences in final resource utilization.
--
-- Description: + The following code implements a Shift Register of 32 bits wide and
--					   16 positions deep.
--					 + Data WRITE is ALWAYS synchronous.
--					 + Data READ may be synchronous or asynchronous, depending on wether or not an
--					   optional output register is used. If used, the correct output data will be
--					   available a cycle after the proper address has been inputed.
--					 + The reading address is not syncronous.
--					 + All control signals (cen,cen_out,reset_out) are High Active.
--					 + Signal reset_out prevails over cen_out.
--
-- Resources: In the most area efficiency implementations, the following code should use either
--				  16 or 32 LUTs (in Shift Register Mode).
--
-- ASCII Schematic:
--
--									  	__           __           __           __         __           __
--									   |  |         |  |         |  |         |  |       |  |         |  |
--					input --(32)-->| 0|--(32)-->| 1|--(32)-->| 2|--(32)-->| 3|  ...  |14|--(32)-->|15|--(32)-->
--									   |/\|         |/\|         |/\|         |/\|       |/\|         |/\|
--					cen;clock________|____________|____________|____________|__________|____________|
--
--
--					address --(4)---------|
--											    |
--											  |\|
--								 0 --(32)--| \           __
--								 1 --(32)--|M |         |  |
--								 2 --(32)--| U|--(32)-->|  |--(32)--> output
--							  ...         |X |         |/\|
--								15 --(32)--| /            |
--											  |/             |
--																  |
--						cen_out;reset_out;clock	--------|
--
--
-- Details:
--				address(3) = High Order Bit
--				address(0) = Low Order Bit
--                Examples:
--							address=0001  <=> output=Register_1
--							address=1000  <=> output=Register_8
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.VComponents.all;

entity SRL_32b_16deep is
	port (
		input 	: in  std_logic_vector (31 downto 0);
		address 	: in  std_logic_vector (3 downto 0);
		clock 	: in  std_logic;
		cen 		: in  std_logic;
		cen_out 	: in std_logic;
		reset_out: in std_logic;
		--
		output 	: out  std_logic_vector (31 downto 0)
	);
end SRL_32b_16deep;

architecture behavioral of SRL_32b_16deep is
	signal srl_exit : std_logic_vector (31 downto 0);
begin

	-- Optional register (to reduce critical path) ---------------------------
	process(clock)
	begin
		if rising_edge(clock) then
			if reset_out = '1' then
				output <= (others=>'0');
			elsif cen_out = '1' then
				output <= srl_exit;
			end if;
		end if;
	end process;

	--	output <= srl_exit;	-- If output register is not adequate comment above
	---------------------------------------------------------------------------

	SHIFT_REGISTER_32b_WIDE_16b_DEEP:
		for cycle in 0 to 31 generate
		begin
			SRL16E_inst : SRL16E
			generic map ( INIT => X"0000")
			port map (
				Q => srl_exit(cycle),		-- SRL data output
				A0 => address(0),				-- Select[0] input
				A1 => address(1),				-- Select[1] input
				A2 => address(2),				-- Select[2] input
				A3 => address(3),				-- Select[3] input
				CE => cen,						-- Clock enable input
				CLK => clock,					-- Clock input
				D => input(cycle)				-- SRL data input
			);
	end generate SHIFT_REGISTER_32b_WIDE_16b_DEEP;

end behavioral;