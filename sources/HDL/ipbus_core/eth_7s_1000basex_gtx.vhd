----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2018/09/21 15:49:21
-- Design Name: 
-- Module Name: eth_7s_1000basex_gtx - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity eth_7s_1000basex_gtx is
 Port ( 
    gt_clkp, gt_clkn: in std_logic;
    gtrefclk_out : out std_logic;
		gt_txp, gt_txn: out std_logic;
		gt_rxp, gt_rxn: in std_logic;
		sfp_los: in std_logic;
		clk125_out: out std_logic;
		clk125_fr: out std_logic;
--		pllclk_out: out std_logic;
--		pllrefclk_out: out std_logic;
		rsti: in std_logic;
		locked: out std_logic;
		tx_data: in std_logic_vector(7 downto 0);
		tx_valid: in std_logic;
		tx_last: in std_logic;
		tx_error: in std_logic;
		tx_ready: out std_logic;
		rx_data: out std_logic_vector(7 downto 0);
		rx_valid: out std_logic;
		rx_last: out std_logic;
		rx_error: out std_logic;
        mmcm_locked_out: out std_logic;
        phy_done_out: out std_logic
 );
end eth_7s_1000basex_gtx;

architecture Behavioral of eth_7s_1000basex_gtx is
    signal gmii_txd, gmii_rxd: std_logic_vector(7 downto 0);
	signal gmii_tx_en, gmii_tx_er, gmii_rx_dv, gmii_rx_er: std_logic;
	signal gmii_rx_clk: std_logic;
	signal sig_det, gt_clkp_i, gt_clkn_i: std_logic;
	signal clk125, clk_fr,dc,clk_dc: std_logic;
	signal rstn, phy_done, mmcm_locked, locked_int: std_logic;
    signal  speedis10100,speedis100 : std_logic;
begin
    clk125_fr <= clk_fr;
	clk125_out <= clk125;
    
    process(clk_fr)
	begin
		if rising_edge(clk_fr) then
			locked_int <= mmcm_locked and phy_done;
		end if;
	end process;
    mmcm_locked_out <= mmcm_locked;
    phy_done_out <= phy_done;
	locked <= locked_int;
	rstn <= not (not locked_int or rsti);
    
    mac:entity work.tri_mode_ethernet_mac_0
    PORT MAP (
        gtx_clk => clk125,
		glbl_rstn => rstn,
		rx_axi_rstn => '1',
		tx_axi_rstn => '1',
		rx_statistics_vector => open,
		rx_statistics_valid => open,
		rx_mac_aclk => open,
		rx_reset => open,
		rx_axis_mac_tdata => rx_data,
		rx_axis_mac_tvalid => rx_valid,
		rx_axis_mac_tlast => rx_last,
		rx_axis_mac_tuser => rx_error,
		tx_ifg_delay => X"00",
		tx_statistics_vector => open,
		tx_statistics_valid => open,
		tx_mac_aclk => open,
		tx_reset => open,
		tx_axis_mac_tdata => tx_data,
		tx_axis_mac_tvalid => tx_valid,
		tx_axis_mac_tlast => tx_last,
		tx_axis_mac_tuser(0) => tx_error,
		tx_axis_mac_tready => tx_ready,
        speedis100 => speedis100,
        speedis10100 => speedis10100,
		pause_req => '0',
		pause_val => X"0000",
		gmii_txd => gmii_txd,
		gmii_tx_en => gmii_tx_en,
		gmii_tx_er => gmii_tx_er,
		gmii_rxd => gmii_rxd,
		gmii_rx_dv => gmii_rx_dv,
		gmii_rx_er => gmii_rx_er,
		rx_configuration_vector => X"0000_0000_0000_0000_2012",
		tx_configuration_vector => X"0000_0000_0000_0000_2012"
    );
    process(clk_fr)
	begin
		if rising_edge(clk_fr) then
			dc <= not dc;
		end if;
	end process;

	dc_buf: BUFG
		port map(
			i => dc,
			o => clk_dc
		);
    phy: entity work.gig_ethernet_pcs_pma_0
	port map(
		gtrefclk_p => gt_clkp,
		gtrefclk_n => gt_clkn,
        --gtrefclk => gtrefclk,
		gtrefclk_out => gtrefclk_out,
		gtrefclk_bufg_out => clk_fr,	
		txp => gt_txp,
		txn => gt_txn,
		rxp => gt_rxp,
		rxn => gt_rxn,
		resetdone => phy_done,
		userclk_out => open,
		userclk2_out => clk125,
		rxuserclk_out => open,
		rxuserclk2_out => open,
		pma_reset_out => open,
		mmcm_locked_out => mmcm_locked,
		independent_clock_bufg => clk_dc,
		gmii_txd => gmii_txd,
		gmii_tx_en => gmii_tx_en,
		gmii_tx_er => gmii_tx_er,
		gmii_rxd => gmii_rxd,
		gmii_rx_dv => gmii_rx_dv,
		gmii_rx_er => gmii_rx_er,
		gmii_isolate => open,
		configuration_vector => "00000",
--        speed_is_10_100 => speedis10100,
--        speed_is_100 => speedis100,
		status_vector => open,
		reset => rsti,
		signal_detect => sig_det,
        gt0_qplloutclk_out => open,
        gt0_qplloutrefclk_out => open
    );
    sig_det <= not sfp_los;
    -- ila1:entity work.ila_1
    -- port map(
    -- clk => clk125,
    -- probe0(0) => mmcm_locked,
    -- probe1(0) => rsti
    -- );
end Behavioral;
