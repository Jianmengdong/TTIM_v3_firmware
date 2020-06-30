-- The ipbus slaves live in this entity - modify according to requirements
--
-- Ports can be added to give ipbus slaves access to the chip top level.
--
-- Dave Newbold, February 2011

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use work.ipbus.all;
use work.TTIM_pack.all;

entity slaves is
  generic (g_cs_wonly_deep : natural:= 2; -- configuration space number of write only registers;
           g_cs_ronly_deep : natural:= 6;  -- configuration space number of read only registers;
	        g_NSLV          : positive := 11
           ); 
  port(
    ipb_clk        : in  std_logic;
    ipb_rst        : in  std_logic;
    ipb_in         : in  ipb_wbus;
    ipb_out        : out ipb_rbus;
    rst_out        : out std_logic;
    eth_err_ctrl   : out std_logic_vector(35 downto 0);
    eth_err_stat   : in  std_logic_vector(47 downto 0) := X"000000000000";
    cs_data_o      : out std_logic_vector(g_cs_wonly_deep*32-1 downto 0);
    cs_data_i      : in  std_logic_vector(g_cs_ronly_deep*32-1 downto 0);
    pkt_rx         : in  std_logic := '0';
    pkt_tx         : in  std_logic := '0'
    );

end slaves;

architecture rtl of slaves is
              
  signal   ipbw               : ipb_wbus_array(g_NSLV-1 downto 0);
  signal   ipbr, ipbr_d       : ipb_rbus_array(g_NSLV-1 downto 0);
  signal   ctrl_reg           : std_logic_vector(31 downto 0);
  signal   inj_ctrl, inj_stat : std_logic_vector(63 downto 0);
  
  signal init_clk : std_logic;
begin

  fabric : entity work.ipbus_fabric
    generic map(NSLV => g_NSLV)
    port map(
      ipb_in          => ipb_in,
      ipb_out         => ipb_out,
      ipb_to_slaves   => ipbw,
      ipb_from_slaves => ipbr
      );

-- Slave 0: id / rst reg 

  slave0 : entity work.ipbus_ctrlreg
    port map(
      clk       => ipb_clk,
      reset     => ipb_rst,
      ipbus_in  => ipbw(0),
      ipbus_out => ipbr(0),
      d         => X"abcdfedc",
      q         => ctrl_reg
      );

  rst_out <= ctrl_reg(0);

-- Slave 1: configuration space write only

  slave1 : entity work.ipbus_cs_write
    generic map(addr_width => f_log2(g_cs_wonly_deep),
	             g_cs_wonly_deep => g_cs_wonly_deep)
    port map(
      clk       => ipb_clk,
      reset     => ipb_rst,
      ipbus_in  => ipbw(1),
      ipbus_out => ipbr(1),
      q         => cs_data_o
      );

-- Slave 2: configuration space read only
  slave2 : entity work.ipbus_cs_read
   generic map(addr_width => f_log2(g_cs_ronly_deep),
	            g_cs_ronly_deep => g_cs_ronly_deep)
   port map(
     clk       => ipb_clk,
     reset     => ipb_rst,
     ipbus_in  => ipbw(2),
     ipbus_out => ipbr(2),
     d         => cs_data_i
     );

-- Slave 3: ethernet error injection

  slave3 : entity work.ipbus_ctrlreg
    generic map(
      ctrl_addr_width => 1,
      stat_addr_width => 1
      )
    port map(
      clk       => ipb_clk,
      reset     => ipb_rst,
      ipbus_in  => ipbw(3),
      ipbus_out => ipbr(3),
      d         => inj_stat,
      q         => inj_ctrl
      );

  eth_err_ctrl <= inj_ctrl(49 downto 32) & inj_ctrl(17 downto 0);
  inj_stat     <= X"00" & eth_err_stat(47 downto 24) & X"00" & eth_err_stat(23 downto 0);

-- Slave 4: packet counters

  slave4 : entity work.ipbus_pkt_ctr
    port map(
      clk       => ipb_clk,
      reset     => ipb_rst,
      ipbus_in  => ipbw(4),
      ipbus_out => ipbr(4),
      pkt_rx    => pkt_rx,
      pkt_tx    => pkt_tx
      );

 end rtl;
