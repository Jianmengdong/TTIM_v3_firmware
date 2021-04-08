--========================================================
-- 05/12/2019 -- version2: change first latched bytes 
--                data comparison with x"AB" to be compatible
--                with new mini-WR firmware
-- 24/11/2020 -- change receiving data buffer to 512 bytes; add uart interface
--               with mini-WR
--========================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;
use work.lite_bus_pack.all;
use work.TTIM_pack.all;
entity wr_interface2 is
    Port ( 
    sys_clk_i : in STD_LOGIC;
    sys_clkg : in std_logic;
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
    end_of_update : out std_logic;
    uart_tx : inout std_logic;
    uart_rx : in std_logic;
    PPS_IN_P : in std_logic;
    PPS_IN_N : in std_logic;
    pps_o : out std_logic;
    pps_original : out std_logic;
    timestamp_o : out std_logic_vector(67 downto 0);
    timestamp_48b_o : out std_logic_vector(47 downto 0)
    --debug_fsm : out std_logic_vector(3 downto 0)
    );
end wr_interface2;

 architecture Behavioral of wr_interface2 is
    constant st0_idle : std_logic_vector(3 downto 0) := x"0";
    constant st0_get_port : std_logic_vector(3 downto 0) := x"1";
    constant st1_get_data : std_logic_vector(3 downto 0) := x"2";
    constant st2_assmble_data : std_logic_vector(3 downto 0) := x"3";
    constant st3_wait_respond : std_logic_vector(3 downto 0) := x"4";
    constant st3_uart_fifo : std_logic_vector(3 downto 0) := x"5";
    constant st4_respond : std_logic_vector(3 downto 0) := x"6";
    constant st5_CRC_error : std_logic_vector(3 downto 0) := x"7";
    constant st5_addr_error : std_logic_vector(3 downto 0) := x"8";
    constant st5_timeout_error : std_logic_vector(3 downto 0) := x"9";
    constant st5_overflow_error : std_logic_vector(3 downto 0) := x"a";
    signal sel :integer;
    signal wr_rx_ctrl,wr_rx_ctrl_i : std_logic_vector(1 downto 0);
    signal wr_rx_data,wr_tx_data,wr_rx_data_i : std_logic_vector(7 downto 0);
    signal wr_tx_cts,wr_tx_vld : std_logic;
    signal data_send : std_logic_vector(159 downto 0);
    signal data_tx : std_logic_vector(79 downto 0);
    signal data_buf : t_array8(255 downto 0) := (others => (others => '0'));
    -- type t_state is (st0_idle,st0_get_port,st1_get_data,st2_assmble_data,
                    -- st3_wait_respond,st3_uart_fifo,st4_respond,st5_CRC_error,st5_addr_error,
                    -- st5_timeout_error,st5_overflow_error);
    signal state : std_logic_vector(3 downto 0);
    signal ack,data_valid,pps_i,timer_valid : std_logic;
    signal debug_fsm : std_logic_vector(3 downto 0);
    signal timer_utc : std_logic_vector(39 downto 0);
    signal timer_8ns : std_logic_vector(27 downto 0);
    signal timer_8ns_u : unsigned(47 downto 0);
    signal timer_utc_u : unsigned(47 downto 0);
    signal timer_total : unsigned(95 downto 0);
    signal pack_probe,tie_to_vcc : std_logic;
    signal uart_received,uart_sent,uart_sent_r,uart_tx_t,start_tx : std_logic;
    signal byte_rx,byte_tx : std_logic_vector(7 downto 0);
    signal baud_div : std_logic_vector(31 downto 0);
    signal uart_fifo_rd_data,uart_fifo_wr_data,uart_fifo_wr_data_r : std_logic_vector(7 downto 0);
    signal uart_fifo_rd_en,uart_fifo_wr_en,uart_fifo_wr_en_r,uart_fifo_valid : std_logic;
    signal st_uart : std_logic_vector(3 downto 0);
    signal len_std : std_logic_vector(9 downto 0);
    signal len_u : unsigned(9 downto 0);
    signal len : integer range 0 to 256;
    
