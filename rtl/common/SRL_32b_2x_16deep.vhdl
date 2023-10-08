----------------------------------------------------------------------------------
-- Engineer: João Carlos Cabrita Resende
-- 
-- Create Date:    03/2015 
-- Module Name:    SRL_32b_16deep - Behavioral 
-- Target Devices: The following code should be able to be implemented in any XILINX
--						FPGA from series 5, 6 and 7. However, due to differences in technology,
--						the code may result in differences in final resource utilization.
--
-- Description: +The following code implements a Shift Register of 32 bits wide and
--					16 positions deep.
--					 +Data WRITE is ALWAYS synchronous.
--					 +Data READ may be synchronous or asynchronous, depending on wether or not an
--					optional output register is used. If used, the correct output data will be
--					available a cycle after the proper address has been inputed.
--					 +The reading address is not syncronous.
--					 +All control signals (cen,cen_out,reset_out) are High Active.
--					 +Signal reset_out prevails over cen_out.
--
-- Resources: In the most area efficiency implementations, the following code should use either
--				16 or 32 LUTs (in Shift Register Mode).
--
-- ASCII Schematic:
--
--										__           __           __           __         __           __
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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity SRL_32b_2x_16deep is
    Port (
			input : in  STD_LOGIC_VECTOR (31 downto 0);
           	address : in  STD_LOGIC_VECTOR (4 downto 0);

           	clock : in  STD_LOGIC;
           	cen : in  STD_LOGIC;
			cen_out : in STD_LOGIC;
			reset_out : in STD_LOGIC;
			  
           	output : out  STD_LOGIC_VECTOR (31 downto 0)
		);
end SRL_32b_2x_16deep;

architecture Behavioral of SRL_32b_2x_16deep is

	signal srl1_exit : std_logic_vector(31 downto 0);
	signal srl2_exit : std_logic_vector(31 downto 0);

	signal output_sel : std_logic_vector(31 downto 0);

begin

-- Optional register (to reduce critical path) ---------------------------
	process(clock)
	begin
		if rising_edge(clock) then
			if reset_out = '1' then
				output <= (others=>'0');
			elsif cen_out = '1' then
				output <= output_sel;
			end if;
		end if;
	end process;

	--	output <= srl_exit;	-- If output register is not adequate comment above
---------------------------------------------------------------------------

-- Additional Multiplex for the output (to suppor dual SRL16 mode) --------
	output_sel	<= srl1_exit when address(4) = '1' else
				   srl2_exit;
---------------------------------------------------------------------------

	SHIFT_REGISTER_32b_WIDE_16b_DEEP_U0:
	for ciclo_1 in 0 to 31 generate
		begin
			SRL16E_inst : SRL16E
				generic map (
					INIT => X"0000")
				port map (
					Q => srl1_exit(ciclo_1),		-- SRL data output
					A0 => address(0),				-- Select[0] input
					A1 => address(1),				-- Select[1] input
					A2 => address(2),				-- Select[2] input
					A3 => address(3),				-- Select[3] input
					CE => cen,					-- Clock enable input
					CLK => clock,					-- Clock input
					D => input(ciclo_1)			-- SRL data input
				);
	end generate SHIFT_REGISTER_32b_WIDE_16b_DEEP_U0;

	SHIFT_REGISTER_32b_WIDE_16b_DEEP_U1:
	for ciclo_1 in 0 to 31 generate
		begin
			SRL16E_inst : SRL16E
				generic map (
					INIT => X"0000")
				port map (
					Q => srl2_exit(ciclo_1),		-- SRL data output
					A0 => address(0),				-- Select[0] input
					A1 => address(1),				-- Select[1] input
					A2 => address(2),				-- Select[2] input
					A3 => address(3),				-- Select[3] input
					CE => cen,					-- Clock enable input
					CLK => clock,					-- Clock input
					D => srl1_exit(ciclo_1)			-- SRL data input
				);
	end generate SHIFT_REGISTER_32b_WIDE_16b_DEEP_U1;
end Behavioral;