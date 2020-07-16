--========================================================
-- 05/12/2019 -- version2: change first latched bytes 
--                data comparison with x"AB" to be compatible
--                with new mini-WR firmware
--========================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;
use work.lite_bus_pack.all;
use work.TTIM_pack.all;
entity wr_interface is
    Port ( 
    sys_clk_i : in STD_LOGIC;
    reset_i : in std_logic;
    wr_locked : in std_logic;
    PDATA_RX : in std_logic_vector(9 downto 0);
    PDATA_TX : inout std_logic_vector(9 downto 0);
    lite_bus_w : out t_lite_wbus_arry(NSLV - 1 downto 0);
    lite_bus_r : in t_lite_rbus_arry(NSLV - 1 downto 0);
    update_data: out std_logic_vector(UPDATE_DATA_WIDTH - 1 downto 0);
    update_data_valid : out std_logic;
    update_fifo_empty : in std_logic;
    update_error : in std_logic_vector(5 downto 0);
    update_status : in std_logic_vector(8 downto 0);
    update_control : out std_logic_vector(19 downto 0);
    re_load : out std_logic;
    PPS_IN_P : in std_logic;
    PPS_IN_N : in std_logic;
    pps_o : out std_logic;
    pps_original : out std_logic;
    timestamp_o : out std_logic_vector(67 downto 0);
    timestamp_48b_o : out std_logic_vector(47 downto 0)
    --debug_fsm : out std_logic_vector(3 downto 0)
    );
end wr_interface;

architecture Behavioral of wr_interface is

    signal sel :integer;
    signal wr_rx_ctrl,wr_rx_ctrl_i : std_logic_vector(1 downto 0);
    signal wr_rx_data,wr_tx_data,wr_rx_data_i : std_logic_vector(7 downto 0);
    signal wr_tx_cts,wr_tx_vld : std_logic;
    signal data_send,data_tx : std_logic_vector(79 downto 0);
    signal data_buf : std_logic_vector(159 downto 0) := (others => '0');
    type t_state is (st0_idle,st1_get_data,st2_assmble_data,
                    st3_wait_respond,st4_respond,st5_CRC_error,st5_addr_error,
                    st5_timeout_error);
    signal state : t_state;
    signal ack,data_valid,pps_i,timer_valid : std_logic;
    signal debug_fsm : std_logic_vector(3 downto 0);
    signal timer_utc : std_logic_vector(39 downto 0);
    signal timer_8ns : std_logic_vector(27 downto 0);
    signal timer_8ns_u : unsigned(47 downto 0);
    signal timer_utc_u : unsigned(47 downto 0);
    signal timer_total : unsigned(95 downto 0);
    signal pack_probe : std_logic;
    
begin
Ibuf:IBUFDS
port map(
I => PPS_IN_P,
IB => PPS_IN_N,
O => pps_i
);
pps_original <= pps_i;
Inst_timer:entity work.fmc_timer
    port map(
    rst_n => not reset_i,
    fmc_clk => sys_clk_i,
    fmc_tm_serial => pps_i,
    pps_o => pps_o,
    timer_utc => timer_utc,
    timer_8ns => timer_8ns,
    timer_valid => timer_valid
    );
    timestamp_o <= timer_utc & timer_8ns when timer_valid = '1' else (others => '0');
    timer_utc_u <= x"0000000" & unsigned(timer_utc(19 downto 0));
    timer_8ns_u <= x"00000" & unsigned(timer_8ns);
    timer_total <= timer_utc_u * 125000000 + timer_8ns_u;
    timestamp_48b_o <= std_logic_vector(timer_total(47 downto 0));
p_latch_wr_data:process(sys_clk_i)
begin
    if falling_edge(sys_clk_i) then
        wr_rx_ctrl <= PDATA_RX(9 downto 8);
        wr_rx_data <= PDATA_RX(3 downto 0) & PDATA_RX(7 downto 4);
        --PDATA_TX <= wr_tx_vld & 'Z' & wr_tx_data;
    end if;
end process;
PDATA_TX(8) <= 'Z';
p_wr_txdata:process(sys_clk_i)
begin
    if rising_edge(sys_clk_i) then
        PDATA_TX(9) <= wr_tx_vld;
        PDATA_TX(7 downto 0) <= wr_tx_data;
        wr_tx_cts <= PDATA_TX(8);
        wr_rx_data_i <= wr_rx_data;
        wr_rx_ctrl_i <= wr_rx_ctrl;
    end if;
