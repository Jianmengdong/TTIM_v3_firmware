
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity i2c_master is
    generic(
    SCALE : integer range 0 to 400 := 200
    );
    Port ( 
    clk_i : in STD_LOGIC;
    rst_i : in std_logic;
    scl_o : out std_logic;
    sda_o : out std_logic;
    sda_i : in std_logic;
    rw : in std_logic;
    ack_inv : in std_logic;
    addr_i : in std_logic_vector(7 downto 0);
    data_i : in std_logic_vector(7 downto 0);
    start_i : in std_logic;
    rp_start : in std_logic;
    stop_i : in std_logic;
    data_o : out std_logic_vector(7 downto 0);
    byte_done_o : out std_logic;
    error : out std_logic;
    busy : out std_logic
    );
end i2c_master;

architecture Behavioral of i2c_master is

    signal scaler : integer range 0 to 400;
    signal scl,sda,start_i1,scl_gen,stop : std_logic;
    type t_state is (st0_idle,st1_gen_start,st2_send_addr,st3_read,st4_write,st_error,
                    st_gen_rp_start,st_gen_stop,st_gen_stop1,st_send_ack,st_send_ack1,st_wait_ack);
    signal state,state_after_ack,state_after_send_ack : t_state;
    signal bit_cnt : integer range 0 to 15;
    signal bit_cnt_v : std_logic_vector(3 downto 0) :=(others => '0');
    signal addr,addr_r,data,data_w : std_logic_vector(7 downto 0);
    signal fsm : std_logic_vector(3 downto 0);
    signal byte_done : std_logic;

begin
addr_r <= addr_i(7 downto 1) & rw;
P_scaler:process(clk_i)
begin
    if rst_i = '1' then
        scaler <= 0;
        scl_gen <= '0';
        scl <= '1';
    elsif rising_edge(clk_i) then
        start_i1 <= start_i;
        case scl_gen is
            when '0' =>
                scaler <= 0;
                scl <= '1';
                if start_i = '1' and start_i1 = '0' then
                    scl_gen <= '1';
                end if;
            when '1' =>
                scaler <= scaler + 1;
                if stop = '0' then
                    if scaler = SCALE then
                        scaler <= 0;
                        scl <= not scl;
                    end if;
                else
                    scl_gen <= '0';
                end if;
            when others =>
                scl_gen <= '0';
        end case;
    end if;
end process;
P_master:process(clk_i)
begin
    if rst_i = '1' then
        state <= st0_idle;
        sda <= '1';
        stop <= '0';
        byte_done <= '0';
    elsif rising_edge(clk_i) then
        case state is
            when st0_idle =>
                sda <= '1';
                stop <= '0';
                byte_done <= '0';
                busy <= '0';
                if start_i = '1' and start_i1 = '0' then
                    state <= st1_gen_start;
                    error <= '0';
                end if;
                fsm <= x"0";
            when st1_gen_start =>
                busy <= '1';
                if scaler = SCALE/2 and scl = '1' then
                    sda <= '0';
                    addr <= addr_r;
                    state <= st2_send_addr;
                end if;
                fsm <= x"1";
                bit_cnt <= 0;
            when st2_send_addr =>
                if bit_cnt <= 8 then
                    if scaler = SCALE/2 and scl = '0' then
                        sda <= addr(7);
                        addr <= addr(6 downto 0) & addr(7);
                        bit_cnt <= bit_cnt + 1;
                    end if;
                else
                    state <= st_wait_ack;
                    sda <= '1';
                    if rw = '1' then
                        state_after_ack <= st3_read;
                    else
                        state_after_ack <= st4_write;
                        data_w <= data_i;
                    end if;
                end if;
                fsm <= x"2";
            when st3_read =>
                sda <= '1';
                if stop_i = '0' then
                    byte_done <= '0';
                    if bit_cnt < 8 then
                        if scaler = SCALE/2 and scl = '1' then
                            data <= data(6 downto 0) & sda_i;
                            bit_cnt <= bit_cnt + 1;
                        end if;
                    else
                        state <= st_send_ack;
                        state_after_send_ack <= st3_read;
                    end if;
                elsif rp_start = '1' then
                    state <= st_gen_rp_start;
                else 
                    state <= st_gen_stop;
                end if;
                fsm <= x"3";
            when st4_write =>
                if rp_start = '1' then
                    state <= st_gen_rp_start;
                elsif stop_i = '0' then
                    byte_done <= '0';
                    if bit_cnt <= 8 then
                        if scaler = SCALE/2 and scl = '0' then
                            sda <= data_w(7);
                            data_w <= data_w(6 downto 0) & data_w(7);
                            bit_cnt <= bit_cnt + 1;
                        end if;
                    else
                        state <= st_wait_ack;
                        sda <= '1';
                        state_after_ack <= st4_write;
                    end if;
                else 
                    state <= st_gen_stop;
                end if;
                fsm <= x"4";
            when st_wait_ack =>
                bit_cnt <= 0;
                if scaler = SCALE/2 and scl = '1' then
                    if sda_i = '0' then
                        state <= state_after_ack;
                        byte_done <= '1';
                        data_w <= data_i;
                    else
                        state <= st_error;
                    end if;
                end if;
                fsm <= x"5";
            when st_send_ack =>
                bit_cnt <= 0;
                if scaler = SCALE/2 and scl = '0' then
                    if ack_inv = '1' then
                        sda <= '1';
                    else
                        sda <= '0';
                    end if;
                    state <= st_send_ack1;
                end if;
                fsm <= x"6";
            when st_send_ack1 => 
                if scaler = SCALE/4 and scl = '0' then
                    sda <= '1';
                    byte_done <= '1';
                    state <= state_after_send_ack;
                end if;
                fsm <= x"7";
            when st_gen_rp_start =>
                sda <= '1';
                state <= st1_gen_start;
                fsm <= x"8";
            when st_gen_stop =>
                sda <= '0';
                state <= st_gen_stop1;
                fsm <= x"9";
            when st_gen_stop1 =>
                if scaler = SCALE/2 and scl = '1' then
                    sda <= '1';
                    stop <= '1';
                    state <= st0_idle;
                end if;
                fsm <= x"a";
            when st_error => 
                state <= st_gen_stop;
                error <= '1';
                fsm <= x"b";
            when others =>
                state <= st0_idle;
        end case;
    end if;
end process;
bit_cnt_v <= std_logic_vector(to_unsigned(bit_cnt, 4));
-- Inst_ila:entity work.ila_0
    -- port map(
    -- clk => clk_i,
    -- probe0 => bit_cnt_v,
    -- probe1 => fsm,
    -- probe2(0) => byte_done,
    -- probe3(0) => stop,
    -- probe4(0) => scl,
    -- probe5(0) => sda_i
    -- );
data_o <= data;
scl_o <= scl;
sda_o <= sda;
byte_done_o <= byte_done;
end Behavioral;
