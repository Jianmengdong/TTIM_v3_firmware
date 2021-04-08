----------------------------------------------------------------------------------
-- Company: Tsinghua
-- Engineer: Jianmeng Dong
-- 
-- Create Date: 2020/03/05 09:16:12
-- Design Name: 
-- Module Name: TTIM_v3_top - Behavioral
-- Project Name: 
-- Target Devices: XC7K325T-2FFG900
-- Tool Versions: 
-- Description: 
-- Top file of the TTIM_v3
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;
use work.lite_bus_pack.all;
use work.TTIM_pack.all;

entity TTIM_v3_top is
    Port ( 
    -- clock ports
    local_clk_p : in STD_LOGIC; --local 125M oscillator
    local_clk_n : in STD_LOGIC;
    wr_clk_p : in std_logic; --WR clock
    wr_clk_n : in std_logic;
    -- trigger link
    trigger_link_tx_p : out std_logic; --trigger link with RMU
    trigger_link_tx_n : out std_logic;
    trigger_link_rx_p : in std_logic;
    trigger_link_rx_n : in std_logic;
    -- mm_trigger_link_tx_p : out std_logic; -- trigger link with MM-trigger system
    -- mm_trigger_link_tx_n : out std_logic;
    -- mm_trigger_link_rx_p : in std_logic;
    -- mm_trigger_link_rx_n : in std_logic;
    -- -- wr link (may not use)
    -- wr_link_tx_p : out std_logic; -- WR implemented with K7, need further development
    -- wr_link_tx_n : out std_logic;
    -- wr_link_rx_p : in std_logic;
    -- wr_link_rx_n : in std_logic;
    -- mini-WR interface
    PDATA_RX : in std_logic_vector(9 downto 0); -- parallel interface with mini-WR
    PDATA_TX : inout std_logic_vector(9 downto 0);
    PPS_IN_P : in std_logic; --PPS from mini-WR
    PPS_IN_N : in std_logic;
    wr_uart_tx : inout std_logic; --uart port
    wr_uart_rx : in std_logic;
    wr_locked : in std_logic;
    wr_reset : out std_logic;
    -- SPI interface
    SPI_CSB     : out std_logic;
    SPI_IO0         : inout std_logic;
    SPI_IO1         : inout std_logic;
    SPI_IO2         : inout std_logic; -- SPI flash write protect
    SPI_IO3         : inout std_logic;
    -- I2C interface
    SCL : out std_logic;
    SDA : inout std_logic;
    -- XADC port
    vp_in : in std_logic;
    vn_in : in std_logic;
    -- sync links with GCU
    BEC2GCU_1_P : out std_logic_vector(48 downto 1); --clock to GCU
    BEC2GCU_1_N : out std_logic_vector(48 downto 1);
    BEC2GCU_2_P : out std_logic_vector(48 downto 1); --trigger + SC to GCU
    BEC2GCU_2_N : out std_logic_vector(48 downto 1);
    GCU2BEC_1_P : in std_logic_vector(48 downto 1); --nhit/SC from GCU
    GCU2BEC_1_N : in std_logic_vector(48 downto 1);
    GCU2BEC_2_P : in std_logic_vector(48 downto 1); --SC/nhit from GCU
    GCU2BEC_2_N : in std_logic_vector(48 downto 1);
    -- test ports
    SMA : inout std_logic_vector(1 downto 0);
    LED : out std_logic_vector(2 downto 1);
    test_pin : inout std_logic_vector(3 downto 0)
    );
end TTIM_v3_top;