end process;
process(sys_clk_i)
variable cnt : integer range 0 to 10;
variable len : integer range 0 to 20;
variable time_out_cnt : integer range 0 to 65535;
begin
    if reset_i = '1' then
        state <= st0_idle;
        data_buf <= (others => '0');
    elsif rising_edge(sys_clk_i) then
        case state is
            when st0_idle =>
                data_buf <= (others => '0');
                data_valid <= '0';
                wr_tx_vld <= '0';
                update_data_valid <= '0';
                data_send <= (others => '0');
                cnt := 0;
                len := 0;
                re_load <= '0';
                time_out_cnt := 0;
                if wr_rx_ctrl_i = "01" then
                    if wr_rx_data_i = x"AB" then
                        state <= st1_get_data;
                        len := 1;
                        data_buf(7 downto 0) <= wr_rx_data_i;
                    else
                        state <= st2_assmble_data;
                    end if;
                end if;
                debug_fsm <= x"0";
                pack_probe <= '0';
            when st1_get_data =>
                data_buf <= data_buf(151 downto 0) & wr_rx_data_i;
                len := len + 1;
                if wr_rx_ctrl_i = "10" then
                    state <= st2_assmble_data;
                elsif wr_rx_ctrl_i = "11" then
                    state <= st5_CRC_error;
                end if;
                debug_fsm <= x"1";
            when st2_assmble_data =>
                cnt := 4;
                if len = 8 and data_buf(UPDATE_DATA_WIDTH+15 downto UPDATE_DATA_WIDTH) = x"55FF" then --update bitstream
                    update_data_valid <= '1';
                    update_data <= data_buf(UPDATE_DATA_WIDTH - 1 downto 0);
                    data_send(79 downto 48) <= data_buf(UPDATE_DATA_WIDTH+31 downto UPDATE_DATA_WIDTH+16) & x"0001";
                    state <= st4_respond;
                elsif len = 10 and data_buf(63 downto 60) = x"4" then  -- litebus packet
                    data_valid <= '1';
                    state <= st3_wait_respond;
                elsif len = 6 and data_buf(31 downto 16) = x"5555" then --update check status
                    data_send(79 downto 48) <= data_buf(47 downto 32) & update_fifo_empty & update_status & update_error;
                    state <= st4_respond;
                elsif len = 6 and data_buf(31 downto 24) = x"55" then --update control
                    update_control <= data_buf(19 downto 0);
                    re_load <= data_buf(20);
                    data_send(79 downto 48) <= data_buf(47 downto 32) & x"0001";
                    state <= st4_respond;
                else --other packet
                    state <= st0_idle;
                    pack_probe <= '1';
                end if;
                debug_fsm <= x"2";
            when st3_wait_respond =>
                time_out_cnt := time_out_cnt + 1;
                if time_out_cnt <= TIME_OUT then
                    if sel = 99 then
                        state <= st5_addr_error;
                    elsif ack = '1' then
                        data_send <= data_tx;
                        state <= st4_respond;
                        time_out_cnt := 0;
                    end if;
                else
                    state <= st5_timeout_error;
                    time_out_cnt := 0;
                end if;
                cnt := 10;
                debug_fsm <= x"3";
            when st4_respond =>
                update_data_valid <= '0';
                if wr_tx_cts = '1' then
                    if cnt > 0 then
                        wr_tx_vld <= '1';
                        wr_tx_data <= data_send(79 downto 72);
                        data_send <= data_send(71 downto 0) & x"00";
                        cnt := cnt - 1;
                    else
                        cnt := 0;
                        wr_tx_vld <= '0';
                        data_valid <= '0';
                        state <= st0_idle;
                    end if;
                else 
                    time_out_cnt := time_out_cnt + 1;
                    if time_out_cnt = TIME_OUT then
                        state <= st0_idle;
                        pack_probe <= '1';
                    end if;
                end if;
                debug_fsm <= x"4";
            when st5_CRC_error =>
                cnt := 10;
                pack_probe <= '1';
                data_send <= x"ABC0FFFFFFFFFFFFFFFF";
                state <= st4_respond;
                debug_fsm <= x"5";
            when st5_addr_error =>
                cnt := 10;
                data_send <= data_buf(79 downto 56) & x"FFFFFFFFFFFFFF";
                state <= st4_respond;
            when st5_timeout_error =>
                cnt := 10;
                data_send <= x"ABC00000000000000000";
                state <= st4_respond;
            when others =>
                state <= st0_idle;
        end case;
    end if;
end process;
process(sys_clk_i)
begin
    if rising_edge(sys_clk_i) then
        ack <= lite_bus_r(sel).ack;
    end if;
end process;
data_tx <= data_buf(79 downto 64) & lite_bus_r(sel).head & lite_bus_r(sel).data;

process(data_buf)
begin
    sel <= f_lite_bus_addr_sel(data_buf(55 downto 48));
end process;
Gen_slaves:for i in NSLV - 1 downto 0 generate
begin
    lite_bus_w(i).strobe <= '1' when sel = i and data_valid = '1' else '0';
    lite_bus_w(i).wr_rd <= data_buf(56); --1 for write, 0 for read
    lite_bus_w(i).data <= data_buf(47 downto 0);
    lite_bus_w(i).head <= data_buf(63 downto 57);
    lite_bus_w(i).addr <= data_buf(55 downto 48);
end generate;
i_ila:entity work.ila_1
    port map(
    clk => sys_clk_i,
    probe0 => wr_rx_ctrl_i,
    probe1 => wr_rx_data_i,
    probe2(0) => wr_tx_cts,
    probe3 => wr_tx_data,
    probe4(0) => wr_tx_vld,
    probe5 => data_buf,
    probe6 => data_send,
    probe7 => debug_fsm,
    probe8(0) => pack_probe
    );
end Behavioral;
