
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;
use work.TTIM_pack.all;
entity sync_links is
    generic(
    g_Hamming : boolean  := true;
    g_TTC_memory_deep  : positive := 25
    );
    Port ( 
    -- hardware interface
    BEC2GCU_1_P : out std_logic_vector(48 downto 1);
    BEC2GCU_1_N : out std_logic_vector(48 downto 1);
    BEC2GCU_2_P : out std_logic_vector(48 downto 1);
    BEC2GCU_2_N : out std_logic_vector(48 downto 1);
    GCU2BEC_1_P : in std_logic_vector(48 downto 1);
    GCU2BEC_1_N : in std_logic_vector(48 downto 1);
    GCU2BEC_2_P : in std_logic_vector(48 downto 1);
    GCU2BEC_2_N : in std_logic_vector(48 downto 1);
    
    gcu2bec_1_o : out std_logic_vector(47 downto 0);
    gcu2bec_2_o : out std_logic_vector(47 downto 0);
    -- internal signals
    clk_i : in STD_LOGIC;
    clk_x2_i : in STD_LOGIC;
    clk_200 : in std_logic;
    sys_clk_lock : in std_logic;
    reset_i : in std_logic;
    test_mode_i : in std_logic_vector(47 downto 0);
    l1a_i : in std_logic;
    nhit_gcu_o : out t_array2(47 downto 0);
    timestamp_i : in std_logic_vector(47 downto 0);
    ch_mask_i : in std_logic_vector(47 downto 0);
    ch_ready_o : out std_logic_vector(47 downto 0);
    tx2_en : in std_logic_vector(47 downto 0);
    tx1_sel : in std_logic_vector(47 downto 0);
    inv_o_1 : in std_logic_vector(47 downto 0);
    ch_sel_i : in std_logic_vector(5 downto 0);
    tap_cnt_i : in std_logic_vector(6 downto 0);
    s_chb_grant1               : out std_logic;
    s_chb_req1               : in std_logic;
    ttc_idle : in std_logic;
    ttc_rst_error : in std_logic;
    s_1588ptp_enable           : in std_logic;
    s_tap_calib_enable         : in std_logic;
    s_tap_rst                  : in std_logic;
    s_tap_incr                 : in std_logic;
    s_l1a_tap_calib_enable     : in std_logic;
    s_l1a_go_prbs              : in std_logic;
    s_hit_toggle               : in std_logic_vector(47 downto 0);
    ld_i : in std_logic_vector(1 downto 0);
    inj_err : in std_logic;
    pair_swap : in std_logic_vector(47 downto 0);
    ttctx_ready : out std_logic;
    error_time1_o : out std_logic_vector(47 downto 0);
    error_time2_o : out std_logic_vector(47 downto 0);
    error_counter1_o : out std_logic_vector(31 downto 0);
    error_counter2_o : out std_logic_vector(31 downto 0);
    sbit_err_count : out std_logic_vector(31 downto 0);
    dbit_err_count : out std_logic_vector(31 downto 0);
    comm_err_count : out std_logic_vector(31 downto 0);
    l1a_err_count : out std_logic_vector(31 downto 0);
    eye_v : out std_logic_vector(31 downto 0);
    l1a_eye_v : out std_logic_vector(31 downto 0);
    s_tap_error_count : out std_logic_vector(31 downto 0)
    );
end sync_links;

