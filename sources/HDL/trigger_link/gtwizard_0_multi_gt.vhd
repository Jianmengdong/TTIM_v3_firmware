-------------------------------------------------------------------------------
--   ____  ____
--  /   /\/   /
-- /___/  \  /    Vendor: Xilinx
-- \   \   \/     Version : 3.6
--  \   \         Application : 7 Series FPGAs Transceivers Wizard
--  /   /         Filename : gtwizard_0_multi_gt.vhd
-- /___/   /\     
-- \   \  /  \ 
--  \___\/\___\
--
--
-- Module gtwizard_0_multi_gt (a Multi GT Wrapper)
-- Generated by Xilinx 7 Series FPGAs Transceivers Wizard
-- 
-- 
-- (c) Copyright 2010-2012 Xilinx, Inc. All rights reserved.
-- 
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
-- 
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
-- 
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
-- 
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES. 


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;


--***************************** Entity Declaration ****************************

entity gtwizard_0_multi_gt is
generic
(
    -- Simulation attributes
    WRAPPER_SIM_GTRESET_SPEEDUP     : string     :=  "FALSE";        -- Set to "TRUE" to speed up sim reset
    RX_DFE_KL_CFG2_IN               : bit_vector :=  X"301148AC";
    USE_BUFG                        : integer   := 0;          -- Set to 1 for bufg usage for cpll railing logic
 
    PMA_RSV_IN                      : bit_vector :=  x"00018480"
);
port
(
    --_________________________________________________________________________
    --_________________________________________________________________________
    --GT0  (X0Y0)
    --____________________________CHANNEL PORTS________________________________
    --------------------------------- CPLL Ports -------------------------------
    gt0_cpllfbclklost_out                   : out  std_logic;
    gt0_cplllock_out                        : out  std_logic;
    gt0_cplllockdetclk_in                   : in   std_logic;
    gt0_cpllrefclklost_out                  : out  std_logic;
    gt0_cpllreset_in                        : in   std_logic;
    -------------------------- Channel - Clocking Ports ------------------------
    gt0_gtrefclk0_in                        : in   std_logic;
    gt0_gtrefclk1_in                        : in   std_logic;
    ---------------------------- Channel - DRP Ports  --------------------------
    gt0_drpaddr_in                          : in   std_logic_vector(8 downto 0);
    gt0_drpclk_in                           : in   std_logic;
    gt0_drpdi_in                            : in   std_logic_vector(15 downto 0);
    gt0_drpdo_out                           : out  std_logic_vector(15 downto 0);
    gt0_drpen_in                            : in   std_logic;
    gt0_drprdy_out                          : out  std_logic;
    gt0_drpwe_in                            : in   std_logic;
    --------------------------- Digital Monitor Ports --------------------------
    gt0_dmonitorout_out                     : out  std_logic_vector(7 downto 0);
    --------------------- RX Initialization and Reset Ports --------------------
    gt0_eyescanreset_in                     : in   std_logic;
    gt0_rxuserrdy_in                        : in   std_logic;
    -------------------------- RX Margin Analysis Ports ------------------------
    gt0_eyescandataerror_out                : out  std_logic;
    gt0_eyescantrigger_in                   : in   std_logic;
    ------------------ Receive Ports - FPGA RX Interface Ports -----------------
    gt0_rxusrclk_in                         : in   std_logic;
    gt0_rxusrclk2_in                        : in   std_logic;
    ------------------ Receive Ports - FPGA RX interface Ports -----------------
    gt0_rxdata_out                          : out  std_logic_vector(15 downto 0);
    ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
    gt0_rxdisperr_out                       : out  std_logic_vector(1 downto 0);
    gt0_rxnotintable_out                    : out  std_logic_vector(1 downto 0);
    --------------------------- Receive Ports - RX AFE -------------------------
    gt0_gtxrxp_in                           : in   std_logic;
    ------------------------ Receive Ports - RX AFE Ports ----------------------
    gt0_gtxrxn_in                           : in   std_logic;
    ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
    gt0_rxdlyen_in                          : in   std_logic;
    gt0_rxdlysreset_in                      : in   std_logic;
    gt0_rxdlysresetdone_out                 : out  std_logic;
    gt0_rxphalign_in                        : in   std_logic;
    gt0_rxphaligndone_out                   : out  std_logic;
    gt0_rxphalignen_in                      : in   std_logic;
    gt0_rxphdlyreset_in                     : in   std_logic;
    gt0_rxphmonitor_out                     : out  std_logic_vector(4 downto 0);
    gt0_rxphslipmonitor_out                 : out  std_logic_vector(4 downto 0);
    -------------------- Receive Ports - RX Equailizer Ports -------------------
    gt0_rxlpmhfhold_in                      : in   std_logic;
    gt0_rxlpmlfhold_in                      : in   std_logic;
    --------------------- Receive Ports - RX Equalizer Ports -------------------
    gt0_rxdfelpmreset_in                    : in   std_logic;
    gt0_rxmonitorout_out                    : out  std_logic_vector(6 downto 0);
    gt0_rxmonitorsel_in                     : in   std_logic_vector(1 downto 0);
    --------------- Receive Ports - RX Fabric Output Control Ports -------------
    gt0_rxoutclk_out                        : out  std_logic;
    gt0_rxoutclkfabric_out                  : out  std_logic;
    ------------- Receive Ports - RX Initialization and Reset Ports ------------
    gt0_gtrxreset_in                        : in   std_logic;
    gt0_rxpmareset_in                       : in   std_logic;
    ----------------- Receive Ports - RX Polarity Control Ports ----------------
    gt0_rxpolarity_in                       : in   std_logic;
    ---------------------- Receive Ports - RX gearbox ports --------------------
    gt0_rxslide_in                          : in   std_logic;
    gt0_rxbyteisaligned_out                 : out std_logic;
    ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    gt0_rxcharisk_out                       : out  std_logic_vector(1 downto 0);
    -------------- Receive Ports -RX Initialization and Reset Ports ------------
    gt0_rxresetdone_out                     : out  std_logic;
    --------------------- TX Initialization and Reset Ports --------------------
    gt0_gttxreset_in                        : in   std_logic;
    gt0_txuserrdy_in                        : in   std_logic;
    ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
    gt0_txusrclk_in                         : in   std_logic;
    gt0_txusrclk2_in                        : in   std_logic;
    ------------------ Transmit Ports - TX Buffer Bypass Ports -----------------
    gt0_txdlyen_in                          : in   std_logic;
    gt0_txdlysreset_in                      : in   std_logic;
    gt0_txdlysresetdone_out                 : out  std_logic;
    gt0_txphalign_in                        : in   std_logic;
    gt0_txphaligndone_out                   : out  std_logic;
    gt0_txphalignen_in                      : in   std_logic;
    gt0_txphdlyreset_in                     : in   std_logic;
    gt0_txphinit_in                         : in   std_logic;
    gt0_txphinitdone_out                    : out  std_logic;
    ------------------ Transmit Ports - TX Data Path interface -----------------
    gt0_txdata_in                           : in   std_logic_vector(15 downto 0);
    ---------------- Transmit Ports - TX Driver and OOB signaling --------------
    gt0_gtxtxn_out                          : out  std_logic;
    gt0_gtxtxp_out                          : out  std_logic;
    ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    gt0_txoutclk_out                        : out  std_logic;
    gt0_txoutclkfabric_out                  : out  std_logic;
    gt0_txoutclkpcs_out                     : out  std_logic;
    --------------------- Transmit Ports - TX Gearbox Ports --------------------
    gt0_txcharisk_in                        : in   std_logic_vector(1 downto 0);
    ------------- Transmit Ports - TX Initialization and Reset Ports -----------
    gt0_txresetdone_out                     : out  std_logic;
    ----------------- Transmit Ports - TX Polarity Control Ports ---------------
    gt0_txpolarity_in                       : in   std_logic;
    
    loop_test : in std_logic;
    prbs_err : out std_logic;


    --____________________________COMMON PORTS________________________________
     GT0_QPLLOUTCLK_IN : in std_logic;
     GT0_QPLLOUTREFCLK_IN : in std_logic

);