begin
tie_to_vcc <= '1';
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
    if rising_edge(sys_clk_i) then
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
variable cnt : integer range 0 to 31;
variable s : integer range 0 to 512;
-- variable len : integer range 0 to 512;
variable time_out_cnt : integer range 0 to 65535;
begin
    if reset_i = '1' then
        state <= st0_idle;
        data_buf <= (others => (others => '0'));
    elsif rising_edge(sys_clk_i) then
        case state is
            when st0_idle =>
                data_buf <= (others => (others => '0'));
                data_valid <= '0';
                wr_tx_vld <= '0';
                update_data_valid <= '0';
                data_send <= (others => '0');
                uart_fifo_wr_en_r <= '0';
                cnt := 0;
                len_u <= (others => '0');
                --re_load <= '0';
                time_out_cnt := 0;
                --end_of_update <= '0';
                if wr_rx_ctrl_i = "01" then
                    if wr_rx_data_i = x"AB" then
                        state <= st0_get_port;
                        --len <= 1;
                        --data_buf(7 downto 0) <= wr_rx_data_i;
                    else
                        state <= st2_assmble_data;
                    end if;
                end if;
                debug_fsm <= x"0";
                pack_probe <= '0';
            when st0_get_port =>
                state <= st1_get_data;  -- x"C0"
            when st1_get_data =>
                data_buf(len) <= wr_rx_data_i;
                len_u <= len_u + 1;
                if wr_rx_ctrl_i = "10" then
                    state <= st2_assmble_data;
                elsif len = 256 then
                    state <= st5_overflow_error;
                elsif wr_rx_ctrl_i = "11" then
                    state <= st5_CRC_error;
                end if;
                debug_fsm <= x"1";
            when st2_assmble_data =>
                cnt := 4;
                if data_buf(0) = x"55" then -- update packets
                    state <= st4_respond;
                    if data_buf(1) = x"55" then
                        data_send(159 downto 128) <= x"ABC0" & update_fifo_empty & update_status & update_error;
                    elsif data_buf(1) = x"FF" then
                        update_data_valid <= '1';
                        for i in 0 to UPDATE_DATA_WIDTH/8-1 loop
                            update_data(i*8+7 downto i*8) <= data_buf(len-1-i);
                        end loop;
                        data_send(159 downto 128) <= x"ABC00000";
                        cnt := 20;
                    else
                        update_control <= data_buf(1)(3 downto 0)&data_buf(2)&data_buf(3);
                        re_load <= data_buf(1)(4);
                        end_of_update <= data_buf(1)(5);
                        data_send(159 downto 128) <= x"ABC00000";
                    end if;
                elsif data_buf(0)(7 downto 4) = x"4" then -- LiteBus packets
                    data_valid <= '1';
                    state <= st3_wait_respond;
                elsif data_buf(0) = x"66" then -- uart packets
                    state <= st3_uart_fifo;
                    s := 1;
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
                        data_send(159 downto 80) <= data_tx;
                        state <= st4_respond;
                        time_out_cnt := 0;
                    end if;
                else
                    state <= st5_timeout_error;
                    time_out_cnt := 0;
                end if;
                cnt := 10;
                debug_fsm <= x"3";
            when st3_uart_fifo =>
                if s < len then
                    uart_fifo_wr_en_r <= '1';
                    uart_fifo_wr_data_r <= data_buf(s);
                    s := s + 1;
                else
                    uart_fifo_wr_en_r <= '0';
                    state <= st4_respond;
                    data_send(159 downto 128) <= x"ABC00000";
                end if;
                debug_fsm <= x"6";
            when st4_respond =>
                update_data_valid <= '0';
                if wr_tx_cts = '1' then
                    if cnt > 0 then
                        wr_tx_vld <= '1';
                        wr_tx_data <= data_send(159 downto 152);
                        data_send <= data_send(151 downto 0) & x"00";
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
                cnt := 4;
                pack_probe <= '1';
                data_send(159 downto 128) <= x"ABC00001";
                state <= st4_respond;
                debug_fsm <= x"5";
            when st5_addr_error =>
                cnt := 4;
                pack_probe <= '1';
                data_send(159 downto 128) <= x"ABC00002";
                state <= st4_respond;
                debug_fsm <= x"7";
            when st5_timeout_error =>
                cnt := 4;
                pack_probe <= '1';
                data_send(159 downto 128) <= x"ABC00003";
                state <= st4_respond;
                debug_fsm <= x"8";
            when st5_overflow_error =>
                cnt := 4;
                pack_probe <= '1';
                data_send(159 downto 128) <= x"ABC00004";
                state <= st4_respond;
                debug_fsm <= x"9";
            when others =>
                state <= st0_idle;
        end case;
    end if;
