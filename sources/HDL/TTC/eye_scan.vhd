----------------------------------------------------------------------------------
-- Company:        INFN - LNL
-- Engineer:       Davide Pedretti
-- Create Date:    13:12:50 10/18/2017 
-- Module Name:    eye scanner - rtl 
-- Project Name:   BEC JUNO
-- Tool versions:  ISE 14.7
-- Revision 0.01 - File Created
-- Description:    
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.TTIM_pack.all;

entity eye_scan is
  generic(
    g_number_of_GCU : positive := 3;
    calibrating_ttc : boolean := true
    );
  port (clk_i         : in  std_logic;
        rst_i         : in  std_logic;
        tap_rst_i     : in  std_logic;  -- start GCUx tap calibration; transition from 0 to 1
        tap_incr_i    : in  std_logic;
        gcu_sel_i     : in  std_logic_vector (5 downto 0);  -- GCUx select; from 1 to 48. 0 = no GCU selected
        chb_grant_i   : in  std_logic;  -- CHB port 4 channel grant flag
        chb_req_o     : out std_logic;  -- CHB port 4 request 
        gcu_id_i      : in  t_array16(47 downto 0);  -- GCUs IDs
        ttc_long_o    : out t_ttc_long_frame;  -- ttc long frame CHB port 4
        comm_err_i    : in  std_logic_vector (g_number_of_GCU*32 - 1 downto 0);
        error_count_o : out std_logic_vector (31 downto 0);  -- GCUx opening of the eye
        debug_fsm_o   : out std_logic_vector (3 downto 0)
        );
end eye_scan;

architecture rtl of eye_scan is

  type t_gcuid_array is array (47 downto 0) of std_logic_vector (15 downto 0);
  type t_gcuerror_array is array (47 downto 0) of std_logic_vector (31 downto 0);

  type t_state is (st0_idle,            -- b"00000"
                   st1_cb_req,          -- b"00001"
                   st2_tap_reset,       -- b"00010"
                   st3_wait,            -- b"00011"
                   st4_load,            -- b"00100"
                   st5_cb_req,          -- b"00101"
                   st6_tap_incr,        -- b"00110"
                   st7_wait,            -- b"00111"
                   st8_load             -- b"01000"
                   );

  signal s_state            : t_state;
  signal s_gcu_id           : t_array16(47 downto 0);
  signal s_gcu_error        : t_gcuerror_array;
  signal s_sel              : unsigned(5 downto 0);
  signal s_tap_rst          : std_logic;
  signal s_tap_incr         : std_logic;
  signal s_error            : std_logic_vector (31 downto 0);
  signal s_count            : std_logic_vector (31 downto 0);
  signal s_go               : std_logic;
  signal s_enable_countdown : std_logic;
  signal s_bomb             : std_logic;
  signal s_lock             : std_logic;
  signal s_load             : std_logic;
  signal u_bomb             : unsigned(30 downto 0);
  signal s_bomb_count       : std_logic_vector(30 downto 0);
  signal s_tap_incr_reg     : std_logic_vector(7 downto 0);
  signal s_tap_rst_reg      : std_logic_vector(7 downto 0);

begin 

  -----------------------------------------------------------------------------
  -- TTC or L1A?
  -----------------------------------------------------------------------------
  s_tap_incr_reg <= x"1a" when calibrating_ttc else
                    x"1d";
  
  s_tap_rst_reg <= x"1c" when calibrating_ttc else
                   x"1f";

  GEN_GCU_ID_ARRAY_1 :
  for I in 1 to g_number_of_GCU generate
    --s_gcu_id(I - 1)    <= gcu_id_i(I*16 -1 downto I*16 -16);
    s_gcu_error(I - 1) <= comm_err_i(I*32 -1 downto I*32 -32);
  end generate GEN_GCU_ID_ARRAY_1;