architecture Behavioral of TTIM_v3_top is

    constant hw_version : std_logic_vector(15 downto 0) := x"0300"; --major[7:4] minor[3:0]
    constant fw_version : std_logic_vector(15 downto 0) := x"FFFF"; --major[7:4] minor[3:0]
                                                                    --x"FFFF" for golden image
    
    signal pps_i : std_logic;
    signal local_clk_i,local_clk_125M_i,local_clk_62M5_i,local_clk_200M_i,local_clk_lock_i : std_logic;
    signal sys_clk_i,sys_clk_125M_i,sys_clk_62M5_i,sys_clk_200M_i,sys_clk_lock_i : std_logic;
    signal lite_bus_w : t_lite_wbus_arry(NSLV - 1 downto 0);
    signal lite_bus_r : t_lite_rbus_arry(NSLV - 1 downto 0);
    signal register_array,register_array_r : t_array48(NSLV - 1 downto 0);
    signal clko_i,gcu2bec_1_i,bec2gcu_2_i,gcu2bec_2_i : std_logic_vector(48 downto 1);
    signal timestamp_48b : std_logic_vector(47 downto 0);
    signal timestamp_i : std_logic_vector(67 downto 0);
    signal update_data : std_logic_vector(UPDATE_DATA_WIDTH - 1 downto 0);
    signal update_control : std_logic_vector(19 downto 0);
    signal update_data_valid,update_fifo_empty,update_wr_en : std_logic;
    signal update_error : std_logic_vector(5 downto 0);
    signal update_status : std_logic_vector(8 downto 0);
    signal en_trig_i : std_logic_vector(4 downto 0);
    signal trig_i : std_logic_vector(15 downto 0);
    signal nhit_i,threshold_i : std_logic_vector(7 downto 0);
    signal test_mode_i,pair_swap,gcu2bec_1,gcu2bec_2 : std_logic_vector(47 downto 0);
    signal reset_err,l1a_i,inj_err,ttctx_ready : std_logic;
    signal hit_i : t_array2(47 downto 0);
    signal ch_mask_i,ch_ready_i,tx2_en,tx1_sel,inv_o_1 : std_logic_vector(47 downto 0);
    signal ch_sel_i : std_logic_vector(5 downto 0);
    signal tap_cnt_i :std_logic_vector(6 downto 0);
    signal ld_i,ext_trig_i :std_logic_vector(1 downto 0);
    signal error_time1_o,error_time2_o : std_logic_vector(47 downto 0);
    signal error_counter1_o,error_counter2_o,s_1588ptp_period,period_i : std_logic_vector(31 downto 0);
    signal use_vio : std_logic;
    signal v_test_mode,v_ch_mask,v_tx2_en,v_tx1_sel,v_inv_o_1 : std_logic_vector(47 downto 0);
    signal v_tap_cnt : std_logic_vector(6 downto 0);
    signal v_ch_sel : std_logic_vector(5 downto 0);
    signal v_ld : std_logic_vector(1 downto 0);
    signal v_reset_err,v_inj_err,v_1588_enable : std_logic;
    signal v_pair_swap : std_logic_vector(47 downto 0);
    signal v_en_trig : std_logic_vector(4 downto 0);
    signal v_chb_req,v_idle,v_l1a_go_prbs,v_tap_cal_enable,v_l1a_cal_enable,v_manual_trig,v_fake_hit : std_logic;
    signal v_hit_toggle,s_hit_toggle : std_logic_vector(47 downto 0);
    signal v_threshold,trigger_type : std_logic_vector(7 downto 0);
    signal v_period : std_logic_vector(31 downto 0);
    signal ch_sel : integer range 0 to 47;
    signal sma_sel,v_sma_sel,pps_r : std_logic;
    signal s_chb_grant1,s_chb_req1,s_1588ptp_enable,s_tap_calib_enable : std_logic;
    signal s_tap_rst,s_tap_incr,s_l1a_tap_calib_enable,s_l1a_go_prbs,ttc_rst_error,ttc_idle : std_logic;
    signal rx_aligned,manual_trig,trig_req,fake_hit : std_logic;
    signal loss_counter,s_eye_v,s_l1a_eye_v,s_tap_error_count: std_logic_vector(31 downto 0);
    signal s_1bit_err_count,s_2bit_err_count,s_comm_err_count,trig_error_cnt : std_logic_vector(31 downto 0);
    signal monitor_fsm : std_logic_vector(3 downto 0);
    signal temp_reg1,temp_reg2,temp_reg3 : std_logic_vector(8 downto 0);
    signal sense_reg,vin_reg,adin_reg,temp_die_reg,vccint_reg,vccaux_reg : std_logic_vector(11 downto 0);
    signal hit_debug,l1a_debug : std_logic_vector(47 downto 0);
    signal trig_window_i,v_trig_window : std_logic_vector(3 downto 0);
    signal trig_rate_s,trig_rate_t : std_logic_vector(23 downto 0);
    signal sys_clk_32M_i,re_load,end_of_update,loop_test : std_logic;
    signal auto_trigger : std_logic;
    signal tx1_t, tx2_t,sys_clkg : std_logic;
    signal reset_sync_links : std_logic_vector(47 downto 0);
    signal reset_trig_link,start_wr_done,manual_auto_trig : std_logic;
    signal led_i : std_logic_vector(1 downto 0);
    signal startup_status : std_logic_vector(2 downto 0);
    signal retry_cnt : std_logic_vector(3 downto 0);
    signal reset_trig,trig_loop_test,fake_hit_max,reset_wr_clk_o : std_logic;