end gtwizard_0_multi_gt;
    
architecture RTL of gtwizard_0_multi_gt is
    attribute DowngradeIPIdentifiedWarnings: string;
    attribute DowngradeIPIdentifiedWarnings of RTL : architecture is "yes";

    attribute CORE_GENERATION_INFO : string;
    attribute CORE_GENERATION_INFO of RTL : architecture is "gtwizard_0_multi_gt,gtwizard_v3_6_9,{protocol_file=Start_from_scratch}";


--***********************************Parameter Declarations********************

    constant DLY : time := 1 ns;

--***************************** Signal Declarations *****************************

    -- ground and tied_to_vcc_i signals
    signal  tied_to_ground_i                :   std_logic;
    signal  tied_to_ground_vec_i            :   std_logic_vector(63 downto 0);
    signal  tied_to_vcc_i                   :   std_logic;
    signal   gt0_qplloutclk_i         :   std_logic;
    signal   gt0_qplloutrefclk_i      :   std_logic;

    signal  gt0_mgtrefclktx_i           :   std_logic_vector(1 downto 0);
    signal  gt0_mgtrefclkrx_i           :   std_logic_vector(1 downto 0);
    signal gt0_txoutclkfabric_i  :   std_logic ;
 
    signal gt0_rxoutclkfabric_i  :   std_logic;
 
 
 
    signal   gt0_qpllclk_i            :   std_logic;
    signal   gt0_qpllrefclk_i         :   std_logic;
    signal   gt0_cpllreset_i            :   std_logic;
    signal   gt0_cpllpd_i         :   std_logic;
    signal   cpll_reset0_i            :   std_logic;
    signal   cpll_pd0_i         :   std_logic;

