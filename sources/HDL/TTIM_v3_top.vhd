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
    generic (g_cs_wonly_deep : natural:= 27; -- configuration space number of write only registers;
           g_cs_ronly_deep : natural:= 40;  -- configuration space number of read only registers;
	        g_NSLV          : positive := 5
           ); 
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
    -- wr link (may not use)
    wr_link_tx_p : out std_logic; -- WR implemented with K7, need further development
    wr_link_tx_n : out std_logic;
    wr_link_rx_p : in std_logic;
    wr_link_rx_n : in std_logic;
    -- mini-WR interface
    PDATA_RX : in std_logic_vector(9 downto 0); -- parallel interface with mini-WR
    PDATA_TX : inout std_logic_vector(9 downto 0);
    PPS_IN_P : in std_logic; --PPS from mini-WR
    PPS_IN_N : in std_logic;
    wr_uart_tx : out std_logic; --uart port
    wr_uart_rx : out std_logic;
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
    constant fw_version : std_logic_vector(15 downto 0) := x"0400"; --major[7:4] minor[3:0]
    
    signal pps_i : std_logic;
    signal local_clk_i,local_clk_125M_i,local_clk_62M5_i,local_clk_200M_i,local_clk_lock_i : std_logic;
    signal sys_clk_i,sys_clk_125M_i,sys_clk_62M5_i,sys_clk_200M_i,sys_clk_lock_i : std_logic;
    signal lite_bus_w : t_lite_wbus_arry(NSLV - 1 downto 0);
    signal lite_bus_r : t_lite_rbus_arry(NSLV - 1 downto 0);
    signal register_array,register_array_r : t_array48(NSLV - 1 downto 0);
    signal clko_i,gcu2bec_1_i,bec2gcu_2_i,gcu2bec_2_i : std_logic_vector(48 downto 1);
    signal timestamp_48b : std_logic_vector(47 downto 0);
    signal timestamp_i : std_logic_vector(67 downto 0);
    signal update_data : std_logic_vector(127 downto 0);
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
    signal v_threshold : std_logic_vector(7 downto 0);
    signal v_period : std_logic_vector(31 downto 0);
    signal ch_sel : integer range 0 to 47;
    signal sma_sel,v_sma_sel,pps_r : std_logic;
    signal s_chb_grant1,s_chb_req1,s_1588ptp_enable,s_tap_calib_enable : std_logic;
    signal s_tap_rst,s_tap_incr,s_l1a_tap_calib_enable,s_l1a_go_prbs,ttc_rst_error,ttc_idle : std_logic;
    signal rx_aligned,manual_trig,trig_req,fake_hit : std_logic;
    signal s_eye_v,s_l1a_eye_v,s_tap_error_count: std_logic_vector(31 downto 0);
    signal s_1bit_err_count,s_2bit_err_count,s_comm_err_count,s_l1a_err_count : std_logic_vector(31 downto 0);
    signal cs_data_o:  t_array32(g_cs_wonly_deep-1 downto 0);
    signal cs_data_i: t_array32(g_cs_ronly_deep-1 downto 0);
    signal trig_window_i,v_trig_window,monitor_fsm : std_logic_vector(3 downto 0);
    signal temp_reg1,temp_reg2,temp_reg3 : std_logic_vector(8 downto 0);
    signal sense_reg,vin_reg,adin_reg,temp_die_reg,vccint_reg,vccaux_reg : std_logic_vector(11 downto 0);
begin
--===========================================--
--     clock generation
Inst_clk_time: entity work.clk_time
    port map(
    local_clk_p => local_clk_p,
    local_clk_n => local_clk_n,
    local_clk_o => local_clk_i,  --IBUFDS_GTE2, for MGT
    --wr_clk_p => wr_clk_p,
    --wr_clk_n => wr_clk_n,
    sys_clk_i =>sys_clk_i,
    --sys_clk_o => sys_clk_i,  --IBUFDS_GTE2, for MGT
    pps_i => pps_i,
    local_clk_62M5_o => local_clk_62M5_i,
    local_clk_125M_o => local_clk_125M_i,
    local_clk_200M_o => local_clk_200M_i,
    local_clk_lock_o => local_clk_lock_i,
    sys_clk_62M5_o => sys_clk_62M5_i,
    sys_clk_125M_o => sys_clk_125M_i,
    sys_clk_200M_o => sys_clk_200M_i,
    sys_clk_lock_o => sys_clk_lock_i,
    led_o => LED
    );
--========================================--
--  interface with mini-WR
Inst_wr_interface:entity work.wr_interface
    port map(
    sys_clk_i => sys_clk_125M_i,
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
    pps_o => pps_i,
    pps_original => open,
    timestamp_o => timestamp_i,
    timestamp_48b_o => timestamp_48b
    );
    wr_reset <= '1';