begin
--===========================================--
--     clock generation
Inst_clk_time: entity work.clk_time
    port map(
    local_clk_p => local_clk_p,
    local_clk_n => local_clk_n,
    local_clk_o => local_clk_i,  --IBUFDS_GTE2, for MGT
    wr_clk_p => wr_clk_p,
    wr_clk_n => wr_clk_n,
    sys_clk_o => sys_clk_i,  --IBUFDS_GTE2, for MGT
    sys_clkg_o => sys_clkg,
    pps_i => pps_i,
    local_clk_62M5_o => local_clk_62M5_i,
    local_clk_125M_o => local_clk_125M_i,
    local_clk_200M_o => local_clk_200M_i,
    local_clk_lock_o => local_clk_lock_i,
    sys_clk_32M_o => sys_clk_32M_i,
    sys_clk_62M5_o => sys_clk_62M5_i,
    sys_clk_125M_o => sys_clk_125M_i,
    sys_clk_200M_o => sys_clk_200M_i,
    sys_clk_lock_o => sys_clk_lock_i,
    start_wr_done => start_wr_done,
    reset_wr_clk_o => reset_wr_clk_o,
    retry_cnt => retry_cnt,
    led_o => led_i
    );
    LED(1) <= led_i(1) when startup_status(2) = '1' else '0';
--========================================--
--  interface with mini-WR
Inst_wr_interface:entity work.wr_interface2
    port map(
    sys_clk_i => sys_clk_125M_i,
    sys_clkg => sys_clkg,
    reset_i => not sys_clk_lock_i,
    PPS_IN_P => PPS_IN_P,
    PPS_IN_N => PPS_IN_N,
    PDATA_RX => PDATA_RX,
    PDATA_TX => PDATA_TX,
    wr_locked => wr_locked,
    lite_bus_w => lite_bus_w,
    lite_bus_r => lite_bus_r,
    update_data => update_data,
    update_data_valid => update_wr_en,
    update_fifo_empty => update_fifo_empty,
    update_error => update_error,
    update_status => update_status,
    update_control => update_control,
    end_of_update => end_of_update,
    re_load => re_load,
    uart_tx => wr_uart_tx,
    uart_rx => wr_uart_rx,
    pps_o => pps_i,
    pps_original => open,
    timestamp_o => timestamp_i,
    timestamp_48b_o => timestamp_48b
    );
    -- wr_reset <= '1';
--=======================================--
--  local control_registers
Inst_remote_update:entity work.remote_update_top
    port map(
    clk_i => sys_clk_32M_i,
    clk_x2_i => sys_clk_125M_i,
    -- SPI interface
    outSpiCsB       => SPI_CSB,
    outSpiMosi_IO0  => SPI_IO0,
    inSpiMiso_IO1   => SPI_IO1,
    outSpiWpB_IO2   => SPI_IO2,
    outSpiHoldB_IO3 => SPI_IO3,
    update_data => update_data,
    update_data_valid => update_wr_en,
    update_fifo_empty => update_fifo_empty,
    outSFPStatus    => update_status,
    outSFPError     => update_error,
    inUpdateControl => update_control,
    end_of_update => end_of_update,
    re_load => re_load
    );
--=======================================--
--  local control_registers
Inst_regs:entity work.control_registers
    port map(
    sys_clk_i => sys_clk_125M_i,
    reset_i => not sys_clk_lock_i,
    lite_bus_w => lite_bus_w,
    lite_bus_r => lite_bus_r,
    register_o => register_array,
    register_i => register_array_r
    );

--========================================--
--  trigger generator
Inst_trig_gen:entity work.trigger_gen
    port map(
    clk_i => sys_clk_62M5_i,
    reset_i => not ttctx_ready,
    reset_event_cnt_i => '0',
    pps_i => pps_i,
    trig_rate_o => trig_rate_t,
    en_trig_i => en_trig_i,
    ext_trig_i => ext_trig_i,
    l1a_o => l1a_i,
    trig_type_o => trigger_type,
    trig_i => trig_i,
    trig_window_i => trig_window_i,
    global_time_i => timestamp_i,
    period_i => period_i,
    threshold_i => threshold_i,
    hit_i => hit_i,
    nhit_o => nhit_i,
    auto_trigger => auto_trigger,
    fake_hit => fake_hit,
    fake_hit_max => fake_hit_max,
    led => LED(2)
    --trig_info_o => open
    );
    ext_trig_i(0) <= SMA(1);
    ext_trig_i(1) <= manual_trig;