--*************************** Component Declarations **************************
component gtwizard_0_GT
generic
(
    -- Simulation attributes
    GT_SIM_GTRESET_SPEEDUP       : string   := "FALSE";
    RX_DFE_KL_CFG2_IN            : bit_vector :=   X"3010D90C";
    PMA_RSV_IN                   : bit_vector :=   X"00000000";
    SIM_CPLLREFCLK_SEL           : bit_vector :=   "001";
    PCS_RSVD_ATTR_IN             : bit_vector :=   X"000000000000"
);
port 
(   
     cpllpd_in : in std_logic;
     cpllrefclksel_in : in std_logic_vector (2 downto 0);
    --------------------------------- CPLL Ports -------------------------------
    cpllfbclklost_out                       : out  std_logic;
    cplllock_out                            : out  std_logic;
    cplllockdetclk_in                       : in   std_logic;
    cpllrefclklost_out                      : out  std_logic;
    cpllreset_in                            : in   std_logic;
    -------------------------- Channel - Clocking Ports ------------------------
    gtrefclk0_in                            : in   std_logic;
    gtrefclk1_in                            : in   std_logic;
    ---------------------------- Channel - DRP Ports  --------------------------
    drpaddr_in                              : in   std_logic_vector(8 downto 0);
    drpclk_in                               : in   std_logic;
    drpdi_in                                : in   std_logic_vector(15 downto 0);
    drpdo_out                               : out  std_logic_vector(15 downto 0);
    drpen_in                                : in   std_logic;
    drprdy_out                              : out  std_logic;
    drpwe_in                                : in   std_logic;
    ------------------------------- Clocking Ports -----------------------------
    qpllclk_in                              : in   std_logic;
    qpllrefclk_in                           : in   std_logic;
    --------------------------- Digital Monitor Ports --------------------------
    dmonitorout_out                         : out  std_logic_vector(7 downto 0);
    --------------------- RX Initialization and Reset Ports --------------------
    eyescanreset_in                         : in   std_logic;
    rxuserrdy_in                            : in   std_logic;
    -------------------------- RX Margin Analysis Ports ------------------------
    eyescandataerror_out                    : out  std_logic;
    eyescantrigger_in                       : in   std_logic;
    ------------------ Receive Ports - FPGA RX Interface Ports -----------------
    rxusrclk_in                             : in   std_logic;
    rxusrclk2_in                            : in   std_logic;
    ------------------ Receive Ports - FPGA RX interface Ports -----------------
    rxdata_out                              : out  std_logic_vector(15 downto 0);
    ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
    rxdisperr_out                           : out  std_logic_vector(1 downto 0);
    rxnotintable_out                        : out  std_logic_vector(1 downto 0);
    --------------------------- Receive Ports - RX AFE -------------------------
    gtxrxp_in                               : in   std_logic;
    ------------------------ Receive Ports - RX AFE Ports ----------------------
    gtxrxn_in                               : in   std_logic;
    ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
    rxdlyen_in                              : in   std_logic;
    rxdlysreset_in                          : in   std_logic;
    rxdlysresetdone_out                     : out  std_logic;
    rxphalign_in                            : in   std_logic;
    rxphaligndone_out                       : out  std_logic;
    rxphalignen_in                          : in   std_logic;
    rxphdlyreset_in                         : in   std_logic;
    rxphmonitor_out                         : out  std_logic_vector(4 downto 0);
    rxphslipmonitor_out                     : out  std_logic_vector(4 downto 0);
    -------------------- Receive Ports - RX Equailizer Ports -------------------
    rxlpmhfhold_in                          : in   std_logic;
    rxlpmlfhold_in                          : in   std_logic;
    --------------------- Receive Ports - RX Equalizer Ports -------------------
    rxdfelpmreset_in                        : in   std_logic;
    rxmonitorout_out                        : out  std_logic_vector(6 downto 0);
    rxmonitorsel_in                         : in   std_logic_vector(1 downto 0);
    --------------- Receive Ports - RX Fabric Output Control Ports -------------
    rxoutclk_out                            : out  std_logic;
    rxoutclkfabric_out                      : out  std_logic;
    ------------- Receive Ports - RX Initialization and Reset Ports ------------
    gtrxreset_in                            : in   std_logic;
    rxpmareset_in                           : in   std_logic;
    ----------------- Receive Ports - RX Polarity Control Ports ----------------
    rxpolarity_in                           : in   std_logic;
    ---------------------- Receive Ports - RX gearbox ports --------------------
    rxslide_in                              : in   std_logic;
    rxbyteisaligned                         : out std_logic;
    ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    rxcharisk_out                           : out  std_logic_vector(1 downto 0);
    -------------- Receive Ports -RX Initialization and Reset Ports ------------
    rxresetdone_out                         : out  std_logic;
    --------------------- TX Initialization and Reset Ports --------------------
    gttxreset_in                            : in   std_logic;
    txuserrdy_in                            : in   std_logic;
    ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
    txusrclk_in                             : in   std_logic;
    txusrclk2_in                            : in   std_logic;
    ------------------ Transmit Ports - TX Buffer Bypass Ports -----------------
    txdlyen_in                              : in   std_logic;
    txdlysreset_in                          : in   std_logic;
    txdlysresetdone_out                     : out  std_logic;
    txphalign_in                            : in   std_logic;
    txphaligndone_out                       : out  std_logic;
    txphalignen_in                          : in   std_logic;
    txphdlyreset_in                         : in   std_logic;
    txphinit_in                             : in   std_logic;
    txphinitdone_out                        : out  std_logic;
    ------------------ Transmit Ports - TX Data Path interface -----------------
    txdata_in                               : in   std_logic_vector(15 downto 0);
    ---------------- Transmit Ports - TX Driver and OOB signaling --------------
    gtxtxn_out                              : out  std_logic;
    gtxtxp_out                              : out  std_logic;
    ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    txoutclk_out                            : out  std_logic;
    txoutclkfabric_out                      : out  std_logic;
    txoutclkpcs_out                         : out  std_logic;
    --------------------- Transmit Ports - TX Gearbox Ports --------------------
    txcharisk_in                            : in   std_logic_vector(1 downto 0);
    ------------- Transmit Ports - TX Initialization and Reset Ports -----------
    txresetdone_out                         : out  std_logic;
    ----------------- Transmit Ports - TX Polarity Control Ports ---------------
    txpolarity_in                           : in   std_logic;
    loop_test : in std_logic;
    prbs_err : out std_logic


);
end component;
component gtwizard_0_cpll_railing
  Generic(
           USE_BUFG       : integer := 0
);
port 
(   
        cpll_reset_out : out std_logic;
         cpll_pd_out : out std_logic;
         refclk_out : out std_logic;
        
         refclk_in : in std_logic

);
end component;



