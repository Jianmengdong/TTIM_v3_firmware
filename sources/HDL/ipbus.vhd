library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;
use work.ipbus.all;
use work.TTIM_pack.all;

entity ipbus_body is
    generic (g_cs_wonly_deep : natural:= 54; -- configuration space number of write only registers;
           g_cs_ronly_deep : natural:= 200;  -- configuration space number of read only registers;
	        g_NSLV          : positive := 5
           ); 
    Port ( 
    eth_clk_p: in std_logic; -- 125MHz MGT clock
	eth_clk_n: in std_logic;
    --sys_clk :in std_logic;
    gtrefclk_out :out std_logic;
	eth_rx_p: in std_logic; -- Ethernet MGT input
	eth_rx_n: in std_logic;
	eth_tx_p: out std_logic; -- Ethernet MGT output
	eth_tx_n: out std_logic;
    mac_addr: in std_logic_vector(47 downto 0); -- MAC address
    ip_addr: in std_logic_vector(31 downto 0); -- IP address
    
    cs_data_o:out t_array32(g_cs_wonly_deep-1 downto 0);
    cs_data_i:in t_array32(g_cs_ronly_deep-1 downto 0)
    );
end ipbus_body;

architecture Behavioral of ipbus_body is
    signal ipb_master_out: ipb_wbus;
	signal ipb_master_in: ipb_rbus;
    signal rst_ipb,ipb_clk,pkt_rx,pkt_tx,soft_rst : std_logic;
	signal s_cs_data_o     : std_logic_vector(g_cs_wonly_deep*32-1 downto 0) := (others => '0');
    signal s_cs_data_i     : std_logic_vector(g_cs_ronly_deep*32-1 downto 0);
begin
ipbus_core: entity work.kc705_basex_infra
	port map(
		eth_clk_p => eth_clk_p,
		eth_clk_n => eth_clk_n,
        --sys_clk => sys_clk,
		gtrefclk_out => gtrefclk_out,
		eth_tx_p => eth_tx_p,
		eth_tx_n => eth_tx_n,
		eth_rx_p => eth_rx_p,
		eth_rx_n => eth_rx_n,
		sfp_los => '0',
		clk_ipb_o => ipb_clk,
		rst_ipb_o => rst_ipb,
		nuke => '0',
		soft_rst => soft_rst,
		leds => open,
		mac_addr => mac_addr,
		ip_addr => ip_addr,
		ipb_in => ipb_master_in,
		ipb_out => ipb_master_out,
        pkt_rx => pkt_rx,
        pkt_tx => pkt_tx,
        clk125_out => open,
        phy_done_out => open
	);
    --mac_addr <= X"021ddba11509"; -- Careful here, arbitrary addresses do not always work
	--ip_addr <= X"C0A80110";  -- 192.168.1.16
    
    ipbus_slaves: entity work.slaves
    generic map(
	    g_cs_wonly_deep => g_cs_wonly_deep, -- configuration space number of write only registers;
        g_cs_ronly_deep => g_cs_ronly_deep,  -- configuration space number of read only registers;
	    g_NSLV          => g_NSLV
        )
    port map(
	    ipb_clk          => ipb_clk,  -- 31.25 MHz
	    ipb_rst          => rst_ipb,
	    ipb_in           => ipb_master_out,
	    ipb_out          => ipb_master_in,
	    rst_out          => soft_rst,
	    cs_data_o        => s_cs_data_o,
	    cs_data_i        => s_cs_data_i,
	    pkt_rx           => pkt_rx,
	    pkt_tx           => pkt_tx
	    );
    Gen_cs_data_o:for i in g_cs_wonly_deep-1 downto 0 generate
        cs_data_o(i) <= s_cs_data_o((i+1)*32-1 downto i * 32);
    end generate;
    Gen_cs_data_i:for i in g_cs_ronly_deep-1 downto 0 generate
        s_cs_data_i((i+1)*32-1 downto i * 32) <= cs_data_i(i);
    end generate;
end Behavioral;
