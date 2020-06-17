----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2018/06/13 12:07:33
-- Design Name: 
-- Module Name: LED_breath - Behavioral
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
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity LED_breath is
    Port ( clk : in STD_LOGIC;
           led_o : out STD_LOGIC);
end LED_breath;

architecture Behavioral of LED_breath is
    
    signal clk_1M : std_logic;

begin
    process(clk)
    variable counter : integer := 0;
    begin
        if(rising_edge(clk)) then
            counter := counter + 1;
            if(counter < 30) then
                clk_1M <= '0';
            elsif(counter < 60) then
                clk_1M <= '1';
            else
                counter := 0;
            end if;
        end if;
    end process;
    
    process(clk_1M)
    variable pwmcnt :integer := 0;
    variable pwmgate:integer := 1;
    variable light :boolean := true;
    begin
        if(rising_edge(clk_1M)) then
            pwmcnt := pwmcnt + 1;
            if(pwmcnt = pwmgate) then
                led_o <= '1';
            end if;
            if(pwmcnt = 999) then
                if(light) then
                    pwmgate := pwmgate + 1;
                else
                    pwmgate := pwmgate - 1;
                end if;
                pwmcnt := 0;
                led_o <= '0';
            end if;
            if(pwmgate = 999) then
                light := false;
            elsif(pwmgate = 1) then
                light := true;
            end if;
        end if;
    end process;

end Behavioral;