--********************************* Main Body of Code**************************

begin                       

    tied_to_ground_i                    <= '0';
    tied_to_ground_vec_i(63 downto 0)   <= (others => '0');
    tied_to_vcc_i                       <= '1';
    gt0_qpllclk_i    <= GT0_QPLLOUTCLK_IN;  
    gt0_qpllrefclk_i <= GT0_QPLLOUTREFCLK_IN; 


 
    --------------------------- GT Instances  -------------------------------   
gt0_txoutclkfabric_out <= gt0_txoutclkfabric_i;
 
 

    --_________________________________________________________________________
    --_________________________________________________________________________
    --GT0  (X0Y0)

gt0_gtwizard_0_i : gtwizard_0_GT 
    generic map
    (
        -- Simulation attributes
        GT_SIM_GTRESET_SPEEDUP        =>  WRAPPER_SIM_GTRESET_SPEEDUP,
        RX_DFE_KL_CFG2_IN             =>  RX_DFE_KL_CFG2_IN,
        SIM_CPLLREFCLK_SEL            =>  "001",
        PMA_RSV_IN                    =>  PMA_RSV_IN,
        PCS_RSVD_ATTR_IN              =>  X"000000000000"
    )
    port map
    (
        cpllpd_in => gt0_cpllpd_i,
        cpllrefclksel_in => "001",
        --------------------------------- CPLL Ports -------------------------------
        cpllfbclklost_out               =>      gt0_cpllfbclklost_out,
        cplllock_out                    =>      gt0_cplllock_out,
        cplllockdetclk_in               =>      gt0_cplllockdetclk_in,
        cpllrefclklost_out              =>      gt0_cpllrefclklost_out,
        cpllreset_in                    =>      gt0_cpllreset_i,
        -------------------------- Channel - Clocking Ports ------------------------
        gtrefclk0_in                    =>      gt0_gtrefclk0_in,
        gtrefclk1_in                    =>      gt0_gtrefclk1_in,
        ---------------------------- Channel - DRP Ports  --------------------------
        drpaddr_in                      =>      gt0_drpaddr_in,
        drpclk_in                       =>      gt0_drpclk_in,
        drpdi_in                        =>      gt0_drpdi_in,
        drpdo_out                       =>      gt0_drpdo_out,
        drpen_in                        =>      gt0_drpen_in,
        drprdy_out                      =>      gt0_drprdy_out,
        drpwe_in                        =>      gt0_drpwe_in,
        ------------------------------- Clocking Ports -----------------------------
        qpllclk_in                      =>      gt0_qpllclk_i,
        qpllrefclk_in                   =>      gt0_qpllrefclk_i,
        --------------------------- Digital Monitor Ports --------------------------
        dmonitorout_out                 =>      gt0_dmonitorout_out,
        --------------------- RX Initialization and Reset Ports --------------------
        eyescanreset_in                 =>      gt0_eyescanreset_in,
        rxuserrdy_in                    =>      gt0_rxuserrdy_in,
        -------------------------- RX Margin Analysis Ports ------------------------
        eyescandataerror_out            =>      gt0_eyescandataerror_out,
        eyescantrigger_in               =>      gt0_eyescantrigger_in,
        ------------------ Receive Ports - FPGA RX Interface Ports -----------------
        rxusrclk_in                     =>      gt0_rxusrclk_in,
        rxusrclk2_in                    =>      gt0_rxusrclk2_in,
        ------------------ Receive Ports - FPGA RX interface Ports -----------------
        rxdata_out                      =>      gt0_rxdata_out,
        ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
        rxdisperr_out                   =>      gt0_rxdisperr_out,
        rxnotintable_out                =>      gt0_rxnotintable_out,
        --------------------------- Receive Ports - RX AFE -------------------------
        gtxrxp_in                       =>      gt0_gtxrxp_in,
        ------------------------ Receive Ports - RX AFE Ports ----------------------
        gtxrxn_in                       =>      gt0_gtxrxn_in,
        ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
        rxdlyen_in                      =>      gt0_rxdlyen_in,
        rxdlysreset_in                  =>      gt0_rxdlysreset_in,
        rxdlysresetdone_out             =>      gt0_rxdlysresetdone_out,
        rxphalign_in                    =>      gt0_rxphalign_in,
        rxphaligndone_out               =>      gt0_rxphaligndone_out,
        rxphalignen_in                  =>      gt0_rxphalignen_in,
        rxphdlyreset_in                 =>      gt0_rxphdlyreset_in,
        rxphmonitor_out                 =>      gt0_rxphmonitor_out,
        rxphslipmonitor_out             =>      gt0_rxphslipmonitor_out,
        -------------------- Receive Ports - RX Equailizer Ports -------------------
        rxlpmhfhold_in                  =>      gt0_rxlpmhfhold_in,
        rxlpmlfhold_in                  =>      gt0_rxlpmlfhold_in,
        --------------------- Receive Ports - RX Equalizer Ports -------------------
        rxdfelpmreset_in                =>      gt0_rxdfelpmreset_in,
        rxmonitorout_out                =>      gt0_rxmonitorout_out,
        rxmonitorsel_in                 =>      gt0_rxmonitorsel_in,
        --------------- Receive Ports - RX Fabric Output Control Ports -------------
        rxoutclk_out                    =>      gt0_rxoutclk_out,
        rxoutclkfabric_out              =>      gt0_rxoutclkfabric_out,
        ------------- Receive Ports - RX Initialization and Reset Ports ------------
        gtrxreset_in                    =>      gt0_gtrxreset_in,
        rxpmareset_in                   =>      gt0_rxpmareset_in,
        ----------------- Receive Ports - RX Polarity Control Ports ----------------
        rxpolarity_in                   =>      gt0_rxpolarity_in,
        ---------------------- Receive Ports - RX gearbox ports --------------------
        rxslide_in                      =>      gt0_rxslide_in,
        rxbyteisaligned                 =>      gt0_rxbyteisaligned_out,
        ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
        rxcharisk_out                   =>      gt0_rxcharisk_out,
        -------------- Receive Ports -RX Initialization and Reset Ports ------------
        rxresetdone_out                 =>      gt0_rxresetdone_out,
        --------------------- TX Initialization and Reset Ports --------------------
        gttxreset_in                    =>      gt0_gttxreset_in,
        txuserrdy_in                    =>      gt0_txuserrdy_in,
        ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
        txusrclk_in                     =>      gt0_txusrclk_in,
        txusrclk2_in                    =>      gt0_txusrclk2_in,
        ------------------ Transmit Ports - TX Buffer Bypass Ports -----------------
        txdlyen_in                      =>      gt0_txdlyen_in,
        txdlysreset_in                  =>      gt0_txdlysreset_in,
        txdlysresetdone_out             =>      gt0_txdlysresetdone_out,
        txphalign_in                    =>      gt0_txphalign_in,
        txphaligndone_out               =>      gt0_txphaligndone_out,
        txphalignen_in                  =>      gt0_txphalignen_in,
        txphdlyreset_in                 =>      gt0_txphdlyreset_in,
        txphinit_in                     =>      gt0_txphinit_in,
        txphinitdone_out                =>      gt0_txphinitdone_out,
        ------------------ Transmit Ports - TX Data Path interface -----------------
        txdata_in                       =>      gt0_txdata_in,
        ---------------- Transmit Ports - TX Driver and OOB signaling --------------
        gtxtxn_out                      =>      gt0_gtxtxn_out,
        gtxtxp_out                      =>      gt0_gtxtxp_out,
        ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        txoutclk_out                    =>      gt0_txoutclk_out,
        txoutclkfabric_out              =>      gt0_txoutclkfabric_i,
        txoutclkpcs_out                 =>      gt0_txoutclkpcs_out,
        --------------------- Transmit Ports - TX Gearbox Ports --------------------
        txcharisk_in                    =>      gt0_txcharisk_in,
        ------------- Transmit Ports - TX Initialization and Reset Ports -----------
        txresetdone_out                 =>      gt0_txresetdone_out,
        ----------------- Transmit Ports - TX Polarity Control Ports ---------------
        txpolarity_in                   =>      gt0_txpolarity_in,
     loop_test => loop_test,
     prbs_err => prbs_err

    );


   cpll_railing0_i : gtwizard_0_cpll_railing
  generic map(
           USE_BUFG       => USE_BUFG
   ) 
   port map
   (
        cpll_reset_out => cpll_reset0_i,
        cpll_pd_out => cpll_pd0_i,
        refclk_out => open,
        refclk_in => gt0_gtrefclk0_in
);


gt0_cpllreset_i <= cpll_reset0_i or gt0_cpllreset_in; 
gt0_cpllpd_i <= cpll_pd0_i ; 
end RTL;     
