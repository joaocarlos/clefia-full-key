--------------------------------------------------------------------------------
-- Company: Instituto Superior Tcnico de Lisboa
-- Engineer: João Carlos Nunes Bittencourt
--
-- Design Name:    Data Registry DFF
-- Module Name:    data_registry
-- Project Name:   CLEFIA 256
-- Description:
-- 		D Flip-flop implementation
--
-- Revision:
-- Revision 1.0 - File Created
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity data_registry is
	port (
		data_in 	: in std_logic_vector (31 downto 0);
		clk 		: in std_logic;
		reset 	: in std_logic;
		enable 	: in std_logic;
		data_out : out std_logic_vector (31 downto 0)
	);
end data_registry;

architecture behavioral of data_registry is
begin
	process (clk, reset)
	begin
		if (reset /= '0') then
			data_out <= X"00000000";
		elsif (clk'event and clk = '1') then
			if (enable = '1') then
				data_out <= data_in;
			end if;
		end if;
	end process;
end behavioral;

