----------------------------------------------------------------------------------
-- Company:        INFN - LNL
-- Engineer:       Davide Pedretti
-- Create Date:    14:42:47 10/09/2017 
-- Module Name:    tap_calibration - rtl 
-- Project Name:   BEC JUNO
-- Tool versions:  ISE 14.7
-- Revision 0.01 - File Created
-- Description:    GCU TTC-TX tap delay calibration; the goal is to find the best sampling point for the 
--                 GCU TTC RX tiles inside the BEC card. The opening of the eye information is intended as
--                 the number of taps for which the TTC RX decoder errors is null.
----------------------------------------------------------------------------------
library ieee;
library XilinxCoreLib;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use work.TTIM_pack.all;

entity tap_calibration_one_edge is
  generic(
    g_number_of_GCU   : positive := 3;
    g_error_threshold : positive := 100;
    calibrating_ttc   : boolean  := true
    );
  port (
    clk_i                  : in  std_logic;
    rst_i                  : in  std_logic;
    start_i                : in  std_logic;  -- start GCUx tap calibration; transition from 0 to 1
    gcu_sel_i              : in  std_logic_vector (5 downto 0);  -- GCUx select; from 1 to 48. 0 = no GCU selected
    aligned_i              : in  std_logic_vector (47 downto 0);  -- GCUx aligned flag
    comm_err_i             : in  std_logic_vector (g_number_of_GCU*32 - 1 downto 0);
    chb_grant_i            : in  std_logic;  -- CHB port 3 channel grant flag
    chb_req_o              : out std_logic;  -- CHB port 3 request 
    gcu_id_i               : in  t_array16(47 downto 0);  -- GCUs IDs
    ttc_long_o             : out t_ttc_long_frame;  -- ttc long frame CHB port 3
    eye_o                  : out std_logic_vector (g_number_of_GCU*7 - 1 downto 0);  -- GCUx opening of the eye 
    cal_done               : out std_logic;
    debug_fsm_o            : out std_logic_vector (4 downto 0);
    debug_bomb_o           : out std_logic;
    debug_bit              : out std_logic;
    debug_go_to_next_state : in  std_logic;
    debug_error            : out std_logic_vector (32 downto 0)
    );

end tap_calibration_one_edge;