end process;
len_std <= std_logic_vector(len_u);
len <= to_integer(len_u);
process(sys_clk_i)
begin
    if rising_edge(sys_clk_i) then
        ack <= lite_bus_r(sel).ack;
    end if;
end process;
data_tx <= x"ABC0" & lite_bus_r(sel).head & lite_bus_r(sel).data;

process(data_buf)
begin
    sel <= f_lite_bus_addr_sel(data_buf(1));
end process;
Gen_slaves:for i in NSLV - 1 downto 0 generate
begin
    lite_bus_w(i).strobe <= '1' when sel = i and data_valid = '1' else '0';
    lite_bus_w(i).wr_rd <= data_buf(0)(0); --1 for write, 0 for read
    lite_bus_w(i).data <= data_buf(2)&data_buf(3)&data_buf(4)&data_buf(5)&data_buf(6)&data_buf(7);
    lite_bus_w(i).head <= data_buf(0)(7 downto 1);
    lite_bus_w(i).addr <= data_buf(1);
end generate;
-- process(sys_clk_i)
-- begin
    -- if rising_edge(sys_clk_i) then
        -- uart_fifo_wr_data <= uart_fifo_wr_data_r;
        -- uart_fifo_wr_en <= uart_fifo_wr_en_r;
    -- end if;
-- end process;
Inst_uart_fifo:entity work.uart_fifo
    port map(
    wr_clk => sys_clk_i,
    rst => '0',
    rd_clk => sys_clk_i,
    din => uart_fifo_wr_data_r,
    wr_en => uart_fifo_wr_en_r,
    rd_en => uart_fifo_rd_en,
    dout => uart_fifo_rd_data,
    valid => uart_fifo_valid
    );
Inst_uart:entity work.uart_communication_blocks
    port map(
    rst => reset_i,
    clk => sys_clk_i,
    cycle_wait_baud => x"0000043D",
    byte_tx => byte_tx,
    byte_rx => byte_rx,
    data_sent_tx => uart_sent,
    data_received_rx => uart_received,
    serial_out => uart_tx_t,
    serial_in => uart_rx,
    start_tx => start_tx
    );
    Inst_iobuf: IOBUF
    port map(
    O => open,
    IO => uart_tx,
    I => '0',
    T => uart_tx_t
    );
P_uart:process(sys_clk_i)
variable wait_cnt : integer range 0 to 4095;
variable rx_cnt : integer range 0 to 7;
begin
    if reset_i = '1' then
        st_uart <= x"0";
        start_tx <= '0';
        uart_fifo_rd_en <= '0';
    elsif rising_edge(sys_clk_i) then
        uart_sent_r <= uart_sent;
        case st_uart is
            when x"0" =>
                uart_fifo_rd_en <= '0';
                start_tx <= '0';
                rx_cnt := 0;
                if uart_fifo_valid = '1' then
                    byte_tx <= uart_fifo_rd_data;
                    st_uart <= x"1";
                end if;
            when x"1" =>
                start_tx <= '1';
                uart_fifo_rd_en <= '1';
                st_uart <= x"2";
            when x"2" =>
                uart_fifo_rd_en <= '0';
                if uart_sent = '1' and uart_sent_r = '0' then
                    if byte_tx = x"0D" then  -- "\r", end of command
                        st_uart <= x"3";
                    else
                        st_uart <= x"4";
                        rx_cnt := 0;
                    end if;
                end if;
                wait_cnt := 0;
            when x"3" => 
                wait_cnt := wait_cnt + 1;
                start_tx <= '0';
                if wait_cnt = 4095 then
                    st_uart <= x"0";
                end if;
            when x"4" =>
                if uart_received = '1' then
                    rx_cnt := rx_cnt + 1;
                    if byte_rx = byte_tx or rx_cnt > 3 then
                        st_uart <= x"3";
                    end if;
                end if;
            when others =>
                st_uart <= x"0";
        end case;
    end if;
end process;
i_ila:entity work.ila_1
    port map(
    clk => sys_clk_i,
    probe0 => wr_rx_ctrl_i,
    probe1 => wr_rx_data_i,
    probe2(0) => wr_tx_cts,
    probe3 => wr_tx_data,
    probe4(0) => wr_tx_vld,
    probe5 => data_buf(1),
    probe6 => data_buf(2),
    probe7 => data_buf(3),
    probe8(0) => pack_probe,
    probe9 => data_buf(4),
    probe10 => len_std,
    probe11 => state
    );
end Behavioral;
