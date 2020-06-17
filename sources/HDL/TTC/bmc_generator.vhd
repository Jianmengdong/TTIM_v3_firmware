-- Biphase Mark Code Generator
-- Version v.0: first release
-- Date: 19/11/2016 
-- Author: Davide Pedretti INFN LNL

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bmc_generator is
	port(
		data_i		: in std_logic;
		reset_i		: in std_logic;
		clk_125_i	: in std_logic;
		-- sel_o       : out std_logic;
		tdm_synch_o : out std_logic;
		bmc_o  		: out std_logic
	);
end entity bmc_generator;

architecture rtl of bmc_generator is

signal s_data	 : std_logic;
signal s_bmc	 : std_logic;
signal s_toggle : std_logic;
signal s_sel    : std_logic;

begin

process(clk_125_i, reset_i)
begin
   if reset_i = '1' then
      s_toggle <= '0';
	elsif rising_edge(clk_125_i) then
		s_toggle <= not s_toggle;
	end if;
end process;

process(clk_125_i, reset_i)
begin
   if reset_i = '1' then
      s_data <= '0';
	elsif rising_edge(clk_125_i) then
		if s_toggle = '0' then -- the bit is stale
		   s_data <= data_i;
		end if;
	end if;
end process;

-- BMC process:
process(clk_125_i,reset_i)
begin
   if reset_i = '1' then
	   s_bmc <= '0';
	elsif rising_edge(clk_125_i) then
		if s_toggle = '1' or s_data = '1' then
			s_bmc <= not s_bmc;
		end if;
	end if;
end process;

bmc_o <= s_bmc;

-- Channel select output signal:
-- process(clk_125_i,reset_i)
-- begin
--    if reset_i = '1' then
-- 	   s_sel <= '0';
-- 	elsif rising_edge(clk_125_i) then
-- 		if s_toggle = '1' then
-- 			s_sel <= not s_sel;
-- 		end if;
-- 	end if;
-- end process;
-- sel_o <= s_sel;

-- time division multiplexing synch signal:
-- process(clk_125_i,reset_i)
-- begin
--    if reset_i = '1' then
-- 	   tdm_synch_o <= '0';
-- 	elsif rising_edge(clk_125_i) then
-- 		if s_toggle = '1' and s_sel = '1' then
-- 			tdm_synch_o <= '1';
-- 		else
-- 		   tdm_synch_o <= '0';
-- 		end if;
-- 	end if;
-- end process;
tdm_synch_o <= not s_toggle;

end rtl;