architecture rtl of tap_calibration_one_edge is
  type t_tap_state is (st0_idle,        -- b"00000"
                       st0_idle2,
                       st1_cb_req,      -- b"00001"
                       st2_tap_reset,   -- b"00010"
                       st3_evaluate,    -- b"00011"
                       st4_cb_req,      -- b"00100"
                       st5_tap_incr,    -- b"00101"
                       st6_cb_req,      -- b"00110"
                       st7_tap_incr,    -- b"00111"
                       st8_evaluate,    -- b"01000"
                       st9_load_eye,    -- b"01100"
                       st10_shift,      -- b"01101"
                       st11_load_decr,  -- b"01110"
                       st12_cb_req,     -- b"01111"
                       st13_tap_decr,   -- b"10000"
                       st14_wait,       -- b"10001"
                       st15_cal_done
                       );

  --type t_gcuid_array is array (47 downto 0) of std_logic_vector (15 downto 0);
  type t_gcuerror_array is array (47 downto 0) of std_logic_vector (31 downto 0);
  type t_eye_values is array(1 downto 0) of std_logic_vector(7 downto 0);

  type t_fsm_signals is
  record
    lock           : std_logic;
    long_data      : std_logic_vector(7 downto 0);
    long_saddr     : std_logic_vector(7 downto 0);
    strobe         : std_logic;
    strobe_decr    : std_logic;
    load_eye       : std_logic;
    en_countdown   : std_logic;
    incr_eye_count : std_logic;
    decr_count     : std_logic;
    tap_decr_load  : std_logic;
    chb_request    : std_logic;
    shift          : std_logic;
    error_flag     : std_logic;
    debug          : std_logic_vector(4 downto 0);
    cal_done       : std_logic;
  end record;

  constant c_fsm_signals : t_fsm_signals := (
    lock           => '0',
    long_data      => x"00",
    long_saddr     => x"00",
    strobe         => '0',
    strobe_decr    => '0',
    load_eye       => '0',
    en_countdown   => '0',
    incr_eye_count => '0',
    decr_count     => '0',
    tap_decr_load  => '0',
    chb_request    => '0',
    shift          => '0',
    error_flag     => '0',
    debug          => b"11111",
    cal_done       => '0'
    );

  component AddSub
    port(
      a    : in  std_logic_vector(31 downto 0);
      b    : in  std_logic_vector(31 downto 0);
      clk  : in  std_logic;
      c_in : in  std_logic;
      ce   : in  std_logic;
      --c_out : OUT STD_LOGIC;
      s    : out std_logic_vector(32 downto 0)
      );
  end component;

  signal s_fsm_signals       : t_fsm_signals;
  signal s_state             : t_tap_state;
  signal s_gcu_id            : t_array16(47 downto 0);
  signal s_gcu_error_vec     : t_gcuerror_array;
  signal s_eye_values        : t_eye_values;
  signal s_aligned           : std_logic;
  signal s_no_error_low      : std_logic;
  signal s_no_error_up       : std_logic;
  signal s_sel               : unsigned(5 downto 0);
  signal s_start             : std_logic;
  signal s_enable_countdown  : std_logic;
  signal s_count             : std_logic_vector(31 downto 0);
  signal s_go                : std_logic;
  signal s_load_err          : std_logic;
  signal s_sum1              : std_logic;
  signal s_sum2              : std_logic;
  signal u_tot_tap_count     : unsigned(7 downto 0);
  signal u_error_tap_count   : unsigned(7 downto 0);
  signal u_eye_tap_count     : unsigned(7 downto 0);
  signal u_old_eye           : unsigned(7 downto 0);
  signal u_new_eye           : unsigned(7 downto 0);
  signal u_tap_shifted       : unsigned(7 downto 0);
  signal s_tot_tap_count     : std_logic_vector(7 downto 0);
  signal s_eye_tap_count     : std_logic_vector(7 downto 0);
  signal s_error_flag        : std_logic;
  signal s_error_flag_re     : std_logic;
  signal u_bomb              : unsigned(30 downto 0);
  signal s_bomb_count        : std_logic_vector(30 downto 0);
  signal s_tap_decr          : std_logic_vector(7 downto 0);
  signal s_sampling_point    : std_logic;
  signal s_incr_eye_count    : std_logic;
  signal s_decr_count        : std_logic;
  signal s_load_eye          : std_logic;
  signal s_tap_decr_load     : std_logic;
  signal s_bomb              : std_logic;
  signal s_shift             : std_logic;
  signal s_lock              : std_logic;
  signal s_eye_zero          : std_logic;
  signal s_eye_one           : std_logic;
  signal u_strobe_count      : unsigned(10 downto 0);
  signal s_error             : std_logic_vector (31 downto 0);
  signal s_error_0           : std_logic_vector (31 downto 0);
  signal s_error_1           : std_logic_vector (31 downto 0);
  signal s_error_2           : std_logic_vector (31 downto 0);
  signal s_sum_part          : std_logic_vector (32 downto 0);
  signal s_sum_total         : std_logic_vector (32 downto 0);
  signal s_carry             : std_logic;
  signal s_no_error          : std_logic;
  signal s_next_state        : std_logic;
  signal s_incr_eye_count_re : std_logic;
  signal s_long_strobe_to_re : std_logic;
  signal s_load_eye_re       : std_logic;
  signal s_decr_count_re     : std_logic;
  signal s_strobe_decr_re    : std_logic;
  signal s_eye_check         : std_logic;
  signal s_tap_incr_reg      : std_logic_vector(7 downto 0);
  signal s_tap_decr_reg      : std_logic_vector(7 downto 0);
  signal s_tap_rst_reg       : std_logic_vector(7 downto 0);
  signal s_cal_done          : std_logic;

  attribute mark_debug                  : string;
  attribute mark_debug of s_state            : signal is "true";
  -- attribute mark_debug of s_eye_tap_count    : signal is "true";
  -- attribute mark_debug of u_error_tap_count  : signal is "true";
  -- attribute mark_debug of s_tot_tap_count    : signal is "true";
  -- attribute mark_debug of s_error_flag       : signal is "true";
  -- attribute mark_debug of s_eye_values       : signal is "true";
  -- attribute mark_debug of u_old_eye          : signal is "true";
  -- attribute mark_debug of u_new_eye          : signal is "true";
  -- attribute mark_debug of u_tap_shifted : signal is "true";
  -- attribute mark_debug of s_load_eye         : signal is "true";
  -- attribute mark_debug of s_tap_decr         : signal is "true";
  -- attribute mark_debug of s_sampling_point   : signal is "true";
  -- attribute mark_debug of s_shift            : signal is "true";
  -- attribute mark_debug of chb_grant_i        : signal is "true";
  -- attribute mark_debug of s_enable_countdown : signal is "true";
  -- attribute mark_debug of s_count            : signal is "true";
  -- attribute mark_debug of s_go               : signal is "true";