s_gcu_id <= gcu_id_i;
  GEN_FILL_ARRAY : if g_number_of_GCU < 48 generate

    GEN_GCU_ID_ARRAY_2 :
    for I in g_number_of_GCU to 47 generate
      --s_gcu_id(I)    <= x"ffff";
      s_gcu_error(I) <= x"00000000";
    end generate GEN_GCU_ID_ARRAY_2;

  end generate GEN_FILL_ARRAY;

  process(clk_i, rst_i)
  begin
    if rst_i = '1' then
      s_sel <= (others => '0');
    elsif rising_edge(clk_i) then
      if (s_tap_rst = '1' or s_tap_incr = '1') and s_lock = '0' then
        s_sel <= unsigned(gcu_sel_i) + 1;
      end if;
    end if;
  end process;

  process(s_sel, s_gcu_id, s_gcu_error)
  begin
    case to_integer(s_sel) is
      when 0 =>                         -- no GCU selected for calibration
        ttc_long_o.long_address <= x"ffff";
        s_error                 <= x"00000000";

      when 1 =>
        ttc_long_o.long_address <= s_gcu_id(0);
        s_error                 <= s_gcu_error(0);

      when 2 =>
        ttc_long_o.long_address <= s_gcu_id(1);
        s_error                 <= s_gcu_error(1);

      when 3 =>
        ttc_long_o.long_address <= s_gcu_id(2);
        s_error                 <= s_gcu_error(2);

      when 4 =>
        ttc_long_o.long_address <= s_gcu_id(3);
        s_error                 <= s_gcu_error(3);

      when 5 =>
        ttc_long_o.long_address <= s_gcu_id(4);
        s_error                 <= s_gcu_error(4);

      when 6 =>
        ttc_long_o.long_address <= s_gcu_id(5);
        s_error                 <= s_gcu_error(5);

      when 7 =>
        ttc_long_o.long_address <= s_gcu_id(6);
        s_error                 <= s_gcu_error(6);

      when 8 =>
        ttc_long_o.long_address <= s_gcu_id(7);
        s_error                 <= s_gcu_error(7);

      when 9 =>
        ttc_long_o.long_address <= s_gcu_id(8);
        s_error                 <= s_gcu_error(8);

      when 10 =>
        ttc_long_o.long_address <= s_gcu_id(9);
        s_error                 <= s_gcu_error(9);

      when 11 =>
        ttc_long_o.long_address <= s_gcu_id(10);
        s_error                 <= s_gcu_error(10);

      when 12 =>
        ttc_long_o.long_address <= s_gcu_id(11);
        s_error                 <= s_gcu_error(11);

      when 13 =>
        ttc_long_o.long_address <= s_gcu_id(12);
        s_error                 <= s_gcu_error(12);

      when 14 =>
        ttc_long_o.long_address <= s_gcu_id(13);
        s_error                 <= s_gcu_error(13);

      when 15 =>
        ttc_long_o.long_address <= s_gcu_id(14);
        s_error                 <= s_gcu_error(14);

      when 16 =>
        ttc_long_o.long_address <= s_gcu_id(15);
        s_error                 <= s_gcu_error(15);

      when 17 =>
        ttc_long_o.long_address <= s_gcu_id(16);
        s_error                 <= s_gcu_error(16);

      when 18 =>
        ttc_long_o.long_address <= s_gcu_id(17);
        s_error                 <= s_gcu_error(17);

      when 19 =>
        ttc_long_o.long_address <= s_gcu_id(18);
        s_error                 <= s_gcu_error(18);

      when 20 =>
        ttc_long_o.long_address <= s_gcu_id(19);
        s_error                 <= s_gcu_error(19);

      when 21 =>
        ttc_long_o.long_address <= s_gcu_id(20);
        s_error                 <= s_gcu_error(20);

      when 22 =>
        ttc_long_o.long_address <= s_gcu_id(21);
        s_error                 <= s_gcu_error(21);

      when 23 =>
        ttc_long_o.long_address <= s_gcu_id(22);
        s_error                 <= s_gcu_error(22);

      when 24 =>
        ttc_long_o.long_address <= s_gcu_id(23);
        s_error                 <= s_gcu_error(23);

      when 25 =>
        ttc_long_o.long_address <= s_gcu_id(24);
        s_error                 <= s_gcu_error(24);

      when 26 =>
        ttc_long_o.long_address <= s_gcu_id(25);
        s_error                 <= s_gcu_error(25);

      when 27 =>
        ttc_long_o.long_address <= s_gcu_id(26);
        s_error                 <= s_gcu_error(26);

      when 28 =>
        ttc_long_o.long_address <= s_gcu_id(27);
        s_error                 <= s_gcu_error(27);

      when 29 =>
        ttc_long_o.long_address <= s_gcu_id(28);
        s_error                 <= s_gcu_error(28);

      when 30 =>
        ttc_long_o.long_address <= s_gcu_id(29);
        s_error                 <= s_gcu_error(29);

      when 31 =>
        ttc_long_o.long_address <= s_gcu_id(30);
        s_error                 <= s_gcu_error(30);

      when 32 =>
        ttc_long_o.long_address <= s_gcu_id(31);
        s_error                 <= s_gcu_error(31);

      when 33 =>
        ttc_long_o.long_address <= s_gcu_id(32);
        s_error                 <= s_gcu_error(32);

      when 34 =>
        ttc_long_o.long_address <= s_gcu_id(33);
        s_error                 <= s_gcu_error(33);

      when 35 =>
        ttc_long_o.long_address <= s_gcu_id(34);
        s_error                 <= s_gcu_error(34);

      when 36 =>
        ttc_long_o.long_address <= s_gcu_id(35);
        s_error                 <= s_gcu_error(35);

      when 37 =>
        ttc_long_o.long_address <= s_gcu_id(36);
        s_error                 <= s_gcu_error(36);

      when 38 =>
        ttc_long_o.long_address <= s_gcu_id(37);
        s_error                 <= s_gcu_error(37);

      when 39 =>
        ttc_long_o.long_address <= s_gcu_id(38);
        s_error                 <= s_gcu_error(38);

      when 40 =>
        ttc_long_o.long_address <= s_gcu_id(39);
        s_error                 <= s_gcu_error(39);

      when 41 =>
        ttc_long_o.long_address <= s_gcu_id(40);
        s_error                 <= s_gcu_error(40);

      when 42 =>
        ttc_long_o.long_address <= s_gcu_id(41);
        s_error                 <= s_gcu_error(41);

      when 43 =>
        ttc_long_o.long_address <= s_gcu_id(42);
        s_error                 <= s_gcu_error(42);

      when 44 =>
        ttc_long_o.long_address <= s_gcu_id(43);
        s_error                 <= s_gcu_error(43);

      when 45 =>
        ttc_long_o.long_address <= s_gcu_id(44);
        s_error                 <= s_gcu_error(44);

      when 46 =>
        ttc_long_o.long_address <= s_gcu_id(45);
        s_error                 <= s_gcu_error(45);

      when 47 =>
        ttc_long_o.long_address <= s_gcu_id(46);
        s_error                 <= s_gcu_error(46);

      when 48 =>
        ttc_long_o.long_address <= s_gcu_id(47);
        s_error                 <= s_gcu_error(47);

      when others =>
        ttc_long_o.long_address <= x"ffff";
        s_error                 <= x"00000000";
    end case;

  end process;

  Inst_tap_rst_rise_edge_detect : entity work.r_edge_detect
    generic map(
      g_clk_rise => "TRUE"
      )
    port map(
      clk_i => clk_i,
      sig_i => tap_rst_i,
      sig_o => s_tap_rst
      );

  Inst_tap_incr_rise_edge_detect : entity work.r_edge_detect
    generic map(
      g_clk_rise => "TRUE"
      )
    port map(
      clk_i => clk_i,
      sig_i => tap_incr_i,
      sig_o => s_tap_incr
      );

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
      p_i      => x"00000400",          -- wait for ~ 262us = 4000
      p_o      => s_count
      );

  p_go : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if s_count = x"00000001" then
        s_go <= '1';
      else
        s_go <= '0';
      end if;
    end if;
  end process p_go;

  p_bomb_count : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if s_lock = '0' then
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


  p_load : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if s_load = '1' then
        error_count_o <= s_error;
      else
        error_count_o <= s_error;
      end if;
    end if;
  end process p_load;

  p_update_state : process(clk_i, rst_i)
  begin
    if rst_i = '1' or s_bomb = '1' then
      s_state <= st0_idle;
    elsif rising_edge(clk_i) then
      case s_state is
        ----
        when st0_idle =>
          if s_tap_rst = '1' then
            s_state <= st1_cb_req;
          elsif s_tap_incr = '1' then
            s_state <= st5_cb_req;
          end if;
        ----  
        when st1_cb_req =>
          if chb_grant_i = '1' then
            s_state <= st2_tap_reset;
          end if;
        ----
        when st2_tap_reset =>
          s_state <= st3_wait;
        ----
        when st3_wait =>
          if s_go = '1' then
            s_state <= st4_load;
          end if;
        ----
        when st4_load =>
          s_state <= st0_idle;
        ----
        when st5_cb_req =>
          if chb_grant_i = '1' then
            s_state <= st6_tap_incr;
          end if;
        ----
        when st6_tap_incr =>
          s_state <= st7_wait;
        ----
        when st7_wait =>
          if s_go = '1' then
            s_state <= st8_load;
          end if;
        ----  
        when st8_load =>
          s_state <= st0_idle;
        ----       
        when others =>
          s_state <= st0_idle;

      end case;
    end if;
  end process p_update_state;

  p_update_fsm_output : process(s_state)
  begin
    case s_state is
      -------
      when st0_idle =>
        s_lock                 <= '0';
        s_load                 <= '0';
        s_enable_countdown     <= '0';
        chb_req_o              <= '0';
        ttc_long_o.long_strobe <= '0';
        ttc_long_o.long_data   <= x"00";
        ttc_long_o.long_subadd <= x"00";
        debug_fsm_o            <= b"0000";
      -------
      when st1_cb_req =>
        s_lock                 <= '1';
        s_load                 <= '0';
        s_enable_countdown     <= '0';
        chb_req_o              <= '1';
        ttc_long_o.long_strobe <= '0';
        ttc_long_o.long_data   <= x"00";
        ttc_long_o.long_subadd <= x"00";
        debug_fsm_o            <= b"0001";
      -------
      when st2_tap_reset =>
        s_lock                 <= '1';
        s_load                 <= '0';
        s_enable_countdown     <= '0';
        chb_req_o              <= '0';
        ttc_long_o.long_strobe <= '1';
        ttc_long_o.long_data   <= x"00";
        ttc_long_o.long_subadd <= s_tap_rst_reg;
        debug_fsm_o            <= b"0010";
      -------    
      when st3_wait =>
        s_lock                 <= '1';
        s_load                 <= '0';
        s_enable_countdown     <= '1';
        chb_req_o              <= '0';
        ttc_long_o.long_strobe <= '0';
        ttc_long_o.long_data   <= x"00";
        ttc_long_o.long_subadd <= x"00";
        debug_fsm_o            <= b"0011";
      -------
      when st4_load =>
        s_lock                 <= '1';
        s_load                 <= '1';
        s_enable_countdown     <= '0';
        chb_req_o              <= '0';
        ttc_long_o.long_strobe <= '0';
        ttc_long_o.long_data   <= x"00";
        ttc_long_o.long_subadd <= x"00";
        debug_fsm_o            <= b"0100";
      -------
      when st5_cb_req =>
        s_lock                 <= '1';
        s_load                 <= '0';
        s_enable_countdown     <= '0';
        chb_req_o              <= '1';
        ttc_long_o.long_strobe <= '0';
        ttc_long_o.long_data   <= x"00";
        ttc_long_o.long_subadd <= x"00";
        debug_fsm_o            <= b"0101";
      -------
      when st6_tap_incr =>
        s_lock                 <= '1';
        s_load                 <= '0';
        s_enable_countdown     <= '0';
        chb_req_o              <= '0';
        ttc_long_o.long_strobe <= '1';
        ttc_long_o.long_data   <= x"00";
        ttc_long_o.long_subadd <= s_tap_incr_reg;
        debug_fsm_o            <= b"0110";
      -------    
      when st7_wait =>
        s_lock                 <= '1';
        s_load                 <= '0';
        s_enable_countdown     <= '1';
        chb_req_o              <= '0';
        ttc_long_o.long_strobe <= '0';
        ttc_long_o.long_data   <= x"00";
        ttc_long_o.long_subadd <= x"00";
        debug_fsm_o            <= b"0111";
      -------
      when st8_load =>
        s_lock                 <= '1';
        s_load                 <= '1';
        s_enable_countdown     <= '0';
        chb_req_o              <= '0';
        ttc_long_o.long_strobe <= '0';
        ttc_long_o.long_data   <= x"00";
        ttc_long_o.long_subadd <= x"00";
        debug_fsm_o            <= b"1000";
      -------
      when others =>
        s_lock                 <= '0';
        s_load                 <= '0';
        s_enable_countdown     <= '0';
        chb_req_o              <= '0';
        ttc_long_o.long_strobe <= '0';
        ttc_long_o.long_data   <= x"00";
        ttc_long_o.long_subadd <= x"00";
        debug_fsm_o            <= b"1111";
    end case;
  end process p_update_fsm_output;


end rtl;

