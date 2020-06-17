
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity remote_update_top is
    Port ( 
    clk_i : in STD_LOGIC;
    clk_x2_i : in STD_LOGIC;
    -- SPIx4 interface
    outSpiCsB           : out std_logic;
    outSpiMosi_IO0          : inout std_logic;
    inSpiMiso_IO1           : inout std_logic;
    outSpiWpB_IO2           : inout std_logic; -- SPI flash write protect
    outSpiHoldB_IO3         : inout std_logic;
    update_data     : in std_logic_vector(127 downto 0);
    update_data_valid : in std_logic;
    update_fifo_empty : out std_logic;
    outSFPStatus : out std_logic_vector(8 downto 0);
    outSFPError : out std_logic_vector(5 downto 0);
    inUpdateControl : in std_logic_vector(19 downto 0) := x"00001"
    );
end remote_update_top;

architecture Behavioral of remote_update_top is

    signal intSFPCheckIdOnly,intSFPVerifyOnly : std_logic;
    signal intSFPData32 : std_logic_vector(31 downto 0);
    signal intSFPDataValid,intSFPFifoRdEn,intSFPReady_BusyB,intSFPDone : std_logic;
    signal intSFPSSDReset_EnableB,intSFPSSDStartTransfer,intSFPSSDTransferDone: std_logic;
    signal intSSDReset_EnableB,intSSDStartTransfer,intSSDTransferDone: std_logic;
    signal intSFPSSDData8Send,intSFPSSDData8Receive : std_logic_vector(7 downto 0);
    signal intSSDData8Send,intSSDData8Receive : std_logic_vector(7 downto 0);
    signal intSSDisQuadWrite,intSSDisQuadRead,intSFPisQuadRead,intSFPisQuadWrite : std_logic;
    signal intBufgTck,intSpiClk : std_logic;
    signal update_control : std_logic_vector(19 downto 0);
begin
intBufgTck <= clk_i;
iSpiFlashProgrammer:entity work.SpiFlashProgrammer
  port map
  (
    inClk                 => intBufgTck,
    inReset_EnableB       => inUpdateControl(0),  --reset FSM
    inCheckIdOnly         => inUpdateControl(1),
    inVerify              => inUpdateControl(2),
    inChangeModeOnly      => inUpdateControl(3),
    inModeRegister        => inUpdateControl(19 downto 4),
    inData32              => intSFPData32, --data to write
    inDataWriteEnable     => intSFPDataValid, 
    outFifoRdEn           => intSFPFifoRdEn,
    outReady_BusyB        => intSFPReady_BusyB, --'0' indicate busy
    outDone               => intSFPDone, --programm done
    outError              => outSFPError(0),
    outErrorIdcode        => outSFPError(1),
    outErrorErase         => outSFPError(2),
    outErrorProgram       => outSFPError(3),
    outErrorTimeOut       => outSFPError(4),
    outErrorCrc           => outSFPError(5),
    outStarted            => outSFPStatus(0),
    outInitializeOK       => outSFPStatus(1),
    outCheckIdOK          => outSFPStatus(2),
    outEraseSwitchWordOK  => outSFPStatus(3),
    outEraseOK            => outSFPStatus(4),
    outProgramOK          => outSFPStatus(5),
    outVerifyOK           => outSFPStatus(6),
    outProgramSwitchWordOK=> outSFPStatus(7),
    outModeChangeOK       => outSFPStatus(8),
    outSSDReset_EnableB   => intSFPSSDReset_EnableB,
    outSSDStartTransfer   => intSFPSSDStartTransfer,
    inSSDTransferDone     => intSFPSSDTransferDone,
    isQuadRead            => intSFPisQuadRead,
    isQuadWrite           => intSFPisQuadWrite,
    outSSDData8Send       => intSFPSSDData8Send,
    inSSDData8Receive     => intSFPSSDData8Receive
  );
  iMuxToSpiSerDes :entity work.MuxToSpiSerDes
  port map
  (
    inMuxSelect           => '1',
    inPort0Reset_EnableB  => '1',
    inPort0StartTransfer  => '0',
    outPort0TransferDone  => open,
    inPort0isQuadWrite   => '0',
    inPort0isQuadRead    => '0',
    inPort0Data8Send      => (others => '0'),
    outPort0Data8Receive  => open,
    inPort1Reset_EnableB  => intSFPSSDReset_EnableB,
    inPort1StartTransfer  => intSFPSSDStartTransfer,
    outPort1TransferDone  => intSFPSSDTransferDone,
    inPort1isQuadWrite   => intSFPisQuadWrite,
    inPort1isQuadRead    => intSFPisQuadRead,
    inPort1Data8Send      => intSFPSSDData8Send,
    outPort1Data8Receive  => intSFPSSDData8Receive,
    outPortYReset_EnableB => intSSDReset_EnableB,
    outPortYStartTransfer => intSSDStartTransfer,
    inPortYTransferDone   => intSSDTransferDone,
    outPortYisQuadWrite   => intSSDisQuadWrite,
    outPortYisQuadRead    => intSSDisQuadRead,
    outPortYData8Send     => intSSDData8Send,
    inPortYData8Receive   => intSSDData8Receive
  );
iSpiSerDes:entity work.SpiSerDes
port map
  (
    inClk           => intBufgTck,
    inReset_EnableB => intSSDReset_EnableB,
    inStartTransfer => intSSDStartTransfer,
    outTransferDone => intSSDTransferDone,
    isQuadWrite     => intSSDisQuadWrite,
    isQuadRead      => intSSDisQuadRead,
    inData8Send     => intSSDData8Send,
    outData8Receive => intSSDData8Receive,
    outSpiCsB       => outSpiCsB,
    outSpiClk       => intSpiClk,
    outSpiMosi      => outSpiMosi_IO0,
    inSpiMiso       => inSpiMiso_IO1,
    outSpiWpB => outSpiWpB_IO2,
    outSpiHoldB => outSpiHoldB_IO3
  );
STARTUPE2_inst : STARTUPE2
  port map (
    CLK => '0',
    GSR => '0', -- 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
    GTS => '0', -- 1-bit input: Global 3-state input (GTS cannot be used for the port name)
    KEYCLEARB => '1',
    PACK => '1', -- 1-bit input: PROGRAM acknowledge input
    USRCCLKO => intSpiClk, -- 1-bit input: User CCLK input
    USRCCLKTS => '0',
    USRDONEO => '1',
    USRDONETS => '1'
  );
Inst_LiteBus2SPI_fifo:entity work.bitstream_fifo
  PORT MAP (
    rst => inUpdateControl(0),
    wr_clk => clk_x2_i,
    rd_clk => clk_i,
    din => update_data,
    wr_en => update_data_valid,
    rd_en => intSFPFifoRdEn,
    dout => intSFPData32,
    full => open,
    empty => update_fifo_empty,
    almost_empty => open,
    valid => intSFPDataValid
  );

end Behavioral;