begin

  -----------------------------------------------------------------------------
  -- TTC or L1A?
  -----------------------------------------------------------------------------
  s_tap_incr_reg <= x"1a" when calibrating_ttc else
                    x"1d";

  s_tap_decr_reg <= x"1b" when calibrating_ttc else
                    x"1e";

  s_tap_rst_reg <= x"1c" when calibrating_ttc else
                   x"1f";

  Inst_start_rise_edge_detect : entity work.r_edge_detect
    generic map(
      g_clk_rise => "TRUE"
      )
    port map(
      clk_i => clk_i,
      sig_i => start_i,
      sig_o => s_start
      );

  r_edge_detect_next_state : entity work.r_edge_detect
    generic map (
      g_clk_rise => "TRUE")
    port map (
      clk_i => clk_i,
      sig_i => debug_go_to_next_state,
      sig_o => s_next_state
      );

  -- r_edge_detect_incr_count : entity work.r_edge_detect
  --   generic map (
  --     g_clk_rise => "TRUE")
  --   port map (
  --     clk_i => clk_i,
  --     sig_i => s_incr_eye_count,
  --     sig_o => s_incr_eye_count_re
  --     );

  s_incr_eye_count_re <= s_incr_eye_count;

  -- r_edge_detect_load_eye : entity work.r_edge_detect
  --   generic map (
  --     g_clk_rise => "TRUE")
  --   port map (
  --     clk_i => clk_i,
  --     sig_i => s_load_eye,
  --     sig_o => s_load_eye_re
  --     );

  GEN_GCU_ID_ARRAY_1 :
  for I in 1 to g_number_of_GCU generate
    --s_gcu_id(I - 1)        <= gcu_id_i(I*16 -1 downto I*16 -16);
    s_gcu_error_vec(I - 1) <= comm_err_i(I*32 -1 downto I*32 -32);
  end generate GEN_GCU_ID_ARRAY_1;
