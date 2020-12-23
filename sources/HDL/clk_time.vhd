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
    sys_clkg_o : out std_logic;
    sys_clk_32M_o : out std_logic;
    sys_clk_62M5_o : out std_logic;
    sys_clk_125M_o : out std_logic;
    sys_clk_200M_o : out std_logic;
    sys_clk_lock_o : out std_logic;
    led_o : out std_logic_vector(1 downto 0);
    retry_cnt : out std_logic_vector(3 downto 0);
    start_wr_done : out std_logic;
    reset_wr_clk_o : out std_logic
    );
end clk_time;

architecture Behavioral of clk_time is

    signal local_clk,wr_clk : std_logic;
    signal local_clk_i,wr_clk_i,sys_clk_lock,local_clk_lock : std_logic;
    signal local_clk_62M5,local_clk_125M,sys_clk_125M,sys_clk_62M5,sys_clk_62M5_inv : std_logic;
    signal pps_r,pps_r0 : std_logic;
    signal state : std_logic_vector(3 downto 0);
    signal sample_clk,sample_clk_r,sample_done,sample_done_r,sample_done_r1 : std_logic;
    signal reset_wr_clk : std_logic;
    signal retry_cnt_u : unsigned(3 downto 0);
    signal tie_to_ground : std_logic;

begin
tie_to_ground <= '0';
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
sys_clkg_o <= wr_clk_i;
Inst_local_clk_gen:entity work.clk_wiz_0
    port map(
    clk_in1 => local_clk_i,
    clk_out1 => local_clk_62M5,
    clk_out2 => local_clk_125M,
    clk_out3 => local_clk_200M_o,
    locked => local_clk_lock,
    rst => tie_to_ground
    );
    local_clk_125M_o <= local_clk_125M;
    local_clk_lock_o <= local_clk_lock;
Inst_sys_clk_gen: entity work.clk_wiz_0
    port map(
    clk_in1 => wr_clk_i,
    clk_out1 => sys_clk_62M5,
    clk_out2 => sys_clk_125M,
    clk_out3 => sys_clk_200M_o,                
    clk_out4 => sys_clk_62M5_inv,
    clk_out5 => sys_clk_32M_o,
    locked => sys_clk_lock,
    rst => reset_wr_clk
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
    --led_o(1) <= sample_clk_r;
---- find pps rising edge
process(sys_clk_125M)
begin
    if sys_clk_lock = '0' then
        pps_r0 <= '0';
        pps_r <= '0';
    elsif falling_edge(sys_clk_125M) then
        pps_r0 <= pps_i;
        if pps_i = '1' and pps_r0 = '0' then
            pps_r <= '1';
        else
            pps_r <= '0';
        end if;
    end if;
end process;
---- sample sys_clk
process(sys_clk_125M)
variable lock_cnt : integer range 0 to 500;
begin
    if sys_clk_lock = '0' then
        sample_clk <= '0';
        sample_done <= '0';
        lock_cnt := 0;
    elsif rising_edge(sys_clk_125M) then
        if lock_cnt < 500 then
            lock_cnt := lock_cnt + 1;
        elsif pps_r = '1' then
            sample_clk <= sys_clk_62M5;
            sample_done <= '1';
        end if;
    end if;
end process;

process(local_clk_125M)
begin
    if local_clk_lock = '0' then
        reset_wr_clk <= '0';
        state <= x"0";
        retry_cnt_u <= (others => '0');
    elsif rising_edge(local_clk_125M) then
        sample_clk_r <= sample_clk;
        sample_done_r <= sample_done;
        sample_done_r1 <= sample_done_r;
        case state is
            when x"0" =>
                reset_wr_clk <= '0';
                start_wr_done <= '0';
                if sample_done_r1 = '1' then
                    if sample_clk_r = '1' then
                        reset_wr_clk <= '1';
                        retry_cnt_u <= retry_cnt_u + 1;
                        state <= x"1";
                    else
                        state <= x"3";
                    end if;
                end if;
            when x"1" =>
                if sys_clk_lock = '0' then
                    state <= x"2";
                end if;
            when x"2" =>
                reset_wr_clk <= '0';
                state <= x"0";
            when x"3" =>
                start_wr_done <= '1';
                if sample_clk_r = '1' then
                    reset_wr_clk <= '1';
                    state <= x"1";
                    start_wr_done <= '0';
                end if;
            when others =>
                state <= x"0";
        end case;
    end if;
end process;
-- Inst_ila : entity work.ila_2
-- port map(
-- clk => local_clk_125M,
-- probe0(0) => sample_done_r1,
-- probe1(0) => sample_clk_r,
-- probe2(0) => sys_clk_lock,
-- probe3 => state,
-- probe4(0) => pps_r
-- );
retry_cnt <= std_logic_vector(retry_cnt_u);
    local_clk_62M5_o <= local_clk_62M5;
    sys_clk_125M_o <= sys_clk_125M;
    sys_clk_lock_o <= sys_clk_lock;
    sys_clk_62M5_o <= sys_clk_62M5;
    reset_wr_clk_o <= reset_wr_clk;
end Behavioral;
