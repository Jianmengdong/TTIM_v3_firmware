
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity startup is
    Port ( 
    clk_in : in STD_LOGIC;
    local_clk_lock : in std_logic;
    start_wr_done : in std_logic;
    reset_sync_links : out std_logic_vector(47 downto 0);
    reset_trig_link : out std_logic;
    
    startup_status : out std_logic_vector(2 downto 0)
    );
end startup;

architecture Behavioral of startup is
    
    signal state : std_logic_vector(3 downto 0);
    
begin
process(clk_in)
variable wait_cnt : integer range 0 to 500;
begin
    if local_clk_lock = '0' then
        reset_sync_links <= (others => '1');
        reset_trig_link <= '1';
        wait_cnt := 0;
        state <= x"0";
        startup_status <= "000";
    elsif rising_edge(clk_in) then
        case state is
            when x"0" =>
                reset_sync_links <= (others => '1');
                reset_trig_link <= '1';
                startup_status <= "000";
                if start_wr_done = '1' then
                    state <= x"1";
                    wait_cnt := 0;
                end if;
            when x"1" => 
                wait_cnt := wait_cnt + 1;
                if wait_cnt = 500 then
                    state <= x"2";
                end if;
                startup_status <= "001";
            when x"2" =>
                wait_cnt := 0;
                reset_sync_links <= x"000000FFFFFF";
                reset_trig_link <= '1';
                state <= x"3";
                startup_status <= "001";
            when x"3" => 
                wait_cnt := wait_cnt + 1;
                if wait_cnt = 500 then
                    state <= x"4";
                end if;
            when x"4" =>
                wait_cnt := 0;
                reset_sync_links <= (others => '0');
                reset_trig_link <= '1';
                startup_status <= "011";
                state <= x"5";
            when x"5" => 
                wait_cnt := wait_cnt + 1;
                if wait_cnt = 500 then
                    state <= x"6";
                end if;
            when x"6" =>
                wait_cnt := 0;
                reset_sync_links <= (others => '0');
                reset_trig_link <= '0';
                startup_status <= "111";
                --state <= x"3";
            when others =>
                state <= x"0";
        end case;
    end if;
end process;
-- Inst_ila:entity work.ila_2
-- port map(
-- clk => clk_in,
-- probe0 => state
-- );
end Behavioral;
