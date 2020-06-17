-------------------------------------------------------------------------------
-- Title      : bmc recovery module
-- Project    : 
-------------------------------------------------------------------------------
-- File       : bmc_recover.vhd
-- Author     : Filippo Marini   <filippo.marini@pd.infn.it>
-- Company    : Universita degli studi di Padova
-- Created    : 2019-05-25
-- Last update: 2019-05-26
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2019 Universita degli studi di Padova
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-05-25  1.0      filippo Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use work.TTIM_pack.all;

entity bmc_recover is
  port (
    cdrclk_x4_i           : in  std_logic;
    cdrdata_i             : in  std_logic;
    reset_n_i             : in  std_logic;
    -- l1a_o                 : out std_logic;
    chb_o                 : out std_logic;
    chb_strobe_o          : out std_logic;
    toggle_shift_o        : out std_logic
    -- cha_time_domain_o     : out std_logic;
    -- toggle_channel_debug  : out std_logic;
    -- toggle_shift_debug    : out std_logic;
    -- bmc_data_toggle_debug : out std_logic;
    -- cdr_data_debug        : out std_logic_vector(1 downto 0)
    );
end entity bmc_recover;

architecture rtl of bmc_recover is

  signal s_cdrdata_q : std_logic_vector(1 downto 0);
  signal s_bmc_data_toggle  : std_logic;
  signal s_align_check : std_logic;
  signal s_bit_toggle : std_logic;
  signal s_toggle_shift : std_logic;

begin  -- architecture rtl


  xor_proc:process(cdrclk_x4_i, reset_n_i) is
  begin
    if reset_n_i = '1' then 
      s_cdrdata_q <= (others => '0');
    elsif rising_edge(cdrclk_x4_i) then
      s_cdrdata_q <= s_cdrdata_q(0) & cdrdata_i;
    end if;
  end process;

  s_bmc_data_toggle <= s_cdrdata_q(0) xor s_cdrdata_q(1);

  f_edge_detect_1: entity work.f_edge_detect
    generic map (
      g_clk_rise => "TRUE"
      )
    port map (
      clk_i => cdrclk_x4_i,
      sig_i => s_bmc_data_toggle,
      sig_o => s_align_check
      );

  -- purpose: bit should be high right after toggle
  alignment_proc : process (cdrclk_x4_i, reset_n_i) is
  begin  -- process
    if reset_n_i = '1' then             -- asynchronous reset (active high)
      s_bit_toggle <= '1';
    elsif rising_edge(cdrclk_x4_i) then  -- rising clock edge
      if (s_align_check and s_bit_toggle) = '0' then
        s_bit_toggle <= not s_bit_toggle;
      end if;
    end if;
  end process;

  -- purpose: process to raise a flag when s_bit_toggle disalign
  dit_toggle_shift_proc: process (cdrclk_x4_i, reset_n_i) is
  begin  -- process dit_toggle_shift_proc
    if reset_n_i = '1' then             -- asynchronous reset (active high)
      s_toggle_shift <= '0';
    elsif rising_edge(cdrclk_x4_i) then  -- rising clock edge
      if (s_align_check and s_bit_toggle) = '1' then
        s_toggle_shift <= '1';
      else
        s_toggle_shift <= '0';
      end if;
    end if;
  end process dit_toggle_shift_proc;

  toggle_shift_o <= s_toggle_shift;

  -----------------------------------------------------------------------------
  -- CHB Extraction
  -----------------------------------------------------------------------------
  -- purpose: xor is sampled correctly only if s_bit_toggle = 1
  chb_extraction_proc: process (cdrclk_x4_i, reset_n_i) is
  begin  -- process chb_extraction_proc
    if reset_n_i = '1' then             -- asynchronous reset (active high)
      chb_o <= '0';
    elsif rising_edge(cdrclk_x4_i) then  -- rising clock edge
      if s_bit_toggle = '1' then
        chb_o <= s_bmc_data_toggle;
      end if;
    end if;
  end process chb_extraction_proc;

  chb_strobe_extraction_proc: process (cdrclk_x4_i, reset_n_i) is
  begin  -- process chb_strobe_extraction_proc
    if reset_n_i = '1' then             -- asynchronous reset (active high)
      chb_strobe_o <= '0';
    elsif rising_edge(cdrclk_x4_i) then  -- rising clock edge
      chb_strobe_o <= s_bit_toggle;
    end if;
  end process chb_strobe_extraction_proc;



end architecture rtl;
