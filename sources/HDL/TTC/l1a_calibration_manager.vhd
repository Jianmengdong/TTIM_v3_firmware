-------------------------------------------------------------------------------
-- Title      : l1a calibration manager
-- Project    : 
-------------------------------------------------------------------------------
-- File       : l1a_calibration_manager.vhd
-- Author     : Filippo Marini   <filippo.marini@pd.infn.it>
-- Company    : Universita degli studi di Padova
-- Created    : 2019-09-16
-- Last update: 2019-09-18
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2019 Universita degli studi di Padova
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-09-16  1.0      filippo Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.TTIM_pack.all;

entity l1a_calibration_manager is
  generic(
    g_number_of_GCU : positive := 3
    );
  port (
    clk_i            : in  std_logic;
    rst_i            : in  std_logic;
    l1a_go_prbs      : in  std_logic;
    gcu_sel_i        : in  std_logic_vector(5 downto 0);
    chb_grant_i      : in  std_logic;
    chb_req_o        : out std_logic;
    gcu_id_i         : in  t_array16(47 downto 0);
    l1a_cal_done     : in  std_logic;
    ttc_long_o       : out t_ttc_long_frame;
    l1a_tap_calib_en : out std_logic
    );
end entity l1a_calibration_manager;

architecture rtl of l1a_calibration_manager is

  type t_manager_state is (st0_idle,
                           st1_cb_req,
                           st2_go_prbs,
                           st3_wait,
                           st4_start_calibration,
                           st5_cb_req,
                           st6_dont_go_prbs,
                           st7_wait
                           );

  signal s_manager_state : t_manager_state;

  type t_fsm_signals is record
    lock              : std_logic;
    chb_req           : std_logic;
    long_data         : std_logic_vector(7 downto 0);
    long_saddr        : std_logic_vector(7 downto 0);
    strobe            : std_logic;
    en_countdown      : std_logic;
    start_calibration : std_logic;
  end record t_fsm_signals;

  signal s_fsm_signals : t_fsm_signals;

  constant c_fsm_signals : t_fsm_signals := (
    lock              => '0',
    chb_req           => '0',
    long_data         => (others => '0'),
    long_saddr        => (others => '0'),
    strobe            => '0',
    en_countdown      => '0',
    start_calibration => '0'
    );

  --type t_gcuid_array is array (47 downto 0) of std_logic_vector (15 downto 0);

  signal s_gcu_id             : t_array16(47 downto 0);
  signal s_sel                : unsigned(5 downto 0);
  signal s_enable_countdown   : std_logic;
  signal s_count              : std_logic_vector(31 downto 0);
  signal s_l1a_go_prbs_re     : std_logic;
  signal u_bomb               : unsigned(31 downto 0);
  signal s_bomb_count         : std_logic_vector(31 downto 0);
  signal s_bomb               : std_logic;
  signal s_lock               : std_logic;
  signal s_go                 : std_logic;

  attribute mark_debug                    : string;
  attribute mark_debug of s_manager_state : signal is "true";
  -- attribute mark_debug of s_bomb          : signal is "true";


