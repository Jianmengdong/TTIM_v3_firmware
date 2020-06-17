-------------------------------------------------------------------------------
-- Title      : ttc_trg_time
-- Project    : 
-------------------------------------------------------------------------------
-- File       : ttc_trg_time.vhd
-- Author     : Filippo Marini
-- Company    : Unipd
-- Created    : 2019-04-16
-- Last update: 2019-10-28
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Send trigger timestamp via TTC
-------------------------------------------------------------------------------
-- Copyright (c) 2019 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-04-16  1.0      filippo	Created
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.TTIM_pack.all;

entity ttc_trg_time is 
   
  port (
    clk_i           : in  std_logic;
    rst_i           : in  std_logic;
    ttctx_ready_i   : in  std_logic;
    local_time_i    : in  std_logic_vector(47 downto 0);
    local_trigger_i : in  std_logic;
    chb_grant_i     : in  std_logic;
    chb_req_o       : out std_logic;
    ttc_long_o      : out t_ttc_long_frame;
   -- debug
    s_local_trigger_pulse_o : out std_logic;
    time_to_send    : out std_logic_vector(31 downto 0));
  

end entity ttc_trg_time;

architecture  rtl of ttc_trg_time is 

  signal s_trg_timestamp : std_logic_vector(47 downto 0);

  type t_trg_time_fsm is (st0_idle,
                          st0_catch_trg_timestamp,
                          st1_verify_txready,
                          st2_chb_req,
                          st3_time_byte_0,
                          st4_chb_req,
                          st5_time_byte_1,
                          st6_chb_req,
                          st7_time_byte_2,
                          st8_chb_req,
                          st9_time_byte_3,
                          st10_chb_req,
                          st11_time_byte_4,
                          st12_chb_req,
                          st13_time_byte_5
                          );

  signal s_state : t_trg_time_fsm;
  signal s_tx_ready : std_logic;
  signal s_ttctx_ready : std_logic;
  signal s_strobe : std_logic;
  signal s_local_trigger_pulse : std_logic;
  --attribute dont_touch : string;
  --attribute mark_debug : string;
  --attribute dont_touch of s_trg_timestamp : signal is "true";
  --attribute mark_debug of s_trg_timestamp : signal is "true";

begin  -- architecture  rtl

  s_ttctx_ready <= ttctx_ready_i;
  time_to_send <= s_trg_timestamp(31 downto 0);

  -----------------------------------------------------------------------------
  -- Trigger pulse generator
  -----------------------------------------------------------------------------
  Inst_strobe_rise_edge_detect : entity work.r_edge_detect
		generic map(
      g_clk_rise  => "TRUE"
      )
		port map(
      clk_i => clk_i,  
      sig_i => local_trigger_i,
      sig_o => s_local_trigger_pulse
      );
-------------------------------------------------------------------------------
-- test debug
-------------------------------------------------------------------------------
  s_local_trigger_pulse_o <= s_local_trigger_pulse;
  ------------------------
  -- Strobe Generator
	------------------------
  Inst_trigger_rise_edge_detect : entity work.r_edge_detect
		generic map(
      g_clk_rise  => "TRUE"
      )
		port map(
      clk_i => clk_i,  
      sig_i => s_strobe,
      sig_o => ttc_long_o.long_strobe
      );

-- purpose: catch local time when triggered
-- should change this to fifo. When fifo not empty, start timestamp long frame
-- sending process.
-- type   : sequential
  p_catch_trg_timestamp : process (clk_i, rst_i) is
  begin  -- process
    if rst_i = '1' then                   -- asynchronous reset (active high)
      s_trg_timestamp <= (others => '0');
    elsif rising_edge(clk_i) then  -- rising clock edge
      if s_local_trigger_pulse = '1' then
        s_trg_timestamp <= local_time_i;
      end if;
    end if;
  end process;