--=======================================--
--  local control_registers
Inst_remote_update:entity work.remote_update_top
    port map(
    clk_i => sys_clk_62M5_i,
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
    inUpdateControl => update_control
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
    register_i => register_array
    );
    -- register map----
    test_mode_i <= cs_data_o(1)(15 downto 0)&cs_data_o(0) when use_vio = '0' else v_test_mode;
    -- test_mode_i <= register_array(0) when use_vio = '0' else v_test_mode;
    -- register_array_r(0) <= test_mode_i;
    ch_mask_i <= cs_data_o(3)(15 downto 0)&cs_data_o(2) when use_vio = '0' else v_ch_mask;
    -- ch_mask_i <= register_array(1) when use_vio = '0' else v_ch_mask;
    -- register_array_r(1) <= ch_mask_i;
    tx2_en <= cs_data_o(5)(15 downto 0)&cs_data_o(4) when use_vio = '0' else v_tx2_en;
    -- tx2_en <= register_array(2) when use_vio = '0' else v_tx2_en;
    -- register_array_r(2) <= tx2_en;
    tx1_sel <= cs_data_o(7)(15 downto 0)&cs_data_o(6) when use_vio = '0' else v_tx2_en;
    -- tx1_sel <= register_array(3) when use_vio = '0' else v_tx1_sel;
    -- register_array_r(3) <= tx1_sel;
    inv_o_1 <= cs_data_o(9)(15 downto 0)&cs_data_o(8) when use_vio = '0' else v_tx2_en;
    -- inv_o_1 <= register_array(4) when use_vio = '0' else v_inv_o_1;
    -- register_array_r(4) <= inv_o_1;
    tap_cnt_i <= cs_data_o(10)(6 downto 0) when use_vio = '0' else v_tap_cnt;
    -- tap_cnt_i <= register_array(5)(6 downto 0) when use_vio = '0' else v_tap_cnt;
    -- register_array_r(5) <= x"0000000000"&"0"&tap_cnt_i;
    ch_sel_i <= cs_data_o(11)(5 downto 0) when use_vio = '0' else v_ch_sel;
    -- ch_sel_i <= register_array(6)(5 downto 0) when use_vio = '0' else v_ch_sel;
    -- register_array_r(6) <= x"0000000000"&"00"&ch_sel_i;
    ld_i <= cs_data_o(12)(1 downto 0) when use_vio = '0' else v_ld;
    -- ld_i <= register_array(7)(1 downto 0) when use_vio = '0' else v_ld;
    -- register_array_r(7) <= x"00000000000"&"00"&ld_i;
    reset_err <= cs_data_o(12)(2) when use_vio = '0' else v_reset_err;
    -- reset_err <= register_array(8)(0) when use_vio = '0' else v_reset_err;
    inj_err <= cs_data_o(12)(3) when use_vio = '0' else v_inj_err;
    -- inj_err <= register_array(8)(1) when use_vio = '0' else v_inj_err;
    s_1588ptp_enable <= cs_data_o(13)(0) when use_vio = '0' else v_1588_enable;
    -- s_1588ptp_enable <= register_array(8)(3) when use_vio = '0' else v_1588_enable;
    -- register_array_r(8) <= x"00000000000"&"0"&s_1588ptp_enable&inj_err&reset_err;
    pair_swap <= cs_data_o(15)(15 downto 0)&cs_data_o(14) when use_vio = '0' else v_pair_swap;
    -- pair_swap <= register_array(9) when use_vio = '0' else v_pair_swap;
    -- register_array_r(9) <= pair_swap;
    en_trig_i <= cs_data_o(16)(4 downto 0) when use_vio = '0' else v_en_trig;
    -- en_trig_i <= register_array(10)(4 downto 0) when use_vio = '0' else v_en_trig;
    -- register_array_r(10) <= x"0000000000"&"000"&en_trig_i;
    s_chb_req1 <= cs_data_o(17)(0) when use_vio = '0' else v_chb_req;
    -- s_chb_req1 <= register_array(11)(0) when use_vio = '0' else v_chb_req;
    -- ttc_idle <= register_array(11)(1) when use_vio = '0' else v_idle;
    ttc_rst_error <= cs_data_o(17)(1);
    -- ttc_rst_error <= register_array(11)(2);
    s_tap_rst <= cs_data_o(18)(0);
    s_tap_incr <= cs_data_o(18)(1);
    -- s_tap_rst <= register_array(12)(0);
    -- s_tap_incr <= register_array(12)(1);
    s_l1a_go_prbs <= cs_data_o(19)(0) when use_vio = '0' else v_l1a_go_prbs;
    s_tap_calib_enable <= cs_data_o(19)(1) when use_vio = '0' else v_tap_cal_enable;
    s_l1a_tap_calib_enable <= cs_data_o(19)(2) when use_vio = '0' else v_l1a_cal_enable;
    manual_trig <= cs_data_o(19)(3) when use_vio = '0' else v_manual_trig;
    -- s_l1a_go_prbs <= register_array(13)(0) when use_vio = '0' else v_l1a_go_prbs;
    -- s_tap_calib_enable <= register_array(14)(0) when use_vio = '0' else v_tap_cal_enable;
    -- s_l1a_tap_calib_enable <= register_array(14)(1) when use_vio = '0' else v_l1a_cal_enable;
    -- manual_trig <= register_array(15)(0) when use_vio = '0' else v_manual_trig;
    sma_sel <= cs_data_o(20)(0) when use_vio = '0' else v_sma_sel;
    -- sma_sel <= register_array(16)(0) when use_vio = '0' else v_sma_sel;
    s_hit_toggle <= cs_data_o(22)(15 downto 0)&cs_data_o(21) when use_vio = '0' else v_hit_toggle;
    -- s_hit_toggle <= register_array(17) when use_vio = '0' else v_hit_toggle;
    fake_hit <= cs_data_o(23)(0) when use_vio = '0' else v_fake_hit;
    -- fake_hit <= register_array(18)(0) when use_vio = '0' else v_fake_hit;
    threshold_i <= cs_data_o(24)(7 downto 0) when use_vio = '0' else v_threshold;
    -- threshold_i <= register_array(24)(7 downto 0) when use_vio = '0' else v_threshold;
    period_i <= cs_data_o(25)(31 downto 0) when use_vio = '0' else v_period;
    trig_window_i <= cs_data_o(26)(3 downto 0) when use_vio = '0' else v_trig_window;
    cs_data_i(0) <= test_mode_i(31 downto 0);
    cs_data_i(1) <= x"0000"&test_mode_i(47 downto 32);
    cs_data_i(2) <= ch_mask_i(31 downto 0);
    cs_data_i(3) <= x"0000"&ch_mask_i(47 downto 32);
    cs_data_i(4) <= tx2_en(31 downto 0);
    cs_data_i(5) <= x"0000"&tx2_en(47 downto 32);
    cs_data_i(6) <= tx1_sel(31 downto 0);
    cs_data_i(7) <= x"0000"&tx1_sel(47 downto 32);
    cs_data_i(8) <= inv_o_1(31 downto 0);
    cs_data_i(9) <= x"0000"&inv_o_1(47 downto 32);
    cs_data_i(10) <= x"000000"&"0"&tap_cnt_i;
    cs_data_i(11) <= x"000000"&"00"&ch_sel_i;
    cs_data_i(12) <= x"000000"&"00"&ld_i;
    cs_data_i(13)(0) <= sys_clk_lock_i;
    cs_data_i(13)(1) <= ttctx_ready;
    cs_data_i(13)(2) <= rx_aligned;
    cs_data_i(13)(3) <= s_chb_grant1;
    cs_data_i(13)(4) <= sma_sel;
    cs_data_i(13)(5) <= fake_hit;
    cs_data_i(13)(6) <= s_1588ptp_enable;
    cs_data_i(13)(7) <= s_l1a_go_prbs;
    cs_data_i(13)(8) <= s_tap_calib_enable;
    cs_data_i(13)(9) <= s_l1a_tap_calib_enable;
    cs_data_i(14) <= pair_swap(31 downto 0);
    cs_data_i(15) <= x"0000"&pair_swap(47 downto 32);
    cs_data_i(16) <= x"000000"&"000"&en_trig_i;
    cs_data_i(17) <= x"0000000"&trig_window_i;
    cs_data_i(18) <= "00000"&temp_reg1&temp_reg2&temp_reg3;
    cs_data_i(19) <= x"000000"&threshold_i;
    cs_data_i(20) <= period_i;
    cs_data_i(21) <= hw_version&fw_version;
    cs_data_i(22) <= error_time1_o(31 downto 0);
    cs_data_i(23) <= x"0000"&error_time1_o(47 downto 32);
    cs_data_i(24) <= error_time2_o(31 downto 0);
    cs_data_i(25) <= x"0000"&error_time2_o(47 downto 32);
    cs_data_i(26) <= error_counter1_o;
    cs_data_i(27) <= error_counter2_o;
    cs_data_i(28) <= s_hit_toggle(31 downto 0);
    cs_data_i(29) <= x"0000"&s_hit_toggle(47 downto 32);
    cs_data_i(30) <= s_1bit_err_count;
    cs_data_i(31) <= s_2bit_err_count;
    cs_data_i(32) <= s_comm_err_count;
    cs_data_i(33) <= s_eye_v;
    cs_data_i(34) <= s_l1a_eye_v;
    cs_data_i(35) <= s_tap_error_count;
    cs_data_i(36) <= x"00"&sense_reg&vin_reg;
    cs_data_i(37) <= x"00"&temp_die_reg&adin_reg;
    cs_data_i(38) <= x"00"&vccint_reg&vccaux_reg;
    cs_data_i(39) <= s_l1a_err_count;
    -- period_i <= register_array(25)(31 downto 0) when use_vio = '0' else v_period;
    -- register_array_r(11) <= hw_version&fw_version&x"000"&s_chb_grant1&rx_aligned&ttctx_ready&sys_clk_lock_i;
    -- register_array_r(12) <= ch_ready_i;
    -- register_array_r(13) <= error_time1_o;
    -- register_array_r(14) <= error_time2_o;
    -- register_array_r(15) <= x"0000"&error_counter1_o;
    -- register_array_r(16) <= x"0000"&error_counter2_o;
    -- register_array_r(17) <= s_hit_toggle;
    -- register_array_r(18) <= x"0000"&s_1bit_err_count;
    -- register_array_r(19) <= x"0000"&s_2bit_err_count;
    -- register_array_r(20) <= x"0000"&s_comm_err_count;
    -- register_array_r(21) <= x"0000"&s_eye_v;
    -- register_array_r(22) <= x"0000"&s_l1a_eye_v;
    -- register_array_r(23) <= x"0000"&s_tap_error_count;
    -- register_array_r(24) <= x"0000000000"&threshold_i;
    -- register_array_r(25) <= x"0000"&period_i;
    
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
    Inst_ila:entity work.ila_0
    port map(
    clk => sys_clk_125M_i,
    probe0 => timestamp_i,
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
    probe15 => nhit_i,
    probe16 => s_l1a_err_count
    );
