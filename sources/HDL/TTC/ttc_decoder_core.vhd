--=================================================================================================--
--==================================== Module Information =========================================--
--=================================================================================================--
--                                                                                         
-- Company:                CERN (PH-ESE-BE)                                                         
-- Engineer:               Sophie Baron (sophie.baron@cern.ch)
--                                                                                                 
-- Project Name:           TTC                                                            
-- Module Name:            TTC_decoder_top                                         
--                                                                                                 
-- Language:               VHDL'93                                                                  
--                                                                                                   
-- Target Device:          Kintex7 - KC705                                                         
-- Tool version:           ISE 14.5                                                                
--                                                                                                   
-- Version:                0.1                                                                      
--
-- Description:            
--
-- Versions history:       DATE         VERSION   AUTHOR            DESCRIPTION
--
--                         19/07/2013   1.0       Sophie BARON      - First .vhd module definition           
--
-- DATE:        24/11/2016
-- VERSION:     2.0
-- AUTHOR:      INFN - Davide Pedretti
-- DESCRIPTION: changed vhdl coding style, design architecture review + design optimization + added 
--              long frame register stack.
--=================================================================================================--
--=================================================================================================--

--=================================================================================================--
--==================================== Additional Comments ========================================--
--=================================================================================================-- 
--
-- TTC FRAME (TDM of channels A and B):
-- A channel: No encoding, minimum latency.
-- B channel: short broadcast or long addressed commands. Hamming check bits

-- B Channel Content:
-- Short Broadcast, 16 bits:
-- 00SSSSSSEBHHHHH1: S=Command/Data, 6 bits. E=Event Counter Reset, 1 bit. B=Bunch Counter Reset, 1 bit. 
--                   H=Hamming Code, 5 bits.
--
-- Long Addressed, 42 bits:
-- 01AAAAAAAAAAAAAAAASSSSSSSSDDDDDDDDHHHHHHH1: A= TTCrx address, 16 bits. S=SubAddress, 8 bits. 
--                                             D=Data, 8 bits. H=Hamming Code, 7 bits.
--  
--     
--
-- TDM/BPM coding principle:
--  <  16.0000 ns   >
--     X---A---X---B---X
--  X=======X=======X A=0, B=0 (no trigger, B=0) 
--  X=======X===X===X A=0, B=1 (no trigger, B=1). 
--  X===X===X=======X A=1, B=0 (trigger, B=0). max string length =11
--  X===X===X===X===X A=1, B=1 (trigger, B=1)
--
--=================================================================================================--


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;
use work.TTIM_pack.all;
library unisim;
use unisim.vcomponents.all;

--=================================================================================================--
--======================================= Module Body =============================================-- 
--=================================================================================================--
entity ttc_decoder_core is
  generic (g_pll_locked_delay : integer  := 200;
           g_Hamming          : boolean  := true;
           g_max_trigg_len    : natural  := 30;
           g_TTC_memory_deep  : positive := 25
           );
  port
    (                                   --== cdr interface ==--
      locked_i              : in  std_logic;  -- from MMCM tile 
      --cdrclk_i                 : in std_logic;  -- 62.5 MHz clock from CDR  
      cdrclk_x4_i           : in  std_logic;  -- 125 MHz clock from CDR        
      cdrclk_x2_i           : in  std_logic;
      cdrdata_i             : in  std_logic;  -- data stream from CDR
      ttcrx_coarse_delay_i  : in  std_logic_vector(4 downto 0);
      gcuid_i               : in  std_logic_vector(15 downto 0);
      --== ttc decoder output ==--
      cha_o                 : out std_logic_vector(1 downto 0);  -- 16ns pulse
      brd_command_vector_o  : out t_brd_command;
      l1a_time_o            : out std_logic_vector (47 downto 0);
      synch_o               : out std_logic_vector (47 downto 0);
      delay_o               : out std_logic_vector (47 downto 0);
      ttc_ctrl_o            : out t_ttc_ctrl;
      delay_req_o           : out std_logic;
      synch_req_o           : out std_logic;
      byte5_o               : out std_logic;
      tap_incr_o            : out std_logic;
      tap_decr_o            : out std_logic;
      tap_reset_o           : out std_logic;
      -- Error counters
      reset_err         : in std_logic;
      single_bit_err_o      : out std_logic_vector(31 downto 0);
      duble_bit_err_o       : out std_logic_vector(31 downto 0);
      comm_err_o            : out std_logic_vector(31 downto 0);
      l1a_err_o        : out std_logic_vector(31 downto 0);
      --== ttc decoder aux flags ==--
      ready_o               : out std_logic;  -- ready_o flag -- MMCM locked delayed
      no_errors_o           : out std_logic;
      l1a_no_errors_o       : out std_logic;
      aligned_o             : out std_logic;
      not_in_table_o        : out std_logic;
      cha_time_domain_o     : out std_logic;
      -- debug
      hit_toggle            : in  std_logic;
      l1a_i                 : in  std_logic;
      toggle_channel_debug  : out std_logic;
      toggle_shift_debug    : out std_logic;
      bmc_data_toggle_debug : out std_logic;
      cdr_data_debug        : out std_logic_vector(1 downto 0);
      brc_cmd_debug         : out std_logic_vector(5 downto 0);
      brc_cmd_strobe_debug  : out std_logic;
      brc_rst_t_debug       : out std_logic;
      brc_rst_e_debug       : out std_logic;
      error_1bit_pulse_test : out std_logic;
      error_2bit_pulse_test : out std_logic;
      error_comm_pulse_test : out std_logic
      );

