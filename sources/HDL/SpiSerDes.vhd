-------------------------------------------------------------------------------
-- Copyright (c) 2010 Xilinx, Inc.
-- This design is confidential and proprietary of Xilinx, All Rights Reserved.
-------------------------------------------------------------------------------
--   ____  ____
--  /   /\/   /
-- /___/  \  /   Vendor:                Xilinx, Inc.
-- \   \   \/    Version:               1.00
--  \   \        Filename:              SpiSerDes.vhd
--  /   /        Date Last Modified:    October 25 2009
-- /___/   /\    Date Created:          October 25 2009
-- \   \  /  \
--  \___\/\___\
--
--Devices:      Spartan-6, Virtex-5, Virtex-6, 7 series FPGAs
--Purpose:      This module serializes and deserializes a byte's worth of
--              data to/from a SPI device for a master SPI controller.
--Description:  This modules takes the following inputs:
--                inClk           - Module clock and forwarded to SPI bus clk.
--                                  The frequency of this clock must be less than
--                                  or equal to the Fmax of the peripheral(s) on
--                                  the SPI bus.
--                inReset_EnableB - Active-high synchronous reset.
--                                  When High, resets this module and 
--                                  also drives the SPI device chip-select High.
--                                  When Low, enables this module and 
--                                  also drives SPI device chip-select Low.
--                inData8Send     - The data byte to send to SPI device.
--                                  The input data byte is registered on the
--                                  first rising edge of inClk after 
--                                  inStartTransfer transitions to High (and 
--                                  when outTransferDone is High).
--                inStartTransfer - Start SPI serialization when this is High
--                                  and when outTransferDone=High.
--              This module has the following outputs:
--                outTransferDone - Signals when serialization is DONE.
--                                  Signal is driven Low on the first rising 
--                                  edge of inClk after inStartTransfer 
--                                  transitions to High.
--                                  Signal is returned to High after the module 
--                                  has completed the serialization of a byte 
--                                  of data.
--                outData8Receive - When outTransferDone=High, this output has 
--                                  the data byte received from the inSpiMiso 
--                                  pin during the serial transfer process.
--              This module is the master controller for SPI bus signals:
--                outSpiCsB   - Connect to SPI device active-low chip select
--                outSpiClk   - Connect to SPI bus clk
--                outSpiMosi  - Connect to SPI bus master-out, slave-input
--                inSpiMiso   - Connect to SPI bus master-in, slave-output
--              If another device can be a master of the SPI bus, then use 
--              outSpiCsB as the active-Low output enable control signal for 
--              all SPI bus outputs. When using outSpiCsB as an output enable,
--              all controlled outputs must have a pull-up, especially the SPI 
--              chip-select signal.
--Usage:        Module setup:
--              - Connect for SPI ports to SPI bus.  See above.
--              - Supply inClk.  Fmax determined by target (slave) SPI device.
--              Module use sequence:
--              1. Reset module:
--                1.A. Drive inReset_EnableB=High to reset module
--              2. Enable SPI device (SPI CSB=Low)
--                2.A. Drive inReset_enableB=Low to select target SPI device.
--              3. Serialize byte output via MOSI and byte input via MISO:
--                3.A. For each byte:
--                  3.A.1: Start serialization:
--                      inData8Send     <= byte to send
--                      inStartTransfer <= High
--                  3.A.2: Wait for serialization DONE
--                      Wait for outTransferDone=High
--                      Get parallel MISO data from outData8Receive
--              4. Disable SPI device (SPI CSB=High)
--                4.A. Drive inReset_EnableB=High
--              NOTES:
--              - All signals active/transition on rising-edge inClk except
--                outSpiMosi transitions on falling-edge of outSpiClk.
--              - If inStartTransfer=High when outTransferDone=High, then
--                next byte serialization starts on following rising inClk.
--                To prevent next byte serialization, set inStartTransfer=Low
--                before outTransferDone goes High.
--              - outSpiClk runs at same frequency and phase as inClk.
--                outSpiClk is gated.
--Signal Timing:
--                        _   _   _   _   _   _         _   _   _
--               inClk  _/ \_/ \_/ \_/ \_/ \_/ \.....\_/ \_/ \_/ \_
--                      ___                                   _____
--     inReset_EnableB     \_________________________________/
--                      _____                                   ___
--           outSpiCsB       \_________________________________/
--                              ___________________________________
--     inStartTransfer  _______/   \\\\\\\\\\\\\\\\\\\\\\\\*\\\\\\\
--                      _________                       ___________
--     outTransferDone           \______________.....__/
--                      _______ ___
--    inData8Send[7:0]  _______XD8SXXX...
--                                  ___ ___ ___       ___ _________
--           inSpiMosi             XD7_XD6_XD5_X.....XD0_X_________
--                      ___________   _   _   _    _    ___________
--           outSpiClk             \_/ \_/ \_/ \.....\_/
--                                                      ___________
--outData8Receive[7:0]           XD8SX               XXXD8R*D8SX___
--  *Note: if inStartTransfer=High, then inData8Send loaded into outData8Receive
--Reference:
--Revision History:
--    Revision (YYYY/MM/DD) - [User] Description
--    Rev 1.00 (2009/10/25) - [RMK] Created.
-------------------------------------------------------------------------------
library ieee;
Library UNISIM;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use UNISIM.vcomponents.all;

