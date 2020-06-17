library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;
package lite_bus_pack is
    constant TIME_OUT : integer range 0 to 65535 := 65535;
    constant NSLV : integer range 0 to 255 := 60;
    type t_lite_rbus is
        record
        ack : std_logic;
        head : std_logic_vector(7 downto 0);
        data : std_logic_vector(55 downto 0);
        end record;
    type t_lite_wbus is
        record
        strobe : std_logic;
        wr_rd : std_logic;
        head : std_logic_vector(6 downto 0);
        addr : std_logic_vector(7 downto 0);
        data : std_logic_vector(47 downto 0);
        end record;
    type t_lite_rbus_arry is array (integer range<>) of t_lite_rbus;
    type t_lite_wbus_arry is array (integer range<>) of t_lite_wbus;
    
    function f_lite_bus_addr_sel(signal addr : std_logic_vector(7 downto 0)) 
                return integer;

end lite_bus_pack;

package body lite_bus_pack is

function f_lite_bus_addr_sel(signal addr : std_logic_vector(7 downto 0)) return integer is
    variable sel : integer;
    begin
        if    std_match(addr, "01000001") then --0x41
            sel := 0;
        elsif std_match(addr, "01000010") then --0x42
            sel := 1;
        elsif std_match(addr, "01000011") then --0x43
            sel := 2;
        elsif std_match(addr, "01000100") then --0x44
            sel := 3;
        elsif std_match(addr, "01000101") then --0x45
            sel := 4;
        elsif std_match(addr, "01000110") then --0x46
            sel := 5;
        elsif std_match(addr, "01000111") then --0x47
            sel := 6;
        elsif std_match(addr, "01001000") then --0x48
            sel := 7;
        elsif std_match(addr, "01001001") then --0x49
            sel := 8;
        elsif std_match(addr, "01001010") then --0x4A
            sel := 9;
        elsif std_match(addr, "01001011") then --0x4B
            sel := 10;
        elsif std_match(addr, "01001100") then --0x4C
            sel := 11;
        elsif std_match(addr, "01001101") then --0x4D
            sel := 12;
        elsif std_match(addr, "01001110") then --0x4E
            sel := 13;
        elsif std_match(addr, "01001111") then --0x4F
            sel := 14;
        elsif std_match(addr, "01010000") then --0x50
            sel := 15;
        elsif std_match(addr, "01010001") then --0x51
            sel := 16;
        elsif std_match(addr, "01010010") then --0x52
            sel := 17;
        elsif std_match(addr, "01010011") then --0x53
            sel := 18;
        elsif std_match(addr, "01010100") then --0x54
            sel := 19;
        elsif std_match(addr, "01010101") then --0x55
            sel := 20;
        elsif std_match(addr, "01010110") then --0x56
            sel := 21;
        elsif std_match(addr, "01010111") then --0x57
            sel := 22;
        elsif std_match(addr, "01011000") then --0x58
            sel := 23;
        elsif std_match(addr, "01011001") then --0x59
            sel := 24;
        elsif std_match(addr, "01011010") then --0x5A
            sel := 25;
        elsif std_match(addr, "01011011") then --0x5B
            sel := 26;
        elsif std_match(addr, "01011100") then --0x5C
            sel := 27;
        elsif std_match(addr, "01011101") then --0x5D
            sel := 28;
        elsif std_match(addr, "01011110") then --0x5E
            sel := 29;
        elsif std_match(addr, "01011111") then --0x5F
            sel := 30;
        elsif std_match(addr, "01100000") then --0x60
            sel := 31;
        elsif std_match(addr, "01100001") then --0x61
            sel := 32;
        elsif std_match(addr, "01100010") then --0x62
            sel := 33;
        else
            sel := 99;
        end if;
        return sel;
    end f_lite_bus_addr_sel;

end lite_bus_pack;