end ttc_decoder_core;

architecture rtl of ttc_decoder_core is

--========================= Signal Declarations ==========================--
  signal s_mmcm_lock           : std_logic;
  signal s_chB_data            : std_logic_vector(38 downto 0);
  signal s_chB_data_rdy        : std_logic_vector(1 downto 0);
  signal s_single_bit_error    : std_logic;
  signal s_double_bit_error    : std_logic;
  signal s_channelB_comm_error : std_logic;
  signal s_cha                 : std_logic;
  signal s_chb                 : std_logic;
  signal s_cdrdata_d           : std_logic;  -- after coarse delay
  signal s_chb_strobe          : std_logic;
  signal s_q31_unused          : std_logic;

  signal u_1bit_err_count  : unsigned(31 downto 0);
  signal u_2bit_err_count  : unsigned(31 downto 0);
  signal u_comm_err_count  : unsigned(31 downto 0);
  signal s_comm_err_count  : std_logic_vector(31 downto 0);
  signal s_carry           : std_logic;
  signal s_brc_cmd         : std_logic_vector(5 downto 0);
  signal s_brc_strobe      : std_logic;
  signal s_brc_rst_t       : std_logic;
  signal s_brc_rst_e       : std_logic;
  signal s_rst_errors      : std_logic;
  signal s_1bit_err        : std_logic;
  signal s_2bit_err        : std_logic;
  signal s_comm_err        : std_logic;
  signal s_add_strb        : std_logic;
  signal s_add_a16         : std_logic_vector(15 downto 0);
  signal s_add_s8          : std_logic_vector(7 downto 0);
  signal s_add_d8          : std_logic_vector(7 downto 0);
  signal s_ttc_mem_addr    : std_logic_vector(7 downto 0);
  signal s_ttc_mem_data    : std_logic_vector(7 downto 0);
  signal s_ttc_mem_we      : std_logic;
  signal s_aligned         : std_logic;
  signal s_idle            : std_logic;
  signal s_toggle_shift    : std_logic;
  signal s_cha_time_domain : std_logic;
  signal s_l1a : std_logic_vector(1 downto 0);
  signal s_l1a_err_pulse : std_logic;
  signal s_l1a_err_pulse_to_reduce : std_logic_vector(1 downto 0);
  signal u_l1a_err_count  : unsigned(31 downto 0);
  signal s_l1a_err_count  : std_logic_vector(31 downto 0);
  signal s_l1a_carry           : std_logic;

  attribute mark_debug : string;
  -- attribute mark_debug of s_l1a : signal is "true";
  -- attribute mark_debug of s_l1a_err_pulse : signal is "true";
  -- attribute mark_debug of s_l1a_err_count : signal is "true";