architecture Behavioral of sync_links is

    signal clko_i,bec2gcu_2_i,gcu2bec_1_i,gcu2bec_2_i : std_logic_vector(47 downto 0);
    signal prbs_o,ttc_stream,inj_err_r,err_inj : std_logic;
    signal gcu2bec_1_d,gcu2bec_2_d,prbs_r : std_logic_vector(47 downto 0);
    signal ch_i :integer range 0 to 47;
    signal error_counter1,error_counter2,err_cnt_1,err_cnt_2 : t_uarray32(47 downto 0);
    signal s_1bit_err_count,s_2bit_err_count,s_comm_err_count : t_array32(47 downto 0);
    signal single_bit_err_cnt,comm_err_cnt: t_array32(47 downto 0);
    signal s_eye_v,s_l1a_eye_v: t_array32(47 downto 0);
    signal brd_cmd_vector,s_cmd_vector_rx : t_brd_command;
    signal s_long_frame_in1,s_long_frame_in2,s_long_frame_in3,s_long_frame_in4 : t_ttc_long_frame;
    signal s_long_frame_in5,s_long_frame_in6,s_long_frame_in7 : t_ttc_long_frame;
    signal s_long_frame_in2_cal,s_long_frame_in2_eye : t_ttc_long_frame;
    signal chb_busy_o,chb_grant1_o,s_chb_grant3,chb_req1_i,s_chb_req3,s_ttctx_ready : std_logic;
    signal s_chb_grant2,s_chb_grant4,s_chb_grant5,s_chb_grant6,s_chb_grant7,s_chb_grant8 : std_logic;
    signal s_chb_req2,s_chb_req4,s_chb_req5,s_chb_req6,s_chb_req7,s_chb_req8 : std_logic;
    signal s_chb_req3_cal,s_chb_req3_eye : std_logic;
    signal gcuid_i : t_array16(47 downto 0);
    signal s_aligned,s_aligned_i,aligned,s_delay_req : std_logic_vector(47 downto 0);
    signal ch_sel : integer range 0 to 47;
    signal error_time1,error_time2 :t_array48(47 downto 0);
    signal sc_in,hit_in : std_logic_vector(47 downto 0);
    signal nhit_gcu : t_array2(47 downto 0);
    signal s_l1a_cal_done,s_l1a_start_calibration : std_logic;
    signal s_tap_eye,s_l1a_tap_eye : std_logic_vector(335 downto 0);
    signal s_l1a_err,s_comm_err : std_logic_vector(1535 downto 0);
    signal s_l1a_err_count,s_comm_err_count_v : t_array32(47 downto 0);
    signal ptp_fsm : std_logic_vector(4 downto 0);
    signal ptp_gcu_no : std_logic_vector(5 downto 0);
    signal s_ttc_tap_rst,s_ttc_tap_incr,s_l1a_tap_rst,s_l1a_tap_incr : std_logic;
    signal s_ttc_tap_error_count,s_l1a_tap_error_count : std_logic_vector(31 downto 0);
begin
--  buff the differential signals
i_channel_map:entity work.channel_map
    port map(
    BEC2GCU_1_P =>BEC2GCU_1_P,
    BEC2GCU_1_N => BEC2GCU_1_N,
    clko_i => clko_i,
    BEC2GCU_2_P => BEC2GCU_2_P,
    BEC2GCU_2_N => BEC2GCU_2_N,
    datao_i => bec2gcu_2_i,
    --======================--
    GCU2BEC_1_P => GCU2BEC_1_P,
    GCU2BEC_1_N => GCU2BEC_1_N,
    data1i_o => gcu2bec_1_i,
    GCU2BEC_2_P => GCU2BEC_2_P,
    GCU2BEC_2_N => GCU2BEC_2_N,
    data2i_o => gcu2bec_2_i,
    --======================--
    --inv_o_1 => inv_o_1,
    --tx1_sel => tx1_sel,
    tx2_en => tx2_en
    );
    
g_tx1:for i in 47 downto 0 generate
    clko_i(i) <= clk_i when tx1_sel(i) = '0' else prbs_r(i);
    prbs_r(i) <= prbs_o when inv_o_1(i) = '0' else not prbs_o;
    bec2gcu_2_i(i) <= ttc_stream when test_mode_i(i) = '0' else prbs_o;
end generate;
i_channel_delay:entity work.channel_delay
    port map(
    clk_i => clk_x2_i,
    clk_200_i => clk_200,
    ready => open,
    data2_i => gcu2bec_1_i,
    data3_i => gcu2bec_2_i,
    data2_o => gcu2bec_1_d,
    data3_o => gcu2bec_2_d,
    ch_i => ch_sel,
    tap_cnt_i => tap_cnt_i,
    ld_i => ld_i
    );
    ch_sel <= to_integer(unsigned(ch_sel_i));
