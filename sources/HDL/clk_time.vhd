library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity clk_time is
    Port ( 
    local_clk_p : in STD_LOGIC; --local 125M oscillator
    local_clk_n : in STD_LOGIC;
    wr_clk_p : in std_logic; --WR clock
    wr_clk_n : in std_logic;
    pps_i : in std_logic;
    local_clk_o : out std_logic; --clock to MGT
    local_clk_62M5_o : out std_logic;
    local_clk_125M_o : out std_logic;
    local_clk_200M_o : out std_logic;
    local_clk_lock_o : out std_logic;
    sys_clk_o : out std_logic; --clock to MGT
    sys_clk_62M5_o : out std_logic;
    sys_clk_125M_o : out std_logic;
    sys_clk_200M_o : out std_logic;
    sys_clk_lock_o : out std_logic;
    led_o : out std_logic_vector(1 downto 0)
    );
end clk_time;

architecture Behavioral of clk_time is

    signal local_clk,wr_clk : std_logic;
    signal local_clk_i,wr_clk_i,sys_clk_lock : std_logic;
    signal local_clk_62M5,sys_clk_125M,sys_clk_62M5,sys_clk_62M5_inv : std_logic;
    signal pps_b,pps_r,pps_r1,st : std_logic;

begin
ibufds_local : IBUFDS_GTE2  
    port map(
    O               => local_clk,
    ODIV2           => open,
    CEB             => '0',
    I               => local_clk_p,
    IB              => local_clk_n
    );
    local_clk_o <= local_clk;
Inst_bufg_local: BUFG
    port map(
    I => local_clk,
    O => local_clk_i
    );
ibufds_sys : IBUFDS_GTE2  
    port map(
    O               => wr_clk,
    ODIV2           => open,
    CEB             => '0',
    I               => wr_clk_p,
    IB              => wr_clk_n
    );
    sys_clk_o <= wr_clk;
Inst_bufg_sys: BUFG
    port map(
    I => wr_clk,
    O => wr_clk_i
    );
    
Inst_local_clk_gen:entity work.clk_wiz_0
    port map(
    clk_in1 => local_clk_i,
    clk_out1 => local_clk_62M5,
    clk_out2 => local_clk_125M_o,
    clk_out3 => local_clk_200M_o,
    locked => local_clk_lock_o
    );
Inst_sys_clk_gen: entity work.clk_wiz_0
    port map(
    clk_in1 => wr_clk_i,
    clk_out1 => sys_clk_62M5,
    clk_out2 => sys_clk_125M,
    clk_out3 => sys_clk_200M_o,                
    clk_out4 => sys_clk_62M5_inv,
    locked => sys_clk_lock
    );
Inst_local_led:entity work.LED_breath
    port map(
    clk     => local_clk_62M5,
    led_o   => led_o(0)
    );
Inst_sys_led:entity work.LED_breath
    port map(
    clk     => sys_clk_62M5,
    led_o   => led_o(1)
    );
    
-- sample pps with 125M clock
process(sys_clk_125M)
begin
    if rising_edge(sys_clk_125M) then
        pps_b <= pps_i;
    end if;
end process;
-- find pps rising edge with 62.5M clock
process(sys_clk_62M5)
variable cnt : integer range 0 to 1023:= 0;
begin
    if sys_clk_lock = '0' then
        cnt := 0;
        st <= '0';
        pps_r <= '0';
    elsif rising_edge(sys_clk_62M5) then
        if cnt < 500 then
            cnt := cnt + 1;
            st <= '0';
        else
            pps_r1 <= pps_i;
            if st = '0' and pps_i = '1' and pps_r1 = '0' then
                pps_r <= pps_b;
                st <= '1';
            end if;
        end if;
    end if;
end process;
    local_clk_62M5_o <= local_clk_62M5;
    sys_clk_125M_o <= sys_clk_125M;
    sys_clk_lock_o <= sys_clk_lock;
    sys_clk_62M5_o <= sys_clk_62M5 when pps_r = '1' else sys_clk_62M5_inv;
end Behavioral;