begin  -- architecture rtl

  -----------------------------------------------------------------------------
  -- Select GCU
  -----------------------------------------------------------------------------
  --GEN_GCU_ID_ARRAY_1 :
  --for I in 1 to g_number_of_GCU generate
    s_gcu_id <= gcu_id_i;
  --end generate GEN_GCU_ID_ARRAY_1;

  -- GEN_FILL_ARRAY : if g_number_of_GCU < 48 generate

    -- GEN_GCU_ID_ARRAY_2 :
    -- for I in g_number_of_GCU to 47 generate
      -- s_gcu_id(I)    <= x"ffff";
    -- end generate GEN_GCU_ID_ARRAY_2;

  -- end generate GEN_FILL_ARRAY;

  process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      s_sel <= (others => '0');
    elsif rising_edge(clk_i) then
      if s_l1a_go_prbs_re = '1' and s_lock = '0' then
        s_sel <= unsigned(gcu_sel_i) + 1;
      end if;
    end if;
  end process;

  process(s_sel, s_gcu_id)
  begin
    case to_integer(s_sel) is
      when 0 =>                         -- no GCU selected for calibration
        ttc_long_o.long_address <= x"ffff";
      when 1 =>
        ttc_long_o.long_address <= s_gcu_id(0);
      when 2 =>
        ttc_long_o.long_address <= s_gcu_id(1);

      when 3 =>
        ttc_long_o.long_address <= s_gcu_id(2);

      when 4 =>
        ttc_long_o.long_address <= s_gcu_id(3);

      when 5 =>
        ttc_long_o.long_address <= s_gcu_id(4);

      when 6 =>
        ttc_long_o.long_address <= s_gcu_id(5);

      when 7 =>
        ttc_long_o.long_address <= s_gcu_id(6);

      when 8 =>
        ttc_long_o.long_address <= s_gcu_id(7);

      when 9 =>
        ttc_long_o.long_address <= s_gcu_id(8);

      when 10 =>
        ttc_long_o.long_address <= s_gcu_id(9);

      when 11 =>
        ttc_long_o.long_address <= s_gcu_id(10);

      when 12 =>
        ttc_long_o.long_address <= s_gcu_id(11);

      when 13 =>
        ttc_long_o.long_address <= s_gcu_id(12);

      when 14 =>
        ttc_long_o.long_address <= s_gcu_id(13);

      when 15 =>
        ttc_long_o.long_address <= s_gcu_id(14);

      when 16 =>
        ttc_long_o.long_address <= s_gcu_id(15);

      when 17 =>
        ttc_long_o.long_address <= s_gcu_id(16);

      when 18 =>
        ttc_long_o.long_address <= s_gcu_id(17);

      when 19 =>
        ttc_long_o.long_address <= s_gcu_id(18);

      when 20 =>
        ttc_long_o.long_address <= s_gcu_id(19);

      when 21 =>
        ttc_long_o.long_address <= s_gcu_id(20);

      when 22 =>
        ttc_long_o.long_address <= s_gcu_id(21);

      when 23 =>
        ttc_long_o.long_address <= s_gcu_id(22);

      when 24 =>
        ttc_long_o.long_address <= s_gcu_id(23);

      when 25 =>
        ttc_long_o.long_address <= s_gcu_id(24);

      when 26 =>
        ttc_long_o.long_address <= s_gcu_id(25);

      when 27 =>
        ttc_long_o.long_address <= s_gcu_id(26);

      when 28 =>
        ttc_long_o.long_address <= s_gcu_id(27);

      when 29 =>
        ttc_long_o.long_address <= s_gcu_id(28);

      when 30 =>
        ttc_long_o.long_address <= s_gcu_id(29);

      when 31 =>
        ttc_long_o.long_address <= s_gcu_id(30);

      when 32 =>
        ttc_long_o.long_address <= s_gcu_id(31);

      when 33 =>
        ttc_long_o.long_address <= s_gcu_id(32);

      when 34 =>
        ttc_long_o.long_address <= s_gcu_id(33);

      when 35 =>
        ttc_long_o.long_address <= s_gcu_id(34);

      when 36 =>
        ttc_long_o.long_address <= s_gcu_id(35);

      when 37 =>
        ttc_long_o.long_address <= s_gcu_id(36);

      when 38 =>
        ttc_long_o.long_address <= s_gcu_id(37);

      when 39 =>
        ttc_long_o.long_address <= s_gcu_id(38);

      when 40 =>
        ttc_long_o.long_address <= s_gcu_id(39);

      when 41 =>
        ttc_long_o.long_address <= s_gcu_id(40);

      when 42 =>
        ttc_long_o.long_address <= s_gcu_id(41);

      when 43 =>
        ttc_long_o.long_address <= s_gcu_id(42);

      when 44 =>
        ttc_long_o.long_address <= s_gcu_id(43);

      when 45 =>
        ttc_long_o.long_address <= s_gcu_id(44);

      when 46 =>
        ttc_long_o.long_address <= s_gcu_id(45);

      when 47 =>
        ttc_long_o.long_address <= s_gcu_id(46);

      when 48 =>
        ttc_long_o.long_address <= s_gcu_id(47);

      when others =>
        ttc_long_o.long_address <= x"ffff";
    end case;

  end process;

  -----------------------------------------------------------------------------
  -- Countdown
  -----------------------------------------------------------------------------
  Inst_countdown : entity work.countdown
    generic map(
      g_width    => 32,
      g_clk_rise => "TRUE"
      )
    port map(
      clk_i    => clk_i,
      reset_i  => rst_i,
      load_i   => chb_grant_i,
      enable_i => s_enable_countdown,
      p_i      => x"00020000",          -- wait for ~ 131us = 8000
      p_o      => s_count
      );

  p_go : process (clk_i) is
  begin  -- process p_go
    if rising_edge(clk_i) then          -- rising clock edge
      if s_count = x"00000001" then
        s_go <= '1';
      else
        s_go <= '0';
      end if;
    end if;
  end process p_go;

  -----------------------------------------------------------------------------
  -- Timeout
  -----------------------------------------------------------------------------
  p_bomb_count : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if s_l1a_go_prbs_re = '1' then
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
      if s_bomb_count(30) = '1' then
        s_bomb <= '1';
      else
        s_bomb <= '0';
      end if;
    end if;
  end process p_bomb;

  -----------------------------------------------------------------------------
  -- Rising edge detector for going prbs
  -----------------------------------------------------------------------------
  r_edge_detect_go_prbs : entity work.r_edge_detect
    generic map (
      g_clk_rise => "TRUE"
      )
    port map (
      clk_i => clk_i,
      sig_i => l1a_go_prbs,
      sig_o => s_l1a_go_prbs_re
      );

  -----------------------------------------------------------------------------
  -- FSM
  -----------------------------------------------------------------------------
  p_update_state : process (clk_i, rst_i) is
  begin  -- process p_update_state
    -- if rst_i = '1' or s_bomb = '1' then  -- asynchronous reset (active high)
    if rst_i = '1' then  -- asynchronous reset (active high)
      s_manager_state <= st0_idle;
    elsif rising_edge(clk_i) then        -- rising clock edge
      case s_manager_state is
        --
        when st0_idle =>
          if s_l1a_go_prbs_re = '1' then
            s_manager_state <= st1_cb_req;
          end if;
        --
        when st1_cb_req =>
          if chb_grant_i = '1' then
            s_manager_state <= st2_go_prbs;
          end if;
        --
        when st2_go_prbs =>
          s_manager_state <= st3_wait;
        --
        when st3_wait =>
          if s_go = '1' then
            s_manager_state <= st4_start_calibration;
          end if;
        --
        when st4_start_calibration =>
          if l1a_cal_done = '1' then
            s_manager_state <= st5_cb_req;
          end if;
        --
        when st5_cb_req =>
          if chb_grant_i = '1' then
            s_manager_state <= st6_dont_go_prbs;
          end if;
        --
        when st6_dont_go_prbs =>
          s_manager_state <= st7_wait;
        --
        when st7_wait =>
          if s_go = '1' then
            s_manager_state <= st0_idle;
          end if;
        --
        when others =>
          s_manager_state <= st0_idle;
      --
      end case;
    end if;
  end process p_update_state;

  p_update_output : process (s_manager_state) is
  begin  -- process p_update_output
    s_fsm_signals <= c_fsm_signals;
    case s_manager_state is
      --
      when st0_idle =>
        null;
      --
      when st1_cb_req =>
        s_fsm_signals.chb_req <= '1';
        s_fsm_signals.lock    <= '1';
      --
      when st2_go_prbs =>
        s_fsm_signals.lock       <= '1';
        s_fsm_signals.long_saddr <= x"20";
        s_fsm_signals.long_data  <= x"00";
        s_fsm_signals.strobe     <= '1';
      --
      when st3_wait =>
        s_fsm_signals.lock         <= '1';
        s_fsm_signals.en_countdown <= '1';
      --
      when st4_start_calibration =>
        s_fsm_signals.lock              <= '1';
        s_fsm_signals.start_calibration <= '1';
      --
      when st5_cb_req =>
        s_fsm_signals.lock    <= '1';
        s_fsm_signals.chb_req <= '1';
      --
      when st6_dont_go_prbs =>
        s_fsm_signals.lock       <= '1';
        s_fsm_signals.long_saddr <= x"20";
        s_fsm_signals.long_data  <= x"00";
        s_fsm_signals.strobe     <= '1';
      --
      when st7_wait =>
        s_fsm_signals.lock         <= '1';
        s_fsm_signals.en_countdown <= '1';
      --
      when others => null;
    end case;
  end process p_update_output;

  s_enable_countdown     <= s_fsm_signals.en_countdown;
  s_lock                 <= s_fsm_signals.lock;
  ttc_long_o.long_subadd <= s_fsm_signals.long_saddr;
  ttc_long_o.long_data   <= s_fsm_signals.long_data;
  ttc_long_o.long_strobe <= s_fsm_signals.strobe;
  chb_req_o              <= s_fsm_signals.chb_req;
  l1a_tap_calib_en       <= s_fsm_signals.start_calibration;

end architecture rtl;