--========================= Components Declarations ==========================--
-- component cdr2a_b_clk
--   generic(
--        g_max_trigg_len : natural := 30
--      );
--    port(
--         cdrclk_x4_i      : in   std_logic;       -- CDR 250MHz clock output from MMCM
--       cdrdata_i      : in   std_logic;       -- ADN2812 CDR Serial Data output
--       reset_n_i        : in   std_logic;              
--       l1a_o          : out  std_logic;       -- A channel = Trigger
--       chb_o           : out  std_logic;        -- B serial stream    
--       chb_strobe_o     : out  std_logic;
--         toggle_shift_o     : out  std_logic;
--         cha_time_domain_o  : out  std_logic;
--      -- debug
--      toggle_channel_debug  : out std_logic;
--      toggle_shift_debug    : out std_logic;
--      bmc_data_toggle_debug : out std_logic;
--      cdr_data_debug      : out std_logic_vector(1 downto 0)
--         );
-- end component;

  component bmc_recover is
    port (
      cdrclk_x4_i    : in  std_logic;
      cdrdata_i      : in  std_logic;
      reset_n_i      : in  std_logic;
      chb_o          : out std_logic;
      chb_strobe_o   : out std_logic;
      toggle_shift_o : out std_logic);
  end component bmc_recover;

  component serialb_com
    generic(include_hamming : boolean := true
            );
    port(
      clk_i                 : in  std_logic;
      reset_n_i             : in  std_logic;
      chb_i                 : in  std_logic;  -- serial stream 
      chb_strobe_i          : in  std_logic;
      single_bit_error_o    : out std_logic;
      double_bit_error_o    : out std_logic;
      communication_error_o : out std_logic;
      data_ready_o          : out std_logic_vector(1 downto 0);
      data_out_o            : out std_logic_vector(38 downto 0)
      );
  end component;

  component BrdCommandDecoder
    port(
      clk_i            : in  std_logic;
      brd_strobe_i     : in  std_logic;
      ttcrx_ready_i    : in  std_logic;
      rx_brd_cmd_i     : in  std_logic_vector(5 downto 0);
      aligned_o        : out std_logic;
      supernova_o      : out std_logic;
      test_pulse_o     : out std_logic;
      time_request_o   : out std_logic;
      rst_errors_o     : out std_logic;
      not_in_table_o   : out std_logic;
      auto_trigger_o   : out std_logic;
      en_acquisition_o : out std_logic
      );
  end component;

  component addressed_command_decoder
    port(
      clk_i         : in  std_logic;
      rst_n_i       : in  std_logic;
      gcu_id_i      : in  std_logic_vector(15 downto 0);
      add_a16_i     : in  std_logic_vector(15 downto 0);
      add_s8_i      : in  std_logic_vector(7 downto 0);
      add_d8_i      : in  std_logic_vector(7 downto 0);
      long_strobe_i : in  std_logic;
      add_s8_o      : out std_logic_vector(7 downto 0);
      add_d8_o      : out std_logic_vector(7 downto 0);
      we_o          : out std_logic
      );
  end component;

  component TTC_register_stack
    generic(
      g_TTC_memory_deep : positive := 25
      );
    port (clk_i        : in  std_logic;
          we_i         : in  std_logic;
          rst_n_i      : in  std_logic;
          addr_i       : in  std_logic_vector (7 downto 0);
          data_i       : in  std_logic_vector (7 downto 0);
          ctrl_o       : out t_ttc_ctrl;
          l1a_time_o   : out std_logic_vector (47 downto 0);
          synch_byte_o : out std_logic_vector (47 downto 0);
          delay_byte_o : out std_logic_vector (47 downto 0));
  end component;


--===================================================--
begin  --================ Architecture Body ================-- 
  --===================================================--


-------
-- debug
-------
  brc_cmd_debug         <= s_brc_cmd;
  brc_cmd_strobe_debug  <= s_brc_strobe;
  brc_rst_t_debug       <= s_brc_rst_e;
  brc_rst_e_debug       <= s_brc_rst_t;
  error_1bit_pulse_test <= s_1bit_err;
  error_2bit_pulse_test <= s_2bit_err;
  error_comm_pulse_test <= s_comm_err;
--

--===================================================-- 
--delay before starting the A and B channel extraction
--===================================================--

  p_delay_after_lock : process(cdrclk_x4_i, locked_i)
    variable timer : integer := 200;
  begin
    if locked_i = '0' then
      timer       := g_pll_locked_delay;
      s_mmcm_lock <= '0';
    elsif rising_edge(cdrclk_x4_i) then
      if timer = 0 then
        s_mmcm_lock <= '1';
      else
        timer := timer-1;
      end if;
    end if;
  end process;