-- purpose: FSM
-- type   : sequential
  p_update_state : process (clk_i, rst_i) is
  begin  -- process
    if rst_i = '1' then                   -- asynchronous reset (active low)
      s_state <= st0_idle;
    elsif rising_edge(clk_i) then  -- rising clock edge
      case s_state is

        when st0_idle =>
          if s_local_trigger_pulse = '1' then
            s_state <= st1_verify_txready;
          end if;

        when st1_verify_txready =>
          if s_ttctx_ready = '1' then
            s_state <= st2_chb_req;
          end if;

        when st2_chb_req =>
          if chb_grant_i = '1' then
            s_state <= st3_time_byte_0;
          end if;

        when st3_time_byte_0 =>
          if chb_grant_i = '0' then
            s_state <= st4_chb_req;
          end if;

        when st4_chb_req =>
          if chb_grant_i = '1' then
            s_state <= st5_time_byte_1;
          end if;

        when st5_time_byte_1 =>
          if chb_grant_i = '0' then
            s_state <= st6_chb_req;
          end if;

        when st6_chb_req =>
          if chb_grant_i = '1' then
            s_state <= st7_time_byte_2;
          end if;

        when st7_time_byte_2 =>
          if  chb_grant_i = '0' then
            s_state <= st8_chb_req;
          end if;

        when st8_chb_req =>
          if chb_grant_i = '1' then
            s_state <= st9_time_byte_3;
          end if;

        when st9_time_byte_3 =>
          if chb_grant_i = '0' then
            s_state <= st10_chb_req;
          end if;

        when st10_chb_req =>
          if chb_grant_i = '1' then
            s_state <= st11_time_byte_4;
          end if;
        when st11_time_byte_4 =>
          if chb_grant_i = '0' then
            s_state <= st12_chb_req;
          end if;

        when st12_chb_req =>
          if chb_grant_i = '1' then
            s_state <= st13_time_byte_5;
          end if;

        when st13_time_byte_5 =>
          if chb_grant_i = '0' then
            s_state <= st0_idle;
          end if;

        when others =>
          s_state <= st0_idle;
      end case;
    end if;
  end process;

-- purpose: update fsm output
-- type   : combinational
-- inputs : s_state
-- outputs: 
  p_update_fms_output : process (s_state, s_trg_timestamp(15 downto 8),
                                 s_trg_timestamp(23 downto 16),
                                 s_trg_timestamp(31 downto 24),
                                 s_trg_timestamp(39 downto 32),
                                 s_trg_timestamp(47 downto 40),
                                 s_trg_timestamp(7 downto 0)) is
  begin  -- process
    case s_state is

      when st0_idle =>
        chb_req_o <= '0';
        ttc_long_o.long_subadd <= x"00";
        ttc_long_o.long_data <= x"00";
        s_strobe <= '0';

      when st1_verify_txready =>
        chb_req_o <= '0';
        ttc_long_o.long_subadd <= x"00";
        ttc_long_o.long_data <= x"00";
        s_strobe <= '0';

      when st2_chb_req =>
        chb_req_o <= '1';
        ttc_long_o.long_subadd <= x"00";
        ttc_long_o.long_data <= x"00";
        s_strobe <= '0';

      when st3_time_byte_0 =>
        chb_req_o <= '0';
        ttc_long_o.long_subadd <= x"01";
        ttc_long_o.long_data <= s_trg_timestamp(7 downto 0);
        s_strobe <= '1';

      when st4_chb_req =>
        chb_req_o <= '1';
        ttc_long_o.long_subadd <= x"00";
        ttc_long_o.long_data <= x"00";
        s_strobe <= '0';

      when st5_time_byte_1 =>
        chb_req_o <= '0';
        ttc_long_o.long_subadd <= x"02";
        ttc_long_o.long_data <= s_trg_timestamp(15 downto 8);
        s_strobe <= '1';

      when st6_chb_req =>
        chb_req_o <= '1';
        ttc_long_o.long_subadd <= x"00";
        ttc_long_o.long_data <= x"00";
        s_strobe <= '0';

      when st7_time_byte_2 =>
        chb_req_o <= '0';
        ttc_long_o.long_subadd <= x"03";
        ttc_long_o.long_data <= s_trg_timestamp(23 downto 16);
        s_strobe <= '1';

      when st8_chb_req =>
        chb_req_o <= '1';
        ttc_long_o.long_subadd <= x"00";
        ttc_long_o.long_data <= x"00";
        s_strobe <= '0';

      when st9_time_byte_3 =>
        chb_req_o <= '0';
        ttc_long_o.long_subadd <= x"04";
        ttc_long_o.long_data <= s_trg_timestamp(31 downto 24);
        s_strobe <= '1';

      when st10_chb_req =>
        chb_req_o <= '1';
        ttc_long_o.long_subadd <= x"00";
        ttc_long_o.long_data <= x"00";
        s_strobe <= '0';

      when st11_time_byte_4 =>
        chb_req_o <= '0';
        ttc_long_o.long_subadd <= x"05";
        ttc_long_o.long_data <= s_trg_timestamp(39 downto 32);
        s_strobe <= '1';

      when st12_chb_req =>
        chb_req_o <= '1';
        ttc_long_o.long_subadd <= x"00";
        ttc_long_o.long_data <= x"00";
        s_strobe <= '0';

      when st13_time_byte_5 =>
        chb_req_o <= '0';
        ttc_long_o.long_subadd <= x"06";
        ttc_long_o.long_data <= s_trg_timestamp(47 downto 40);
        s_strobe <= '1';



      when others => null;
    end case;
  end process;

  ttc_long_o.long_address <= (others => '0');




end architecture  rtl;
