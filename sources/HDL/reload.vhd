
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity reload is
    Port ( 
    clk_in : in STD_LOGIC;
    trigger : in std_logic
    );
end reload;

architecture Behavioral of reload is
    constant SYNC_WORD : std_logic_vector(31 downto 0) := x"5599AA66";
    constant NOOP : std_logic_vector(31 downto 0) := x"04000000";
    constant WBSTAR : std_logic_vector(31 downto 0) := x"0C400080";
    constant ADDR : std_logic_vector(31 downto 0) := x"00002D00";
    constant CMD : std_logic_vector(31 downto 0) := x"0C000180";
    constant IPROG : std_logic_vector(31 downto 0) := x"000000F0";
    
    signal cs,trigger_r : std_logic;
    signal data : std_logic_vector(31 downto 0);
    signal state : std_logic_vector(3 downto 0);

begin
P_delay_trigger:process(clk_in,trigger)
variable cnt : integer range 0 to 200 := 0;
begin
    if rising_edge(clk_in) then
        if trigger = '0' then
            cnt := 0;
            trigger_r <= '0';
        else
            if cnt < 100 then
                cnt := cnt + 1;
                trigger_r <= '0';
            else
                trigger_r <= '1';
            end if;
        end if;
    end if;
end process;
P_reload: process(clk_in,trigger_r)
begin
    if rising_edge(clk_in) then
        if trigger_r = '0' then
            state <= x"0";
            cs <= '1';
            data <= (others => '0');
        else case state is
            when x"0" =>
                state <= x"1";
                cs <= '1';
                data <= (others => '0');
            when x"1" =>
                state <= x"2";
                cs <= '0';
                data <= (others => '0');
            when x"2" =>
                state <= x"3";
                data <= (others => '1');
            when x"3" =>
                state <= x"4";
                data <= SYNC_WORD;
            when x"4" =>
                state <= x"5";
                data <= NOOP;
            when x"5" =>
                state <= x"6";
                data <= WBSTAR;
            when x"6" =>
                state <= x"7";
                data <= ADDR;
            when x"7" =>
                state <= x"8";
                data <= CMD;
            when x"8" =>
                state <= x"9";
                data <= IPROG;
            when x"9" =>
                state <= x"a";
                data <= NOOP;
            when x"a" =>
                state <= x"b";
                data <= NOOP;
            when x"b" =>
                state <= x"c";
                cs <= '1';
                data <= (others => '0');
            when x"c" => 
            when others =>
        end case;
        end if;
    end if;
end process;
Inst_icap: ICAPE2
    generic map(
    ICAP_WIDTH => "X32",
    SIM_CFG_FILE_NAME => "NONE"
    )
    port map(
    clk => clk_in,
    CSIB => cs,
    O => open,
    I => data,
    RDWRB => '0' -- low to write,should not change during CSIB is low
    );
end Behavioral;
