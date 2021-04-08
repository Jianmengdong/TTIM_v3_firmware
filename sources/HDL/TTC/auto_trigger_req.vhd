
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity auto_trigger_req is
    Port ( 
    clk_i : in STD_LOGIC;
    auto_trigger_i : in STD_LOGIC;
    chb_req_o : out std_logic;
    chb_grant_i : in std_logic;
    autotrigger_o : out std_logic
    );
end auto_trigger_req;

architecture Behavioral of auto_trigger_req is
    signal state : std_logic_vector(3 downto 0);
begin

process(clk_i)
begin
    if rising_edge(clk_i) then
        case state is
            when x"0" =>
                autotrigger_o <= '0';
                chb_req_o <= '0';
                if auto_trigger_i = '1' then
                    state <= x"1";
                    chb_req_o <= '1';
                    autotrigger_o <= '1';
                end if;
            when x"1" => 
                if chb_grant_i = '1' then
                    autotrigger_o <= '1';
                    state <= x"0";
                    chb_req_o <= '0';
                end if;
            when others =>
                state <= x"0";
        end case;
    end if;
end process;

end Behavioral;