--========================================--
--  trigger generator
Inst_trig_gen:entity work.trigger_gen
    port map(
    clk_i => sys_clk_62M5_i,
    reset_i => not ttctx_ready,
    reset_event_cnt_i => '0',
    en_trig_i => en_trig_i,
    ext_trig_i => ext_trig_i,
    l1a_o => l1a_i,
    trig_i => trig_i,
    trig_window_i => trig_window_i,
    global_time_i => timestamp_i,
    period_i => period_i,
    threshold_i => threshold_i,
    hit_i => hit_i,
    nhit_o => nhit_i,
    fake_hit => fake_hit
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
    reset_i => not sys_clk_lock_i,
    rx_aligned => rx_aligned
    );
--===========================================--
--     ipbus core
Inst_ipbus:entity work.ipbus_body
    generic map(g_cs_wonly_deep => g_cs_wonly_deep, -- configuration space number of write only registers;
           g_cs_ronly_deep => g_cs_ronly_deep,  -- configuration space number of read only registers;
	        g_NSLV  => g_NSLV
           )
    port map(
    eth_clk_p => wr_clk_p,
    eth_clk_n => wr_clk_n,
    gtrefclk_out => sys_clk_i,
    eth_tx_p => wr_link_tx_p,
	eth_tx_n => wr_link_tx_n,
	eth_rx_p => wr_link_rx_p,
	eth_rx_n => wr_link_rx_n,
    mac_addr => X"021ddba11574",
	ip_addr => X"C0A80A20", --192.168.10.32
    
    cs_data_o        => cs_data_o,
    cs_data_i        => cs_data_i
    );
--===========================================--
--     sync link to GCU
Inst_sync_link:entity work.sync_links
    port map(
    BEC2GCU_1_P => BEC2GCU_1_P,
    BEC2GCU_1_N => BEC2GCU_1_N,
    BEC2GCU_2_P => BEC2GCU_2_P,
    BEC2GCU_2_N => BEC2GCU_2_N,
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
    l1a_i       => l1a_i,
    nhit_gcu_o  => hit_i,
    timestamp_i => timestamp_48b,
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
    l1a_err_count    => s_l1a_err_count,
    eye_v => s_eye_v,
    l1a_eye_v => s_l1a_eye_v,
    s_tap_error_count => s_tap_error_count
    );
    ch_sel <= to_integer(unsigned(ch_sel_i));
--=================================--
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
--=================================--
--  test signals
SMA(0) <= gcu2bec_1(ch_sel) when sma_sel = '0' else gcu2bec_2(ch_sel);
SMA(1) <= 'Z';

test_pin <= "ZZZZ";
end Behavioral;