entity SpiSerDes is
  port 
  (
    -- SerDes clock and control signals
    inClk           : in  std_logic;  -- System clock. Fmax <= SPI peripheral Fmax.
    inReset_EnableB : in  std_logic;  -- Active-high, synchronous reset.
    inStartTransfer : in  std_logic;  -- Active-high, initiate transfer of data
    outTransferDone : out std_logic;  -- DONE='1' when transfer is done

    -- Parallel data ports
    isQuadWrite : in std_logic;  -- indicate quad write
    isQuadRead : in std_logic; -- indicate quad read
    inData8Send     : in  std_logic_vector(7 downto 0); -- Sent to SPI device
    outData8Receive : out std_logic_vector(7 downto 0); -- Received from SPI device

    -- SPI ports and tristate control - Connect these to the SPI bus
    outSpiCsB       : out std_logic;  -- SPI chip-select to SPI device 
                                      -- or all SPI outputs control enable
    outSpiClk       : out std_logic;  -- SPI clock to SPI device
    outSpiMosi      : inout std_logic;  -- SPI master-out, slave-in to SPI device;IO0
    inSpiMiso       : inout  std_logic;   -- SPI master-in, slave-out from SPI device;IO1
    outSpiWpB : inout std_logic; --IO2
    outSpiHoldB : inout std_logic;    --IO3
    
    mosi : out std_logic;
    miso : out std_logic
  );
end SpiSerDes;

architecture behavioral of SpiSerDes is

  -- Constants
  constant  cShiftCountInit : std_logic_vector(8 downto 0)  := B"000000001";
  constant  cQuadCountInit : std_logic_vector(2 downto 0) := B"001";

  -- Registers
  signal    regShiftCount   : std_logic_vector(8 downto 0)  := cShiftCountInit;
  signal    regQuadCount   : std_logic_vector(2 downto 0)  := cQuadCountInit;
  signal    regShiftData    : std_logic_vector(7 downto 0)  := B"00000000";
  signal    regSpiCsB       : std_logic                     := '1';
  signal    regSpiMosi      : std_logic                     := '1';
  signal    regTransferDoneDelayed  : std_logic             := '1';
  signal    regQuadin : std_logic_vector(3 downto 0);
  signal    regQuadout : std_logic_vector(3 downto 0);
  -- Signals
  signal    intTransferDone,spiMosi_o : std_logic;

  -- Attributes
  attribute clock_signal    : string;
  attribute clock_signal    of inClk : signal is "yes";

