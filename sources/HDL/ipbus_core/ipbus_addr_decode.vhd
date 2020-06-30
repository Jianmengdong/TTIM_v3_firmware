-- Address decode logic for ipbus fabric
--
-- This file has been AUTOGENERATED from the address table - do not hand edit
--
-- We assume the synthesis tool is clever enough to recognise exclusive conditions
-- in the if statement.
--
-- Dave Newbold, February 2011

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use work.ipbus.all;

package ipbus_addr_decode is

  function ipbus_addr_sel(signal addr : in std_logic_vector(31 downto 0)) return integer;

end ipbus_addr_decode;

package body ipbus_addr_decode is
  
  function ipbus_addr_sel(signal addr : in std_logic_vector(31 downto 0)) return integer is
    variable sel : integer;
  begin
    -- START automatically  generated VHDL the Tue Jul  9 16:49:55 2013 
    if std_match(addr, "0000000000000000000000000000000-") then
      sel := 0;  -- ctrl_reg / base 0x00000000 / deep = 1
    elsif std_match(addr, "00000000000000000000000001------") then
      sel := 1;  -- cs_write / base 0x00000040 / deep = 54 / addr_width = 6
	 elsif std_match(addr, "000000000000000000000001--------") then
      sel := 2;  -- cs_read / base 0x00000100 / deep = 199 / addr_width = 8
	 elsif std_match(addr, "0000000000000000000000100000000-") then
      sel := 3;  -- error injection / base 0x000018 / deep = 2 / addr_width = 1
    elsif std_match(addr, "0000000000000000000000100000001-") then
      sel := 4;  -- packet counters / base 0x0000001a / deep = 1 / addr_width = 1
    else
      sel := 99;
    end if;
    return sel;
  end ipbus_addr_sel;
  
end ipbus_addr_decode;