--========================================--
--  trigger link with RMU
Inst_trig_link:entity work.trigger_link
    port map(
    SFP_RX_P => trigger_link_rx_p,
    SFP_RX_N => trigger_link_rx_n,
    SFP_TX_P => trigger_link_tx_p,
    SFP_TX_N => trigger_link_tx_n,
    refclk_i => sys_clk_i,
    trig_o => trig_i,
    nhit_i => nhit_i,
    clk_i => sys_clk_62M5_i,
    reset_i => reset_trig_link or reset_trig,
    loop_test => trig_loop_test,
    reset_err => reset_err,
    prbs_error => trig_error_cnt,
    rx_aligned => rx_aligned
    );
--===========================================--
--     sync link to GCU
Inst_sync_link:entity work.sync_links
    port map(
    BEC2GCU_1_P => BEC2GCU_1_P,
    BEC2GCU_1_N => BEC2GCU_1_N,
    BEC2GCU_2_P => BEC2GCU_2_P,
    BEC2GCU_2_N => BEC2GCU_2_N,
    reset_sync_links => reset_sync_links,
    GCU2BEC_1_P => GCU2BEC_1_P,
    GCU2BEC_1_N => GCU2BEC_1_N,
    GCU2BEC_2_P => GCU2BEC_2_P,
    GCU2BEC_2_N => GCU2BEC_2_N,
    gcu2bec_1_o => gcu2bec_1,
    gcu2bec_2_o => gcu2bec_2,
    clk_i       => sys_clk_62M5_i,
    clk_x2_i    => sys_clk_125M_i,
    clk_200     => sys_clk_200M_i,
    sys_clk_lock => sys_clk_lock_i,
    test_mode_i => test_mode_i,
    reset_i     => reset_err,
    loop_test => loop_test,
    pps_i => pps_i,
    trig_rate_o => trig_rate_s,
    l1a_i       => l1a_i,
    trigger_type => trigger_type,
    auto_trigger => auto_trigger or manual_auto_trig,
    nhit_gcu_o  => hit_i,
    timestamp_i => timestamp_48b,
    loss_counter_o => loss_counter,
    ch_mask_i   => ch_mask_i,
    ch_ready_o  => ch_ready_i,
    tx2_en      => tx2_en,
    tx1_sel     => tx1_sel,
    inv_o_1     => inv_o_1,
    ch_sel_i    => ch_sel_i,
    tap_cnt_i   => tap_cnt_i,
    s_chb_grant1 => s_chb_grant1,
    s_chb_req1 => s_chb_req1,
    ttc_idle => ttc_idle,
    ttc_rst_error => ttc_rst_error,
    s_1588ptp_enable => s_1588ptp_enable,
    s_tap_calib_enable => s_tap_calib_enable,
    s_tap_rst => s_tap_rst,
    s_tap_incr => s_tap_incr,
    s_l1a_tap_calib_enable => s_l1a_tap_calib_enable,
    s_l1a_go_prbs => s_l1a_go_prbs,
    s_hit_toggle => s_hit_toggle,
    ld_i        => ld_i,
    inj_err     => inj_err,
    pair_swap   => pair_swap,
    ttctx_ready => ttctx_ready,
    error_time1_o    => error_time1_o,
    error_time2_o    => error_time2_o,
    error_counter1_o => error_counter1_o,
    error_counter2_o => error_counter2_o,
    sbit_err_count    => s_1bit_err_count,
    dbit_err_count    => s_2bit_err_count,
    comm_err_count    => s_comm_err_count,
    eye_v => s_eye_v,
    l1a_eye_v => s_l1a_eye_v,
    s_tap_error_count => s_tap_error_count
    );
    ch_sel <= to_integer(unsigned(ch_sel_i));
--=================================--
--  test signals
Inst_monitor: entity work.monitor
    port map(
    clk_i => sys_clk_62M5_i,
    rst_i => reset_err,
    read_reg => timestamp_i(29),
    SCL => SCL,
    SDA => SDA,
    vp_in => vp_in,
    vn_in => vn_in,
    temp_reg1 => temp_reg1,
    temp_reg2 => temp_reg2,
    temp_reg3 => temp_reg3,
    sense_reg => sense_reg,
    vin_reg => vin_reg,
    adin_reg => adin_reg,
    temp_die_reg => temp_die_reg,
    vccint_reg => vccint_reg,
    vccaux_reg => vccaux_reg,
    fsm_o => monitor_fsm
    );