s_gcu_id <= gcu_id_i;
  GEN_FILL_ARRAY : if g_number_of_GCU < 48 generate

    GEN_GCU_ID_ARRAY_2 :
    for I in g_number_of_GCU to 47 generate
      --s_gcu_id(I)        <= x"ffff";
      s_gcu_error_vec(I) <= x"00000000";
    end generate GEN_GCU_ID_ARRAY_2;

  end generate GEN_FILL_ARRAY;

  process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      s_sel <= (others => '0');
    elsif rising_edge(clk_i) then
      if s_start = '1' and s_lock = '0' then
        s_sel <= unsigned(gcu_sel_i) +1;
      end if;
    end if;
  end process;

  process(s_sel, aligned_i, s_gcu_id, s_gcu_error_vec)
  begin
    case to_integer(s_sel) is
      when 0 =>                         -- no GCU selected for calibration
        ttc_long_o.long_address <= x"ffff";
        s_aligned               <= '0';
        s_error                 <= x"00000000";
      when 1 =>
        ttc_long_o.long_address <= s_gcu_id(0);
        s_aligned               <= aligned_i(0);
        s_error                 <= s_gcu_error_vec(0);

      when 2 =>
        ttc_long_o.long_address <= s_gcu_id(1);
        s_aligned               <= aligned_i(1);
        s_error                 <= s_gcu_error_vec(1);

      when 3 =>
        ttc_long_o.long_address <= s_gcu_id(2);
        s_aligned               <= aligned_i(2);
        s_error                 <= s_gcu_error_vec(2);

      when 4 =>
        ttc_long_o.long_address <= s_gcu_id(3);
        s_aligned               <= aligned_i(3);
        s_error                 <= s_gcu_error_vec(3);

      when 5 =>
        ttc_long_o.long_address <= s_gcu_id(4);
        s_aligned               <= aligned_i(4);
        s_error                 <= s_gcu_error_vec(4);

      when 6 =>
        ttc_long_o.long_address <= s_gcu_id(5);
        s_aligned               <= aligned_i(5);
        s_error                 <= s_gcu_error_vec(5);

      when 7 =>
        ttc_long_o.long_address <= s_gcu_id(6);
        s_aligned               <= aligned_i(6);
        s_error                 <= s_gcu_error_vec(6);

      when 8 =>
        ttc_long_o.long_address <= s_gcu_id(7);
        s_aligned               <= aligned_i(7);
        s_error                 <= s_gcu_error_vec(7);

      when 9 =>
        ttc_long_o.long_address <= s_gcu_id(8);
        s_aligned               <= aligned_i(8);
        s_error                 <= s_gcu_error_vec(8);

      when 10 =>
        ttc_long_o.long_address <= s_gcu_id(9);
        s_aligned               <= aligned_i(9);
        s_error                 <= s_gcu_error_vec(9);

      when 11 =>
        ttc_long_o.long_address <= s_gcu_id(10);
        s_aligned               <= aligned_i(10);
        s_error                 <= s_gcu_error_vec(10);

      when 12 =>
        ttc_long_o.long_address <= s_gcu_id(11);
        s_aligned               <= aligned_i(11);
        s_error                 <= s_gcu_error_vec(11);

      when 13 =>
        ttc_long_o.long_address <= s_gcu_id(12);
        s_aligned               <= aligned_i(12);
        s_error                 <= s_gcu_error_vec(12);

      when 14 =>
        ttc_long_o.long_address <= s_gcu_id(13);
        s_aligned               <= aligned_i(13);
        s_error                 <= s_gcu_error_vec(13);

      when 15 =>
        ttc_long_o.long_address <= s_gcu_id(14);
        s_aligned               <= aligned_i(14);
        s_error                 <= s_gcu_error_vec(14);

      when 16 =>
        ttc_long_o.long_address <= s_gcu_id(15);
        s_aligned               <= aligned_i(15);
        s_error                 <= s_gcu_error_vec(15);

      when 17 =>
        ttc_long_o.long_address <= s_gcu_id(16);
        s_aligned               <= aligned_i(16);
        s_error                 <= s_gcu_error_vec(16);

      when 18 =>
        ttc_long_o.long_address <= s_gcu_id(17);
        s_aligned               <= aligned_i(17);
        s_error                 <= s_gcu_error_vec(17);

      when 19 =>
        ttc_long_o.long_address <= s_gcu_id(18);
        s_aligned               <= aligned_i(18);
        s_error                 <= s_gcu_error_vec(18);

      when 20 =>
        ttc_long_o.long_address <= s_gcu_id(19);
        s_aligned               <= aligned_i(19);
        s_error                 <= s_gcu_error_vec(19);

      when 21 =>
        ttc_long_o.long_address <= s_gcu_id(20);
        s_aligned               <= aligned_i(20);
        s_error                 <= s_gcu_error_vec(20);

      when 22 =>
        ttc_long_o.long_address <= s_gcu_id(21);
        s_aligned               <= aligned_i(21);
        s_error                 <= s_gcu_error_vec(21);

      when 23 =>
        ttc_long_o.long_address <= s_gcu_id(22);
        s_aligned               <= aligned_i(22);
        s_error                 <= s_gcu_error_vec(22);

      when 24 =>
        ttc_long_o.long_address <= s_gcu_id(23);
        s_aligned               <= aligned_i(23);
        s_error                 <= s_gcu_error_vec(23);

      when 25 =>
        ttc_long_o.long_address <= s_gcu_id(24);
        s_aligned               <= aligned_i(24);
        s_error                 <= s_gcu_error_vec(24);

      when 26 =>
        ttc_long_o.long_address <= s_gcu_id(25);
        s_aligned               <= aligned_i(25);
        s_error                 <= s_gcu_error_vec(25);

      when 27 =>
        ttc_long_o.long_address <= s_gcu_id(26);
        s_aligned               <= aligned_i(26);
        s_error                 <= s_gcu_error_vec(26);

      when 28 =>
        ttc_long_o.long_address <= s_gcu_id(27);
        s_aligned               <= aligned_i(27);
        s_error                 <= s_gcu_error_vec(27);

      when 29 =>
        ttc_long_o.long_address <= s_gcu_id(28);
        s_aligned               <= aligned_i(28);
        s_error                 <= s_gcu_error_vec(28);

      when 30 =>
        ttc_long_o.long_address <= s_gcu_id(29);
        s_aligned               <= aligned_i(29);
        s_error                 <= s_gcu_error_vec(29);

      when 31 =>
        ttc_long_o.long_address <= s_gcu_id(30);
        s_aligned               <= aligned_i(30);
        s_error                 <= s_gcu_error_vec(30);

      when 32 =>
        ttc_long_o.long_address <= s_gcu_id(31);
        s_aligned               <= aligned_i(31);
        s_error                 <= s_gcu_error_vec(31);

      when 33 =>
        ttc_long_o.long_address <= s_gcu_id(32);
        s_aligned               <= aligned_i(32);
        s_error                 <= s_gcu_error_vec(32);

      when 34 =>
        ttc_long_o.long_address <= s_gcu_id(33);
        s_aligned               <= aligned_i(33);
        s_error                 <= s_gcu_error_vec(33);

      when 35 =>
        ttc_long_o.long_address <= s_gcu_id(34);
        s_aligned               <= aligned_i(34);
        s_error                 <= s_gcu_error_vec(34);

      when 36 =>
        ttc_long_o.long_address <= s_gcu_id(35);
        s_aligned               <= aligned_i(35);
        s_error                 <= s_gcu_error_vec(35);

      when 37 =>
        ttc_long_o.long_address <= s_gcu_id(36);
        s_aligned               <= aligned_i(36);
        s_error                 <= s_gcu_error_vec(36);

      when 38 =>
        ttc_long_o.long_address <= s_gcu_id(37);
        s_aligned               <= aligned_i(37);
        s_error                 <= s_gcu_error_vec(37);

      when 39 =>
        ttc_long_o.long_address <= s_gcu_id(38);
        s_aligned               <= aligned_i(38);
        s_error                 <= s_gcu_error_vec(38);

      when 40 =>
        ttc_long_o.long_address <= s_gcu_id(39);
        s_aligned               <= aligned_i(39);
        s_error                 <= s_gcu_error_vec(39);

      when 41 =>
        ttc_long_o.long_address <= s_gcu_id(40);
        s_aligned               <= aligned_i(40);
        s_error                 <= s_gcu_error_vec(40);

      when 42 =>
        ttc_long_o.long_address <= s_gcu_id(41);
        s_aligned               <= aligned_i(41);
        s_error                 <= s_gcu_error_vec(41);

      when 43 =>
        ttc_long_o.long_address <= s_gcu_id(42);
        s_aligned               <= aligned_i(42);
        s_error                 <= s_gcu_error_vec(42);

      when 44 =>
        ttc_long_o.long_address <= s_gcu_id(43);
        s_aligned               <= aligned_i(43);
        s_error                 <= s_gcu_error_vec(43);

      when 45 =>
        ttc_long_o.long_address <= s_gcu_id(44);
        s_aligned               <= aligned_i(44);
        s_error                 <= s_gcu_error_vec(44);

      when 46 =>
        ttc_long_o.long_address <= s_gcu_id(45);
        s_aligned               <= aligned_i(45);
        s_error                 <= s_gcu_error_vec(45);

      when 47 =>
        ttc_long_o.long_address <= s_gcu_id(46);
        s_aligned               <= aligned_i(46);
        s_error                 <= s_gcu_error_vec(46);

      when 48 =>
        ttc_long_o.long_address <= s_gcu_id(47);
        s_aligned               <= aligned_i(47);
        s_error                 <= s_gcu_error_vec(47);

      when others =>
        ttc_long_o.long_address <= x"ffff";
        s_aligned               <= '0';
        s_error                 <= x"00000000";
    end case;

  end process;