--===================================================-- 
--                   Coarse delay
--===================================================--

  Inst_ttcrx_coarse_delay : SRLC32E
    generic map (
      INIT => X"00000000")
    port map (
      Q   => s_cdrdata_d,               -- SRL data output
      Q31 => s_q31_unused,              -- SRL cascade output pin
      A   => ttcrx_coarse_delay_i,      -- 5-bit shift depth select input
      CE  => '1',                       -- Clock enable input
      CLK => cdrclk_x4_i,               -- Clock input
      D   => cdrdata_i                  -- SRL data input
      );


--===================================================-- 
--            Hit Descrambler
--===================================================--
  Inst_hit_recognizer : entity work.hit_recognizer
    port map(
      hit_from_gcu => l1a_i,
      clk_i        => cdrclk_x2_i,
      clk_x2_i     => cdrclk_x4_i,
      rst_i        => not locked_i,
      toggle_i     => hit_toggle,
      --aligned_o => open,
      hit_o        => s_l1a
      );

  bmc_recover_1 : bmc_recover
    port map (
      cdrclk_x4_i    => cdrclk_x4_i,
      cdrdata_i      => s_cdrdata_d,
      reset_n_i      => not locked_i,
      chb_o          => s_chb,
      chb_strobe_o   => s_chb_strobe,
      toggle_shift_o => s_toggle_shift
      );

  cha_time_domain_o <= '0';
  cha_o <= s_l1a;
-- s_cha <= l1a_i;
--===================================================--
--            Deserializer + Error Correction
--===================================================--
  Inst_deserializer : serialb_com
    generic map (
      include_hamming => g_Hamming)
    port map(
      clk_i                 => cdrclk_x4_i,
      reset_n_i             => s_mmcm_lock,
      chb_i                 => s_chb,   -- serial stream 
      chb_strobe_i          => s_chb_strobe,
      single_bit_error_o    => s_single_bit_error,
      double_bit_error_o    => s_double_bit_error,
      communication_error_o => s_channelB_comm_error,
      data_ready_o          => s_chB_data_rdy,
      data_out_o            => s_chB_data
      );

-------------------------------------------------------------------------------
-- L1A PRBS error counter
-------------------------------------------------------------------------------
  FakeHitChk : entity work.PRBS_ANY
    generic map(
      CHK_MODE    => true,
      INV_PATTERN => false,
      POLY_LENGHT => 7,
      POLY_TAP    => 3,
      NBITS       => 2
      )
    port map(
      RST      => '0',
      CLK      => cdrclk_x2_i,
      DATA_IN  => s_l1a,
      EN       => '1',
      DATA_OUT => s_l1a_err_pulse_to_reduce
      );

  s_l1a_err_pulse <= or_reduce(s_l1a_err_pulse_to_reduce);

  p_l1a_comm_error_counter : process(cdrclk_x4_i)
  begin
    if rising_edge(cdrclk_x4_i) then
      if s_mmcm_lock = '0' or s_rst_errors = '1' then
        u_l1a_err_count <= (others => '0');
      elsif s_l1a_err_pulse = '1' and s_l1a_carry = '0' then
        u_l1a_err_count <= u_l1a_err_count + 1;
      end if;
    end if;
  end process p_l1a_comm_error_counter;

  s_l1a_err_count <= std_logic_vector(u_l1a_err_count);

  l1a_err_o <= s_l1a_err_count;

  s_l1a_carry <= '1' when s_l1a_err_count(31) = '1' else
                 '0';

  l1a_no_errors_o <= '0' when u_l1a_err_count >= 1 else
                     '1';