-- prbs generator and checker in test_mode
process(clk_x2_i)
begin
    if rising_edge(clk_x2_i) then
        inj_err_r <= inj_err;
        if inj_err = '1' and inj_err_r = '0' then
            err_inj <= '1';
        else
            err_inj <= '0';
        end if;
    end if;
end process;
i_prbs_gen:entity work.PRBS_ANY
    generic map(
    CHK_MODE => FALSE,
    INV_PATTERN => FALSE,
    POLY_LENGHT => 7,
    POLY_TAP => 6,
    NBITS => 1
    )
    port map(
    RST => '0',
    CLK => clk_x2_i,
    DATA_IN(0) => err_inj,
    EN => '1',
    DATA_OUT(0) => prbs_o
    );
i_prbs_chk:entity work.prbs_check
    port map(
    clk_i => clk_x2_i,
    reset_i => reset_i,
    en_i => test_mode_i,
    global_time_i => timestamp_i,
    prbs_i1 => gcu2bec_1_d,
    prbs_i2 => gcu2bec_2_d,
    prbs_err1_o => open,
    prbs_err2_o => open,
    err_cnt_1_o => err_cnt_1,
    err_cnt_2_o => err_cnt_2,
    error_time1 => error_time1,
    error_time2 => error_time2
    );
    gcu2bec_1_o <= gcu2bec_1_d;
    gcu2bec_2_o <= gcu2bec_2_d;
    error_counter1_o <= std_logic_vector(err_cnt_1(ch_sel));
    error_counter2_o <= std_logic_vector(err_cnt_2(ch_sel));
    error_time1_o <= error_time1(ch_sel);
    error_time2_o <= error_time2(ch_sel);
    sbit_err_count <= s_1bit_err_count(ch_sel);
    dbit_err_count <= s_2bit_err_count(ch_sel);
    comm_err_count <= s_comm_err_count(ch_sel);
    l1a_err_count <= s_l1a_err_count(ch_sel);
--  link logic when normal running
 -- ttc encoder
Inst_ttc_encoder : entity work.ttc_encoder
    generic map(
      g_pll_locked_delay => 200
      )
    port map(
    locked_i         => sys_clk_lock,
    clk_x2_i         => clk_x2_i,
    brd_cmd_vector_i => brd_cmd_vector,
    l1a_i            => l1a_i,
    long_frame1_i    => s_long_frame_in1,
    long_frame2_i    => s_long_frame_in2,
    long_frame3_i      => s_long_frame_in3,  -- PORT4 eye scan
    long_frame4_i      => s_long_frame_in4,  -- PORT5 
    long_frame5_i      => s_long_frame_in5,  -- PORT6 
    long_frame6_i      => s_long_frame_in6,  -- PORT7  
    long_frame7_i      => s_long_frame_in7,  -- PORT8 trigger 
    ttc_stream_o     => ttc_stream, --TTC up link
    chb_busy_o       => chb_busy_o,
    chb_grant1_o     => s_chb_grant1, --brd cmd channel
    chb_grant2_o     => s_chb_grant2,
    chb_grant3_o     => s_chb_grant3,
    chb_grant4_o       => s_chb_grant4,
    chb_grant5_o       => s_chb_grant5,
    chb_grant6_o       => s_chb_grant6,
    chb_grant7_o       => s_chb_grant7,
    chb_grant8_o       => s_chb_grant8, 
    chb_req1_i       => s_chb_req1,
    chb_req2_i       => s_chb_req2,
    chb_req3_i       => s_chb_req3,
    chb_req4_i         => s_chb_req4,
    chb_req5_i         => s_chb_req5,
    chb_req6_i         => s_chb_req6,
    chb_req7_i         => s_chb_req7,
    chb_req8_i         => s_chb_req8,
    ready_o          => s_ttctx_ready
    );
    brd_cmd_vector.idle           <= ttc_idle;
    brd_cmd_vector.rst_time       <= '0';
    brd_cmd_vector.rst_event      <= '0';
    brd_cmd_vector.rst_time_event <= '0';
    brd_cmd_vector.supernova      <= '0';
    brd_cmd_vector.test_pulse     <= '0';
    brd_cmd_vector.time_request   <= '0';
    brd_cmd_vector.rst_errors     <= ttc_rst_error;
    brd_cmd_vector.autotrigger    <= '0';
    brd_cmd_vector.en_acquisition <= '0';
    ttctx_ready <= s_ttctx_ready;
  select_eye_cal_l1a : process (s_l1a_tap_calib_enable) is
  begin  -- process select_eye_cal_l1a
    case s_l1a_tap_calib_enable is
      when '1' =>
        s_long_frame_in2 <= s_long_frame_in2_cal;
        s_chb_req3       <= s_chb_req3_cal;
      when '0' =>
        s_long_frame_in2 <= s_long_frame_in2_eye;
        s_chb_req3       <= s_chb_req3_eye;
      when others =>
        null ;
    end case;
  end process select_eye_cal_l1a;
 -- ttc decoders
