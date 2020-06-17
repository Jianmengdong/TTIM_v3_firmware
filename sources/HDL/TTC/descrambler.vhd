----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2019/04/01 13:09:19
-- Design Name: 
-- Module Name: descrambler - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity descrambler is
  port (
    clk_i   : in  std_logic;
    reset_i : in  std_logic;
    D       : in  std_logic;
    Q       : out std_logic
    );
end descrambler;

architecture Behavioral of descrambler is

  signal LSR : std_logic_vector(22 downto 0);
  signal feedback     : std_logic;
  signal internal_out : std_logic;

begin
  process(clk_i)
  begin
    if reset_i = '1' then
      LSR <= (others => '0');
    elsif rising_edge(clk_i) then 
      LSR(22 downto 1) <= LSR (21 downto 0);
      LSR(0)           <= D;
    end if;
  end process;

  feedback     <= LSR(17) xor LSR(22);
  internal_out <= D xor feedback;

  Q <= internal_out;
end Behavioral;