Inst_startup: entity work.startup
    port map(
    clk_in => local_clk_125M_i,
    local_clk_lock => local_clk_lock_i,
    start_wr_done => start_wr_done,
    reset_sync_links => reset_sync_links,
    reset_trig_link => reset_trig_link,
    startup_status => startup_status
    );
    --LED(2) <= startup_status(2);
    -- register map----
    
    test_mode_i <= register_array(0) when use_vio = '0' else v_test_mode;
    ch_mask_i <= register_array(1) when use_vio = '0' else v_ch_mask;
    tx2_en <= register_array(2) when use_vio = '0' else v_tx2_en;
    tx1_sel <= register_array(3) when use_vio = '0' else v_tx1_sel;
    inv_o_1 <= register_array(4) when use_vio = '0' else v_inv_o_1;
    tap_cnt_i <= register_array(5)(6 downto 0) when use_vio = '0' else v_tap_cnt;
    ch_sel_i <= register_array(6)(5 downto 0) when use_vio = '0' else v_ch_sel;
    ld_i <= register_array(7)(1 downto 0) when use_vio = '0' else v_ld;
    reset_err <= register_array(8)(0) when use_vio = '0' else v_reset_err;
    inj_err <= register_array(8)(1) when use_vio = '0' else v_inj_err;
    reset_trig <= register_array(8)(2);-- when use_vio = '0' else v_inj_err;
    s_1588ptp_enable <= register_array(8)(3) when use_vio = '0' else v_1588_enable;
    pair_swap <= register_array(9) when use_vio = '0' else v_pair_swap;
    en_trig_i <= register_array(10)(4 downto 0) when use_vio = '0' else v_en_trig;
    s_chb_req1 <= register_array(11)(0) when use_vio = '0' else v_chb_req;
    ttc_idle <= register_array(11)(1) when use_vio = '0' else v_idle;
    ttc_rst_error <= register_array(11)(2);
    s_tap_rst <= register_array(12)(0);
    s_tap_incr <= register_array(12)(1);
    s_l1a_go_prbs <= register_array(13)(0) when use_vio = '0' else v_l1a_go_prbs;
    s_tap_calib_enable <= register_array(14)(0) when use_vio = '0' else v_tap_cal_enable;
    s_l1a_tap_calib_enable <= register_array(14)(1) when use_vio = '0' else v_l1a_cal_enable;
    manual_trig <= register_array(15)(0) when use_vio = '0' else v_manual_trig;
    manual_auto_trig <= register_array(15)(1);
    sma_sel <= register_array(16)(0) when use_vio = '0' else v_sma_sel;
    s_hit_toggle <= register_array(17) when use_vio = '0' else v_hit_toggle;
    fake_hit <= register_array(18)(0) when use_vio = '0' else v_fake_hit;
    loop_test <= register_array(19)(0);-- when use_vio = '0' else v_fake_hit;
    trig_loop_test <= register_array(19)(1);-- when use_vio = '0' else v_fake_hit;
    threshold_i <= register_array(24)(7 downto 0) when use_vio = '0' else v_threshold;
    period_i <= register_array(25)(31 downto 0) when use_vio = '0' else v_period;
    trig_window_i <= register_array(30)(3 downto 0) when use_vio = '0' else v_trig_window;
    register_array_r(0) <= test_mode_i;
    register_array_r(1) <= ch_mask_i;
    register_array_r(2) <= tx2_en;
    register_array_r(3) <= tx1_sel;
    register_array_r(4) <= inv_o_1;
    register_array_r(5) <= x"0000000000"&"0"&tap_cnt_i;
    register_array_r(6) <= x"0000000000"&"00"&ch_sel_i;
    register_array_r(7) <= x"0000" & trig_error_cnt;
    register_array_r(8) <= x"00000000000"&"0"&s_1588ptp_enable&inj_err&reset_err;
    register_array_r(9) <= pair_swap;
    register_array_r(10) <= x"0000000000"&"000"&en_trig_i;
    register_array_r(11) <= hw_version&fw_version&x"000"&s_chb_grant1&rx_aligned&ttctx_ready&sys_clk_lock_i;
    register_array_r(12) <= ch_ready_i;
    register_array_r(13) <= error_time1_o;
    register_array_r(14) <= error_time2_o;
    register_array_r(15) <= x"0000"&error_counter1_o;
    register_array_r(16) <= x"0000"&error_counter2_o;
    register_array_r(17) <= s_hit_toggle;
    register_array_r(18) <= x"0000"&s_1bit_err_count;
    register_array_r(19) <= x"0000"&s_2bit_err_count;
    register_array_r(20) <= x"0000"&s_comm_err_count;
    register_array_r(21) <= x"0000"&s_eye_v;
    register_array_r(22) <= x"0000"&s_l1a_eye_v;
    register_array_r(23) <= x"0000"&s_tap_error_count;
    register_array_r(24) <= x"0000000000"&threshold_i;
    register_array_r(25) <= x"0000"&period_i;
    register_array_r(26) <= x"00000"&'0'&temp_reg1&temp_reg2&temp_reg3;
    register_array_r(27) <= x"000"&sense_reg&vin_reg&adin_reg;
    register_array_r(28) <= hit_debug;
    register_array_r(29) <= l1a_debug;
    register_array_r(30) <= x"00000000000"&trig_window_i;
    register_array_r(31) <= x"000"&temp_die_reg&vccint_reg&vccaux_reg;
    register_array_r(32) <= trig_rate_s&trig_rate_t;
    register_array_r(33) <= x"0000"&loss_counter;
    process(sys_clk_62M5_i)
    begin
    if rising_edge(sys_clk_62M5_i) then
        hit_debug <= hit_debug(39 downto 0) & nhit_i;
        l1a_debug <= l1a_debug(46 downto 0) & l1a_i;
    end if;
    end process;
    Inst_vio:entity work.vio_0
    port map(
    clk => sys_clk_125M_i,
    probe_in0 => test_mode_i,
    probe_in1(0) => s_1588ptp_enable,
    probe_in2(0) => s_tap_calib_enable,
    probe_in3(0) => s_tap_rst,
    probe_in4(0) => s_tap_incr,
    probe_in5(0) => s_chb_req1,
    probe_in6(0) => s_chb_grant1,
    probe_out0(0) => use_vio,
    probe_out1 => v_test_mode,
    probe_out2 => v_ch_mask,
    probe_out3 => v_tx2_en,
    probe_out4 => v_tx1_sel,
    probe_out5 => v_inv_o_1,
    probe_out6 => v_tap_cnt,
    probe_out7 => v_ch_sel,
    probe_out8 => v_ld,
    probe_out9(0) => v_reset_err,
    probe_out10(0) => v_inj_err,
    probe_out11(0) => v_1588_enable,
    probe_out12 => v_pair_swap,
    probe_out13 => v_en_trig,
    probe_out14(0) => v_chb_req,
    probe_out15(0) => v_idle,
    probe_out16(0) => v_l1a_go_prbs,
    probe_out17(0) => v_tap_cal_enable,
    probe_out18(0) => v_l1a_cal_enable,
    probe_out19(0) => v_manual_trig,
    probe_out20 => v_hit_toggle,
    probe_out21(0) => v_fake_hit,
    probe_out22 => v_threshold,
    probe_out23 => v_period,
    probe_out24(0) => v_sma_sel,
    probe_out25 => v_trig_window
    );
    wr_reset <= '1';

    Inst_ila:entity work.ila_0
    port map(
    clk => sys_clk_125M_i,
    probe0 => trig_error_cnt,
    probe1 => timestamp_48b,
    probe2 => error_time1_o,
    probe3 => error_time2_o,
    probe4 => error_counter1_o,
    probe5 => error_counter2_o,
    probe6 => s_1bit_err_count,
    probe7 => s_2bit_err_count,
    probe8 => s_comm_err_count,
    probe9 => s_eye_v,
    probe10 => s_l1a_eye_v,
    probe11 => s_tap_error_count,
    probe12(0) => sys_clk_lock_i,
    probe13(0) => wr_locked,
    probe14(0) => l1a_i,
    probe15 => nhit_i
    --probe16 => monitor_fsm
    );
--=================================--
--  test signals
-- SMA(0) <= gcu2bec_1(ch_sel) when sma_sel = '0' else gcu2bec_2(ch_sel);
-- SMA(1) <= 'Z';
--SMA(0) <= trig_i(15);
SMA(0) <= sys_clkg;
SMA(1) <= sys_clk_lock_i;
test_pin <= "ZZZZ";
end Behavioral;