genGCUupLink:for i in 47 downto 0 generate
    gcuid_i(i) <= std_logic_vector(to_unsigned(i + 1, 16));
    nhit_gcu_o(i) <= nhit_gcu(i) when ch_mask_i(i) = '1' else (others => '0');
    hit_in(i) <= gcu2bec_1_d(i) when pair_swap(i) = '0' else gcu2bec_2_d(i);
    sc_in(i) <= gcu2bec_2_d(i) when pair_swap(i) = '0' else gcu2bec_1_d(i);
    -- s_hit_toggle <= s_hit_toggle_ipbus when v_l1a_use_vio = '0' else
                    -- v_hit_toggle;

    ttc_decoder_core : entity work.ttc_decoder_core
      generic map (
        g_pll_locked_delay => 200,
        g_Hamming          => g_Hamming,
        g_max_trigg_len    => 10,
        g_TTC_memory_deep  => 26)
      port map (
        locked_i              => sys_clk_lock,
        cdrclk_x4_i           => clk_x2_i,
        cdrclk_x2_i           => clk_i,
        cdrdata_i             => sc_in(i),
        ttcrx_coarse_delay_i  => (others => '0'),
        gcuid_i               => gcuid_i(i),
        cha_o                 => nhit_gcu(i),
        brd_command_vector_o  => open,
        l1a_time_o            => open,
        synch_o               => open,
        delay_o               => open,
        ttc_ctrl_o            => open,
        delay_req_o           => s_delay_req(i),
        synch_req_o           => open,
        byte5_o               => open,
        reset_err           => reset_i,
        single_bit_err_o      => s_1bit_err_count(i),
        duble_bit_err_o       => s_2bit_err_count(i),
        comm_err_o            => s_comm_err_count_v(i),
        l1a_err_o             => s_l1a_err_count(i),
        ready_o               => open,
        no_errors_o           => open,
        l1a_no_errors_o       => open,
        aligned_o             => s_aligned(i),
        not_in_table_o        => open,
        cha_time_domain_o     => open,
        hit_toggle            => s_hit_toggle(i),
        l1a_i                 => hit_in(i),
        toggle_channel_debug  => open,
        toggle_shift_debug    => open,
        bmc_data_toggle_debug => open,
        cdr_data_debug        => open,
        brc_cmd_debug         => open,
        brc_cmd_strobe_debug  => open,
        brc_rst_t_debug       => open,
        brc_rst_e_debug       => open,
        error_1bit_pulse_test => open,
        error_2bit_pulse_test => open,
        error_comm_pulse_test => open);
        s_aligned_i(i) <= s_aligned(i) when ch_mask_i(i) = '1' else '0';