--=============================================================================--
-- output mapping - 62.5 MHz synchronization (data updated every 16ns)
--=============================================================================--
-- All data readout so far was at 250 MHz; Sampling data at 62.5 MHz we introduce
-- up to 12 ns of latency uncertainty besides the external CDR uncertainty

  process(cdrclk_x4_i, s_mmcm_lock)
  begin
    if s_mmcm_lock = '0' then
      s_brc_strobe <= '0';
      s_add_strb   <= '0';
      s_brc_cmd    <= (others => '0');
      s_brc_rst_e  <= '0';
      s_brc_rst_t  <= '0';
      s_add_a16    <= (others => '0');
      s_add_s8     <= (others => '0');
      s_add_d8     <= (others => '0');
      s_1bit_err   <= '0';
      s_2bit_err   <= '0';
      -- cha_o                  <= '0';
      s_comm_err   <= '0';
      ready_o      <= '0';
    elsif rising_edge(cdrclk_x4_i) then
      s_brc_strobe <= s_chB_data_rdy(0);
      s_add_strb   <= s_chB_data_rdy(1);
      --SSSSSSEB
      if s_chB_data_rdy(0) = '1' then
        s_brc_cmd   <= s_chB_data(12 downto 7);
        s_brc_rst_e <= s_chB_data(6);
        s_brc_rst_t <= s_chB_data(5);
      else
        s_brc_cmd   <= (others => '0');
        s_brc_rst_e <= '0';
        s_brc_rst_t <= '0';
      end if;

      --AAAAAAAAAAAAAAAASSSSSSSSDDDDDDDD
      if s_chB_data_rdy(1) = '1' then
        s_add_a16 <= s_chB_data(38 downto 23);
        s_add_s8  <= s_chB_data(22 downto 15);
        s_add_d8  <= s_chB_data(14 downto 7);
      else
        s_add_a16 <= (others => '0');
        s_add_s8  <= (others => '0');
        s_add_d8  <= (others => '0');
      end if;
      s_1bit_err <= s_single_bit_error;
      s_2bit_err <= s_double_bit_error;
      -- cha_o        <= s_cha and s_aligned;
      s_comm_err <= s_channelB_comm_error;
      ready_o    <= s_mmcm_lock;
    end if;
  end process;

--===================================================--
--                Broadcast Command Decoder
--===================================================--

  Inst_BrdCommandDecoder : BrdCommandDecoder
    port map(
      clk_i            => cdrclk_x4_i,
      brd_strobe_i     => s_brc_strobe,
      ttcrx_ready_i    => s_mmcm_lock,
      rx_brd_cmd_i     => s_brc_cmd,
      aligned_o        => s_idle,
      supernova_o      => brd_command_vector_o.supernova,
      test_pulse_o     => brd_command_vector_o.test_pulse,
      time_request_o   => brd_command_vector_o.time_request,
      rst_errors_o     => s_rst_errors,
      auto_trigger_o   => brd_command_vector_o.autotrigger,
      not_in_table_o   => not_in_table_o,
      en_acquisition_o => brd_command_vector_o.en_acquisition
      );

  brd_command_vector_o.rst_errors     <= s_rst_errors;
  brd_command_vector_o.rst_time       <= s_brc_rst_t;
  brd_command_vector_o.rst_event      <= s_brc_rst_e;
  brd_command_vector_o.rst_time_event <= s_brc_rst_e and s_brc_rst_t;
  brd_command_vector_o.idle           <= s_idle;
--===================================================--
--                Addressed Command Decoder
--===================================================--

  Inst_AddressedCommandDecoder : addressed_command_decoder
    port map(
      clk_i         => cdrclk_x4_i,
      rst_n_i       => s_mmcm_lock,
      gcu_id_i      => gcuid_i,
      add_a16_i     => s_add_a16,
      add_s8_i      => s_add_s8,
      add_d8_i      => s_add_d8,
      long_strobe_i => s_add_strb,
      add_s8_o      => s_ttc_mem_addr,
      add_d8_o      => s_ttc_mem_data,
      we_o          => s_ttc_mem_we
      );

--===================================================--
--                TTC register stack
--===================================================--

  Inst_TTC_register_stack : entity work.TTC_register_stack
    generic map(
      g_TTC_memory_deep => g_TTC_memory_deep
      )
    port map(
      clk_i        => cdrclk_x4_i,
      we_i         => s_ttc_mem_we,
      rst_n_i      => s_mmcm_lock,
      addr_i       => s_ttc_mem_addr,
      data_i       => s_ttc_mem_data,
      ctrl_o       => ttc_ctrl_o,
      l1a_time_o   => l1a_time_o,
      synch_byte_o => synch_o,
      delay_byte_o => delay_o
      );
--===================================================--
--       addressed command delay request pulse
--===================================================--       
  p_delay_req : process(cdrclk_x4_i)
  begin
    if rising_edge(cdrclk_x4_i) then
      if s_ttc_mem_addr = x"19" and s_ttc_mem_we = '1' then
        delay_req_o <= '1';
      else
        delay_req_o <= '0';
      end if;
    end if;
  end process p_delay_req;