--===================================================-- 
--                       COUNTDOWN
--===================================================--

  Inst_countdown : entity work.countdown
    generic map(
      g_width    => 32,
      g_clk_rise => "TRUE"
      )
    port map(
      clk_i    => clk_i,
      reset_i  => rst_i,
      load_i   => chb_grant_i or s_load_eye or s_start,
      enable_i => s_enable_countdown,
      p_i      => x"00020000",          -- wait for ~ 131us = 8000
      p_o      => s_count
      );

  p_go : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if s_count = x"00000004" then
        s_go       <= '0';
        s_load_err <= '1';
        s_sum1     <= '0';
        s_sum2     <= '0';
      elsif s_count = x"00000003" then
        s_go       <= '0';
        s_load_err <= '0';
        s_sum1     <= '1';
        s_sum2     <= '0';
      elsif s_count = x"00000002" then
        s_go       <= '0';
        s_load_err <= '0';
        s_sum1     <= '0';
        s_sum2     <= '1';
      elsif s_count = x"00000001" then
        s_go       <= '1';
        s_load_err <= '0';
        s_sum1     <= '0';
        s_sum2     <= '0';
      else
        s_go       <= '0';
        s_load_err <= '0';
        s_sum1     <= '0';
        s_sum2     <= '0';
      end if;
    end if;
  end process p_go;
--===================================================-- 
--                     ERROR HANDLER
--===================================================-- 
  p_error_load : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if s_start = '1' then
        s_error_0 <= (others => '0');
        s_error_1 <= (others => '0');
        s_error_2 <= (others => '0');
      elsif s_load_err = '1' then
        s_error_0 <= s_error;
        s_error_1 <= s_error_0;
        s_error_2 <= s_error_1;
      end if;
    end if;
  end process p_error_load;

  Inst_adder1 : AddSub
    port map (
      a    => s_error_1,
      b    => s_error_2,
      clk  => clk_i,
      c_in => '0',
      ce   => s_sum1,
      --c_out => s_carry,
      s    => s_sum_part
      );

  Inst_adder2 : AddSub
    port map (
      a    => s_error_0,
      b    => s_sum_part(31 downto 0),
      clk  => clk_i,
      c_in => s_sum_part(32),
      ce   => s_sum2,
      --c_out => s_sum_total(32),
      s    => s_sum_total
      );
  s_no_error <= '0' when unsigned(s_sum_total) >= g_error_threshold else
                '1';