end generate;
s_comm_err_count <= s_comm_err_count_v;
ch_ready_o <= s_aligned_i;
-- send trigger time via ttc
ttc_trg_time_1 : entity work.ttc_trg_time
    port map (
      clk_i           => clk_x2_i,
      rst_i           => not sys_clk_lock,
      ttctx_ready_i   => s_ttctx_ready,
      local_time_i    => timestamp_i,
      local_trigger_i => l1a_i,
      chb_grant_i     => s_chb_grant8,
      chb_req_o       => s_chb_req8,
      ttc_long_o      => s_long_frame_in7,
      s_local_trigger_pulse_o => open,
      time_to_send    => open
      );

---------------------------------1588 ptp protocol BEC side-------------------------
Inst_bec_1588_ptp:entity work.BEC_1588_ptp_v2
    port map(
    clk_i   => clk_x2_i,
    clk_div2 => clk_i,
    rst_i   => not sys_clk_lock,
    ttcrx_ready => ch_mask_i,
    enable_i    => s_1588ptp_enable,
    period_i    => x"20000000", --32b time interval for ptp check
    delay_req_i => s_delay_req,
    chb_grant_i => s_chb_grant2,
    local_time_i=> timestamp_i, --48b local time
    chb_req_o   => s_chb_req2,
    fsm_debug_o => ptp_fsm, --5 bits
    current_gcu => ptp_gcu_no, -- 6 bits
    catch_time => open,
    s_go_o => open,
    gcu_id_i    => gcuid_i, --GCU IDs in parallel
    ttc_long_o  => s_long_frame_in1 --ttc long format to encoder
    );
    -- Inst_ila2:entity work.ila_2
    -- port map(
    -- clk => clk_x2_i,
    -- probe0 => ptp_fsm,
    -- probe1 => ptp_gcu_no
    -- );
  -----------------------------------------------------------------------------
  -- TTC calibration
  -----------------------------------------------------------------------------
  Inst_tap_calibration : entity work.tap_calibration_one_edge
    generic map(
      g_number_of_GCU   => 48,
      g_error_threshold => 50,
      calibrating_ttc   => true
      )
    port map(
      clk_i                  => clk_x2_i,
      rst_i                  => not s_ttctx_ready,
      start_i                => s_tap_calib_enable,
      gcu_sel_i              => ch_sel_i,
      aligned_i              => ch_mask_i,  -- 48 bit
      comm_err_i             => s_comm_err,
      chb_grant_i            => s_chb_grant4,
      chb_req_o              => s_chb_req4,
      gcu_id_i               => gcuid_i,
      ttc_long_o             => s_long_frame_in3,
      eye_o                  => s_tap_eye,
      cal_done               => open,
      debug_go_to_next_state => '0'
      );

  -----------------------------------------------------------------------------
  -- L1A calibration
  -----------------------------------------------------------------------------
  l1a_calibration_manager_1 : entity work.l1a_calibration_manager
    generic map (
      g_number_of_GCU => 48
      )
    port map (
      clk_i            => clk_x2_i,
      rst_i            => not s_ttctx_ready,
      l1a_go_prbs      => s_l1a_tap_calib_enable,
      gcu_sel_i        => ch_sel_i,
      chb_grant_i      => s_chb_grant3,
      chb_req_o        => s_chb_req3_cal,
      gcu_id_i         => gcuid_i,
      l1a_cal_done     => s_l1a_cal_done,
      ttc_long_o       => s_long_frame_in2_cal,
      l1a_tap_calib_en => s_l1a_start_calibration
      );

  Inst_l1a_tap_calibration : entity work.tap_calibration_one_edge
    generic map(
      g_number_of_GCU   => 48,
      g_error_threshold => 50,
      calibrating_ttc   => false
      )
    port map(
      clk_i                  => clk_x2_i,
      rst_i                  => not s_ttctx_ready,
      start_i                => s_l1a_start_calibration,
      gcu_sel_i              => ch_sel_i,
      aligned_i              => ch_mask_i,  -- 48 bit
      comm_err_i             => s_l1a_err,
      chb_grant_i            => s_chb_grant5,
      chb_req_o              => s_chb_req5,
      gcu_id_i               => gcuid_i,
      ttc_long_o             => s_long_frame_in4,
      eye_o                  => s_l1a_tap_eye,
      cal_done               => s_l1a_cal_done,
      debug_go_to_next_state => '0'
      );
  gen_eye_vector : for i in 1 to 48 generate
    s_eye_v(i - 1)     <= x"000000" & '0' & s_tap_eye(i*7 - 1 downto (i - 1)*7);
    s_l1a_eye_v(i - 1) <= x"000000" & '0' & s_l1a_tap_eye(i*7 - 1 downto (i - 1)*7);
  end generate gen_eye_vector;
  eye_v <= s_eye_v(ch_sel);
  l1a_eye_v <= s_l1a_eye_v(ch_sel);
  -----------------------------------------------------------------------------
  -- Eye scanner
  -----------------------------------------------------------------------------
  p_l1a_ttc_select : process (s_l1a_go_prbs) is
  begin  -- process p_l1a_ttc_select
    case s_l1a_go_prbs is
      when '0' =>
        s_ttc_tap_rst     <= s_tap_rst;
        s_ttc_tap_incr    <= s_tap_incr;
        s_tap_error_count <= s_ttc_tap_error_count;
        s_l1a_tap_rst     <= '0';
        s_l1a_tap_incr    <= '0';

      when '1' =>
        s_ttc_tap_rst     <= '0';
        s_ttc_tap_incr    <= '0';
        s_tap_error_count <= s_l1a_tap_error_count;
        s_l1a_tap_rst     <= s_tap_rst;
        s_l1a_tap_incr    <= s_tap_incr;

      when others =>
        null;
    end case;
  end process p_l1a_ttc_select;

  -- TTC eye scan
  Inst_eye_scan : entity work.eye_scan
    generic map(
      g_number_of_GCU => 48,
      calibrating_ttc => true
      )
    port map(
      clk_i         => clk_x2_i,
      rst_i         => not s_ttctx_ready,
      tap_rst_i     => s_ttc_tap_rst,
      tap_incr_i    => s_ttc_tap_incr,
      gcu_sel_i     => ch_sel_i,
      chb_grant_i   => s_chb_grant6,
      chb_req_o     => s_chb_req6,
      gcu_id_i      => gcuid_i,
      ttc_long_o    => s_long_frame_in5,
      comm_err_i    => s_comm_err,
      error_count_o => s_ttc_tap_error_count,
      debug_fsm_o   => open
      );

  -- L1A eye scan
  l1a_eye_scan_manager_1 : entity work.l1a_eye_scan_manager
    generic map (
      g_number_of_GCU => 48
      )
    port map (
      clk_i       => clk_x2_i,
      rst_i       => not s_ttctx_ready,
      l1a_go_prbs => s_l1a_go_prbs,
      gcu_sel_i   => ch_sel_i,
      gcu_id_i    => gcuid_i,
      chb_grant_i => s_chb_grant3,
      chb_req_o   => s_chb_req3_eye,
      ttc_long_o  => s_long_frame_in2_eye
      );

  Inst_l1a_eye_scan : entity work.eye_scan
    generic map(
      g_number_of_GCU => 48,
      calibrating_ttc => false
      )
    port map(
      clk_i         => clk_x2_i,
      rst_i         => not s_ttctx_ready,
      tap_rst_i     => s_l1a_tap_rst,
      tap_incr_i    => s_l1a_tap_incr,
      gcu_sel_i     => ch_sel_i,
      chb_grant_i   => s_chb_grant7,
      chb_req_o     => s_chb_req7,
      gcu_id_i      => gcuid_i,
      ttc_long_o    => s_long_frame_in6,
      comm_err_i    => s_l1a_err,
      error_count_o => s_l1a_tap_error_count,
      debug_fsm_o   => open
      );
  gen_comm_err_vector : for i in 1 to 48 generate
    s_comm_err(i*32 - 1 downto (i-1)*32) <= s_comm_err_count_v(i-1)(31 downto 0);
    s_l1a_err(i*32 - 1 downto (i-1)*32)  <= s_l1a_err_count(i-1)(31 downto 0);
  end generate gen_comm_err_vector;
  
end Behavioral;