begin
  -- Internal signals
  intTransferDone <= regShiftCount(0) when (isQuadRead = '0' and isQuadWrite = '0') else
                     regQuadCount(0);

  -- TransferDone delayed by half clock cycle
  processTransferDone : process (inClk)
  begin
    if (falling_edge(inClk)) then
      regTransferDoneDelayed  <= intTransferDone;
    end if;
  end process processTransferDone;

  -- SPI chip-select (active-Low) is always inverse of inReset_EnableB.
  processSpiCsB : process (inClk)
  begin
    if (rising_edge(inClk)) then
      regSpiCsB <= inReset_EnableB;
    end if;
  end process processSpiCsB;

  -- Track transfer of serial data with barrel shifter.
  processShiftCount : process (inClk)
  begin
    if (rising_edge(inClk)) then
      if (inReset_EnableB='1') then
        regShiftCount <= cShiftCountInit;
        regQuadCount <= cQuadCountInit;
      elsif ((intTransferDone='0') or (inStartTransfer='1')) then
        -- Barrel shift (rotate right)
        if (isQuadRead = '1' or isQuadWrite = '1') then
            regQuadCount <= regQuadCount(0) & regQuadCount(2 downto 1);
        else
            regShiftCount <= regShiftCount(0) & regShiftCount(8 downto 1);
        end if;
      end if;
    end if;
  end process processShiftCount;

  -- Simultaneous serialize outgoing data & deserialize incoming data. MSB first
  processShiftData : process (inClk)
  begin
    if (rising_edge(inClk)) then
      if (intTransferDone='0') then
        -- SHIFT-left while not outTransferDone
        if isQuadRead = '1' then
            regShiftData <= regShiftData(3 downto 0) & regQuadin;
        elsif isQuadWrite = '1' then
            regShiftData <= regShiftData(3 downto 0) & regShiftData(7 downto 4);
        else
            regShiftData  <= regShiftData(6 downto 0) & regQuadin(1);
        end if;
      elsif (inStartTransfer='1') then
        -- Load data to start a new transfer sequence from a done state
        regShiftData  <= inData8Send;
      end if;
    end if;
  end process processShiftData;

  --SPI MOSI register outputs on falling edge of inClk.  MSB first.
  processSpiMosi : process (inClk)
  begin
    if (falling_edge(inClk)) then
      if (inReset_EnableB='1') then
        --regSpiMosi  <= '1';
        regQuadout <= x"1";
      elsif (intTransferDone='0') then
        if isQuadWrite = '1' then
            regQuadout <= regShiftData(7 downto 4);
        else
            regQuadout(0)  <= regShiftData(7);
        end if;
      end if;
    end if;
  end process processSpiMosi;

  -- Assign outputs
  outSpiClk       <= (inClk or intTransferDone or regTransferDoneDelayed);
  outSpiCsB       <= regSpiCsB;

  outTransferDone <= intTransferDone;
  outData8Receive <= regShiftData;
  
  Inst_iobuf0: IOBUF
    port map(
    O => regQuadin(0),
    IO => outSpiMosi,
    I => regQuadout(0),
    T => isQuadRead
    );
    mosi <= regQuadout(0);
    --spiMosi_o <= regQuadout(0) when isQuadWrite = '1' else regSpiMosi;
  Inst_iobuf1: IOBUF
    port map(
    O => regQuadin(1),
    IO => inSpiMiso,
    I => regQuadout(1),
    T => not isQuadWrite
    );
    miso <= regQuadin(1);
  Inst_iobuf2: IOBUF
    port map(
    O => regQuadin(2),
    IO => outSpiWpB,
    I => regQuadout(2),
    T => not isQuadWrite
    );
  Inst_iobuf3: IOBUF
    port map(
    O => regQuadin(3),
    IO => outSpiHoldB,
    I => regQuadout(3),
    T => not isQuadWrite
    );

  -- Inst_ila: entity work.ila_3
    -- port map(
    -- clk => inClk,
    -- probe0 => regQuadout,
    -- probe1 => regQuadin,
    -- probe2(0) => isQuadWrite,
    -- probe3(0) => isQuadRead,
    -- probe4(0) => intTransferDone,
    -- probe5(0) => regSpiCsB,
    -- probe6 => regShiftData
    -- );
end behavioral;

