-- Generic ipbus slave config register for testing
--
-- generic addr_width defines number of significant address bits
--
-- We use one cycle of read / write latency to ease timing (probably not necessary)
-- The q outputs change immediately on write (no latency).
--
-- Dave Newbold, March 2011

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use work.ipbus.all;

entity ipbus_cs_read is
  generic(addr_width : natural := 0;
          g_cs_ronly_deep : natural:= 6
          );
  port(
    clk       : in  std_logic;
    reset     : in  std_logic;
    ipbus_in  : in  ipb_wbus;
    ipbus_out : out ipb_rbus;
    d         : in std_logic_vector(g_cs_ronly_deep*32-1 downto 0)
    );

end ipbus_cs_read;

architecture rtl of ipbus_cs_read is

  type   reg_array is array(g_cs_ronly_deep-1 downto 0) of std_logic_vector(31 downto 0);
  signal reg : reg_array;
  signal sel : integer;
  signal ack : std_logic;

begin

  sel <= to_integer(unsigned(ipbus_in.ipb_addr(addr_width - 1 downto 0))) when addr_width > 0 else 0;

  process(clk)
  begin
    if rising_edge(clk) then
      if ipbus_in.ipb_strobe = '1' and ipbus_in.ipb_write = '0' then
        ipbus_out.ipb_rdata <= reg(sel);
      end if;
      ack <= ipbus_in.ipb_strobe and not ack;

    end if;
  end process;

  ipbus_out.ipb_ack <= ack;
  ipbus_out.ipb_err <= '0';

  q_gen : for i in g_cs_ronly_deep-1 downto 0 generate
  
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        reg(i) <= (others => '0');
      else
   	  reg(i) <= d((i+1)*32-1 downto i*32);
      end if;
    end if;
  end process;
  
  end generate;

end rtl;