--===================================================-- 
--                       EYE COUNTER
--===================================================-- 
  p_tot_counter : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if s_start = '1' then
        u_tot_tap_count <= (others => '0');
      elsif s_incr_eye_count_re = '1' then
        u_tot_tap_count <= u_tot_tap_count + 1;
      end if;
    end if;
  end process p_tot_counter;

  s_tot_tap_count <= std_logic_vector(u_tot_tap_count);

  r_edge_detect_1 : entity work.r_edge_detect
    generic map (
      g_clk_rise => "TRUE")
    port map (
      clk_i => clk_i,
      sig_i => s_error_flag,
      sig_o => s_error_flag_re
      );

  p_partial_counter : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if s_start = '1' or s_error_flag_re = '1' then
        u_error_tap_count <= (others => '0');
        u_eye_tap_count   <= (others => '0');
      elsif s_incr_eye_count_re = '1' then
        if s_error_flag = '1' then
          u_error_tap_count <= u_error_tap_count + 1;
        else
          u_eye_tap_count <= u_eye_tap_count + 1;
        end if;
      end if;
    end if;
  end process p_partial_counter;

  s_eye_tap_count <= std_logic_vector(u_eye_tap_count);

  s_eye_check <= or_reduce(s_eye_tap_count(7 downto 1));  -- need to avoid eyes
  -- wider less than 2 taps

  p_eye_latcher : process (clk_i, rst_i) is
  begin  -- process p_eye_latcher
    if rst_i = '1' or s_start = '1' then  -- asynchronous reset (active high)
      s_eye_values <= (others => (others => '0'));
    elsif rising_edge(clk_i) then         -- rising clock edge
      if (s_error_flag_re = '1' and s_eye_check = '1') or s_load_eye = '1' then
        s_eye_values(1) <= s_eye_values(0);
        s_eye_values(0) <= s_eye_tap_count;
      end if;
    end if;
  end process p_eye_latcher;

  u_old_eye <= unsigned(s_eye_values(1));
  u_new_eye <= unsigned(s_eye_values(0));

  p_eye_loader : process(clk_i)         -- non serve per l' algoritmo
  begin
    for I in 1 to g_number_of_GCU loop
      if rising_edge(clk_i) then
        if s_cal_done = '1' then
          if s_sel = I then
            if u_new_eye > u_old_eye then
              eye_o(I*7 - 1 downto I*7 -7) <= s_eye_values(0)(6 downto 0);
            else
              eye_o(I*7 - 1 downto I*7 -7) <= s_eye_values(1)(6 downto 0);
            end if;

          -- da modificare
          end if;
        end if;
      end if;
    end loop;
  end process p_eye_loader;


  s_eye_zero <= '1' when u_eye_tap_count = 0 else '0';
  s_eye_one  <= '1' when u_eye_tap_count = 1 else '0';

--===================================================-- 
--                /2 (RIGHT SHIFT REGISTER)
--===================================================-- 
  p_right_shift : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if s_start = '1' then
        u_tap_shifted <= (others => '0');
      elsif s_shift = '1' then
        if u_old_eye > u_new_eye then
          u_tap_shifted <= u_new_eye + u_error_tap_count + x"28";  -- 40 taps
        -- to move about to the center mindind the error width
        else
          u_tap_shifted <= u_new_eye - x"28";
        end if;
      end if;
    end if;
  end process p_right_shift;

--===================================================-- 
--            MOVE TO THE BEST SAMPLING POINT
--===================================================-- 

  Inst_tap_countdown : entity work.countdown
    generic map(
      g_width    => 8,
      g_clk_rise => "TRUE"
      )
    port map(
      clk_i    => clk_i,
      reset_i  => s_start,
      load_i   => s_tap_decr_load,
      enable_i => s_decr_count,
      p_i      => std_logic_vector(u_tap_shifted),
      p_o      => s_tap_decr
      );

  p_best_sampling_point : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if s_tap_decr = x"00" then
        s_sampling_point <= '1';
      else
        s_sampling_point <= '0';
      end if;
    end if;
  end process p_best_sampling_point;
  debug_bit <= s_go;
--===================================================-- 
--                       TIMEOUT/FSM AUTO-RESET
--===================================================-- 
  p_bomb_count : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if s_start = '1' then
        u_bomb <= (others => '0');
      elsif s_lock = '1' then
        u_bomb <= u_bomb + 1;
      end if;
    end if;
  end process p_bomb_count;

  s_bomb_count <= std_logic_vector(u_bomb);

  p_bomb : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if s_bomb_count(28) = '1' then
        s_bomb <= '1';
      else
        s_bomb <= '0';
      end if;
    end if;
  end process p_bomb;