--===================================================--
--       addressed command synch request pulse
--===================================================--       
  p_synch_req : process(cdrclk_x4_i)
  begin
    if rising_edge(cdrclk_x4_i) then
      if (s_ttc_mem_addr = x"09") and s_ttc_mem_we = '1' then
        synch_req_o <= '1';
      else
        synch_req_o <= '0';
      end if;
    end if;
  end process p_synch_req;

--===================================================--
--       addressed command byte 5 pulse
--===================================================--       
  p_byte5 : process(cdrclk_x4_i)
  begin
    if rising_edge(cdrclk_x4_i) then
      if (s_ttc_mem_addr = x"16" or s_ttc_mem_addr = x"0e") and s_ttc_mem_we = '1' then
        byte5_o <= '1';
      else
        byte5_o <= '0';
      end if;
    end if;
  end process p_byte5;

--===================================================--
--       addressed command tap increment pulse
--===================================================--       
  p_tap_incr : process(cdrclk_x4_i)
  begin
    if rising_edge(cdrclk_x4_i) then
      if (s_ttc_mem_addr = x"1a" and s_ttc_mem_we = '1') then
        tap_incr_o <= '1';
      else
        tap_incr_o <= '0';
      end if;
    end if;
  end process p_tap_incr;

--===================================================--
--       addressed command tap decrement pulse
--===================================================--       
  p_tap_decr : process(cdrclk_x4_i)
  begin
    if rising_edge(cdrclk_x4_i) then
      if (s_ttc_mem_addr = x"1b" and s_ttc_mem_we = '1') then
        tap_decr_o <= '1';
      else
        tap_decr_o <= '0';
      end if;
    end if;
  end process p_tap_decr;

--===================================================--
--       addressed command tap reset pulse
--===================================================--       
  p_tap_reset : process(cdrclk_x4_i)
  begin
    if rising_edge(cdrclk_x4_i) then
      if (s_ttc_mem_addr = x"1c" and s_ttc_mem_we = '1') then
        tap_reset_o <= '1';
      else
        tap_reset_o <= '0';
      end if;
    end if;
  end process p_tap_reset;

--===================================================--
--                 Error Counters
--===================================================--

  p_1bit_error_counter : process(cdrclk_x4_i)
  begin
    if rising_edge(cdrclk_x4_i) then
      if s_mmcm_lock = '0' or reset_err = '1' or s_rst_errors = '1' then
        u_1bit_err_count <= (others => '0');
      elsif s_1bit_err = '1' then
        u_1bit_err_count <= u_1bit_err_count + 1;
      end if;
    end if;
  end process p_1bit_error_counter;
  single_bit_err_o <= std_logic_vector(u_1bit_err_count);


  p_2bit_error_counter : process(cdrclk_x4_i)
  begin
    if rising_edge(cdrclk_x4_i) then
      if s_mmcm_lock = '0' or reset_err = '1' or s_rst_errors = '1' then
        u_2bit_err_count <= (others => '0');
      elsif s_2bit_err = '1' then
        u_2bit_err_count <= u_2bit_err_count + 1;
      end if;
    end if;
  end process p_2bit_error_counter;
  duble_bit_err_o <= std_logic_vector(u_2bit_err_count);


  p_comm_error_counter : process(cdrclk_x4_i)
  begin
    if rising_edge(cdrclk_x4_i) then
      if s_mmcm_lock = '0' or reset_err = '1' or s_rst_errors = '1' then
        u_comm_err_count <= (others => '0');
      elsif s_comm_err = '1' and s_carry = '0' then
        u_comm_err_count <= u_comm_err_count + 1;
      end if;
    end if;
  end process p_comm_error_counter;
  s_comm_err_count <= std_logic_vector(u_comm_err_count);
  comm_err_o       <= s_comm_err_count;
  s_carry          <= '1' when s_comm_err_count(31) = '1' else
             '0';
  no_errors_o <= '0' when u_comm_err_count >= 1 else
                 '1';
--===================================================--
--         Set Reset FF - Channel Aligned flag
--===================================================--         
  Inst_aligned_SR : entity work.set_reset_ffd
    generic map(
      g_clk_rise => "TRUE"
      )
    port map(
      clk_i   => cdrclk_x4_i,
      set_i   => s_idle,
      reset_i => s_toggle_shift,
      q_o     => s_aligned
      );
  aligned_o <= s_aligned;

end rtl;