--===================================================-- 
--                        FSM
--===================================================-- 

  p_update_state : process(clk_i, rst_i)
  begin
    if rst_i = '1' or s_bomb = '1' then
      -- if rst_i = '1' then
      s_state <= st0_idle;
    elsif rising_edge(clk_i) then
      case s_state is
        ----
        when st0_idle =>
          if s_start = '1' then
            s_state <= st0_idle2;
          end if;
        ----
        when st0_idle2 =>
          if s_go = '1' then
            s_state <= st1_cb_req;
          end if;
        ----  
        when st1_cb_req =>
          if chb_grant_i = '1' then
            s_state <= st2_tap_reset;
          end if;
        ----
        when st2_tap_reset =>
          s_state <= st3_evaluate;
        ----
        when st3_evaluate =>
          if s_go = '1' then
            if s_tot_tap_count = x"7B" then
              s_state <= st9_load_eye;
            else
              if s_no_error = '0' then  -- we are in the error phase
                s_state <= st6_cb_req;
              else
                s_state <= st4_cb_req;
              end if;
            end if;
          end if;
        ----
        when st4_cb_req =>
          if chb_grant_i = '1' then
            s_state <= st5_tap_incr;
          end if;
        ----
        when st5_tap_incr =>
          s_state <= st3_evaluate;
        ----
        when st6_cb_req =>
          if chb_grant_i = '1' then
            s_state <= st7_tap_incr;
          end if;
        ----     
        when st7_tap_incr =>
          s_state <= st8_evaluate;
        ----
        when st8_evaluate =>
          if s_go = '1' then
            if s_tot_tap_count = x"7B" then
              s_state <= st9_load_eye;
            else
              if s_no_error = '1' then  -- we are in the eye phase
                s_state <= st4_cb_req;
              else
                s_state <= st6_cb_req;
              end if;
            end if;
          end if;
        ----
        when st9_load_eye =>
          -- if s_eye_zero = '1' or s_eye_one = '1' then
          --   s_state <= st0_idle;
          -- else
          s_state <= st10_shift;
        -- end if;
        ----     
        when st10_shift =>
          if s_go = '1' then
            s_state <= st11_load_decr;
          end if;
        ----     
        when st11_load_decr =>
          s_state <= st12_cb_req;
        ----
        when st12_cb_req =>
          if chb_grant_i = '1' then
            s_state <= st13_tap_decr;
          end if;
        ----
        when st13_tap_decr =>
          s_state <= st14_wait;
        ----
        when st14_wait =>
          if s_go = '1' then
            if s_sampling_point = '0' then
              s_state <= st12_cb_req;
            else
              s_state <= st15_cal_done;
            end if;
          end if;
        --
        when st15_cal_done =>
          s_state <= st0_idle;
        --
        when others =>
          s_state <= st0_idle;
      ----
      end case;
    end if;
  end process p_update_state;

  p_update_fsm_output : process(s_state)
  begin
    s_fsm_signals <= c_fsm_signals;
    case s_state is
      -------
      when st0_idle =>
        s_fsm_signals.debug <= b"00000";
      -------
      when st0_idle2 =>
        s_fsm_signals.debug        <= b"00000";
        s_fsm_signals.en_countdown <= '1';
      -------
      when st1_cb_req =>
        s_fsm_signals.debug       <= b"00001";
        s_fsm_signals.chb_request <= '1';
        s_fsm_signals.lock        <= '1';
      -------
      when st2_tap_reset =>
        s_fsm_signals.debug      <= b"00010";
        s_fsm_signals.lock       <= '1';
        s_fsm_signals.long_saddr <= s_tap_rst_reg;
        s_fsm_signals.long_data  <= x"00";
        s_fsm_signals.strobe     <= '1';
      -------
      when st3_evaluate =>
        s_fsm_signals.debug        <= b"00011";
        s_fsm_signals.lock         <= '1';
        s_fsm_signals.en_countdown <= '1';
        s_fsm_signals.error_flag   <= '0';
      -------
      when st4_cb_req =>
        s_fsm_signals.debug       <= b"00100";
        s_fsm_signals.lock        <= '1';
        s_fsm_signals.chb_request <= '1';
        s_fsm_signals.error_flag  <= '0';
      -------
      when st5_tap_incr =>
        s_fsm_signals.debug          <= b"00101";
        s_fsm_signals.lock           <= '1';
        s_fsm_signals.incr_eye_count <= '1';
        s_fsm_signals.long_saddr     <= s_tap_incr_reg;
        s_fsm_signals.long_data      <= x"00";
        s_fsm_signals.strobe         <= '1';
        s_fsm_signals.error_flag     <= '0';
      -------
      when st6_cb_req =>
        s_fsm_signals.debug       <= b"00110";
        s_fsm_signals.lock        <= '1';
        s_fsm_signals.chb_request <= '1';
        s_fsm_signals.error_flag  <= '1';
      -------
      when st7_tap_incr =>
        s_fsm_signals.debug          <= b"00111";
        s_fsm_signals.lock           <= '1';
        s_fsm_signals.incr_eye_count <= '1';
        s_fsm_signals.long_saddr     <= s_tap_incr_reg;
        s_fsm_signals.long_data      <= x"00";
        s_fsm_signals.strobe         <= '1';
        s_fsm_signals.error_flag     <= '1';
      -------
      when st8_evaluate =>
        s_fsm_signals.debug        <= b"01000";
        s_fsm_signals.lock         <= '1';
        s_fsm_signals.en_countdown <= '1';
        s_fsm_signals.error_flag   <= '1';
      -------
      when st9_load_eye =>
        s_fsm_signals.debug    <= b"01001";
        s_fsm_signals.lock     <= '1';
        s_fsm_signals.load_eye <= '1';
      -------
      when st10_shift =>
        s_fsm_signals.debug        <= b"01010";
        s_fsm_signals.lock         <= '1';
        s_fsm_signals.shift        <= '1';
        s_fsm_signals.en_countdown <= '1';
      -------
      when st11_load_decr =>
        s_fsm_signals.debug         <= b"01011";
        s_fsm_signals.lock          <= '1';
        s_fsm_signals.tap_decr_load <= '1';
      -------
      when st12_cb_req =>
        s_fsm_signals.debug       <= b"01100";
        s_fsm_signals.lock        <= '1';
        s_fsm_signals.chb_request <= '1';
      -------
      when st13_tap_decr =>
        s_fsm_signals.debug      <= b"01101";
        s_fsm_signals.lock       <= '1';
        s_fsm_signals.decr_count <= '1';
        s_fsm_signals.long_saddr <= s_tap_decr_reg;
        s_fsm_signals.long_data  <= x"00";
        -- s_fsm_signals.strobe_decr     <= '1';
        s_fsm_signals.strobe     <= '1';
      -------
      when st14_wait =>
        s_fsm_signals.debug        <= b"01110";
        s_fsm_signals.lock         <= '1';
        s_fsm_signals.en_countdown <= '1';
      --
      when st15_cal_done =>
        s_fsm_signals.lock     <= '1';
        s_fsm_signals.cal_done <= '1';

      when others =>

    end case;
  end process p_update_fsm_output;

  -- r_edge_detect_strobe : entity work.r_edge_detect
  --   generic map (
  --     g_clk_rise => "TRUE")
  --   port map (
  --     clk_i => clk_i,
  --     sig_i => s_fsm_signals.strobe_decr,
  --     sig_o => s_strobe_decr_re
  --     );

  -- r_edge_detect_decr_count : entity work.r_edge_detect
  --   generic map (
  --     g_clk_rise => "TRUE")
  --   port map (
  --     clk_i => clk_i,
  --     sig_i => s_decr_count,
  --     sig_o => s_decr_count_re
  --     );

  debug_fsm_o            <= s_fsm_signals.debug;
  s_lock                 <= s_fsm_signals.lock;
  ttc_long_o.long_subadd <= s_fsm_signals.long_saddr;
  ttc_long_o.long_data   <= s_fsm_signals.long_data;
  ttc_long_o.long_strobe <= s_fsm_signals.strobe;
  -- s_long_strobe_to_re    <= s_fsm_signals.strobe;
  chb_req_o              <= s_fsm_signals.chb_request;
  s_load_eye             <= s_fsm_signals.load_eye;
  s_shift                <= s_fsm_signals.shift;
  s_tap_decr_load        <= s_fsm_signals.tap_decr_load;
  s_enable_countdown     <= s_fsm_signals.en_countdown;
  s_incr_eye_count       <= s_fsm_signals.incr_eye_count;
  s_decr_count           <= s_fsm_signals.decr_count;
  s_error_flag           <= s_fsm_signals.error_flag;
  s_cal_done             <= s_fsm_signals.cal_done;

  cal_done     <= s_cal_done;
  debug_bomb_o <= s_bomb;
-------------------debug----------------
--p_incr_count : process(clk_i)
--begin
--   if rising_edge(clk_i) then
--     if s_start = '1' then
--       u_strobe_count <= (others => '0');
--    elsif s_fsm_signals.strobe = '1' then
--       u_strobe_count <= u_strobe_count + 1;
--     end if;
--  end if;
--end process p_incr_count;
--debug_strobe <= std_logic_vector(u_strobe_count);
  debug_error  <= s_sum_total;
end rtl;

