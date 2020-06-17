-- sensors on the BEC base board
-- power monitor: 1101111x
-- temperature sensor 1: 1001110x
-- temperature sensor 2: 1001010x
-- temperature sensor 3: 1001100x


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;
use work.TTIM_pack.all;

entity monitor is
    Port ( 
    clk_i : in STD_LOGIC;
    rst_i : in std_logic;
    read_reg : in std_logic;
    SCL : out std_logic;
    SDA : inout std_logic;
    temp_reg1 : out std_logic_vector(8 downto 0);
    temp_reg2 : out std_logic_vector(8 downto 0);
    temp_reg3 : out std_logic_vector(8 downto 0);
    sense_reg : out std_logic_vector(11 downto 0);
    vin_reg : out std_logic_vector(11 downto 0);
    adin_reg : out std_logic_vector(11 downto 0);
    fsm_o : out std_logic_vector(3 downto 0)
    );
end monitor;

architecture Behavioral of monitor is
    constant TEMP1 : std_logic_vector(7 downto 0) := "10011100"; -- left
    constant TEMP3 : std_logic_vector(7 downto 0) := "10010100"; -- middle
    constant TEMP2 : std_logic_vector(7 downto 0) := "10010000"; -- right
    constant PWR : std_logic_vector(7 downto 0) := "11011110"; -- power monitor
    constant SENSE : std_logic_vector(7 downto 0) := x"14"; -- delta sense
    constant VIN : std_logic_vector(7 downto 0) := x"1E"; -- input voltage
    constant ADIN : std_logic_vector(7 downto 0) := x"28"; -- voltage to TTIM
    
    type t_state is (st0_idle,st1_start,st2_sendAddr,st_read,st_read1,st_read2,
                    st_write);
    signal state,state_after_sendAddr :t_state;
    signal start,stop,rp_start,scl_i,sda_i,sda_o,rw,byte_done : std_logic;
    signal slave_addr,reg_addr,data_i,data_o,addr_i : std_logic_vector(7 downto 0);
    signal read_reg_r,read_reg_s,error : std_logic;
    signal temp_reg : t_array16(5 downto 0);
    signal sel : integer range 0 to 6 := 0;--std_logic_vector(1 downto 0);
    signal fsm : std_logic_vector(3 downto 0);
    signal busy,ack_inv,inv_ack : std_logic;
begin
temp_reg1 <= temp_reg(0)(15 downto 7);
temp_reg2 <= temp_reg(1)(15 downto 7);
temp_reg3 <= temp_reg(2)(15 downto 7);
sense_reg <= temp_reg(3)(15 downto 4);
vin_reg <= temp_reg(4)(15 downto 4);
adin_reg <= temp_reg(5)(15 downto 4);
fsm_o <= fsm;
Inst_iobuf:IOBUF
    port map(
    O => sda_i,
    IO => SDA,
    I => '0',
    T => sda_o -- 3-state enable input, high=input, low=output 
    );
-- find rising_edge of read_reg
P_read_start:process(clk_i)
begin
    if rising_edge(clk_i) then
        read_reg_r <= read_reg;
        if read_reg = '1' and read_reg_r = '0' then
            read_reg_s <= '1';
        else
            read_reg_s <= '0';
        end if;
    end if;
end process;
-- I2C interface inst
Inst_i2c:entity work.i2c_master
    port map(
    clk_i => clk_i,
    rst_i => rst_i,
    scl_o => scl_i,
    sda_i => sda_i,
    sda_o => sda_o,
    rw => rw,
    ack_inv => ack_inv,
    addr_i => addr_i,
    data_i => data_i,
    start_i => start,
    rp_start => rp_start,
    stop_i => stop,
    data_o => data_o,
    byte_done_o => byte_done,
    error => error,
    busy => busy
    );
    SCL <= scl_i;
-- FSM to perform read procedure
P_read_regs:process(clk_i)
    begin
    if rst_i = '1' then
        state <= st0_idle;
        temp_reg <= (others => (others => '0'));
        sel <= 0;
        ack_inv <= '0';
        inv_ack <= '0';
    elsif rising_edge(clk_i) then
        case state is
            when st0_idle =>
                start <= '0';
                data_i <= (others => '0');
                rp_start <= '0';
                stop <= '0';
                sel <= 0;
                fsm <= x"0";
                ack_inv <= '0';
                inv_ack <= '0';
                if read_reg_s = '1' then
                    state <= st1_start;
                end if;
            when st1_start =>
                if busy = '0' then
                    if sel < 3 then
                        state <= st2_sendAddr;
                        state_after_sendAddr <= st_read;
                        rw <= '1';
                        inv_ack <= '0';
                    else
                        state <= st2_sendAddr;
                        state_after_sendAddr <= st_write;
                        data_i <= reg_addr;
                        rw <= '0';
                        inv_ack <= '1';
                    end if;
                    start <= '1';
                end if;
                fsm <= x"1";
                addr_i <= slave_addr;
            when st2_sendAddr => 
                start <= '0';
                if byte_done = '1' then
                    state <= state_after_sendAddr;
                    rp_start <= '0';
                elsif error = '1' then
                    state <= st0_idle;
                end if;
                fsm <= x"2";
            when st_read =>
                if byte_done = '1' then
                    temp_reg(sel)(15 downto 8) <= data_o;
                    state <= st_read1;
                    if inv_ack = '1' then
                        ack_inv <= '1';
                    else
                        ack_inv <= '0';
                    end if;
                elsif error = '1' then
                    state <= st0_idle;
                end if;
                fsm <= x"3";
            when st_read1 => 
                if byte_done = '1' then
                    temp_reg(sel)(7 downto 0) <= data_o;
                    state <= st_read2;
                    stop <= '1';
                elsif error = '1' then
                    state <= st0_idle;
                end if;
                fsm <= x"4";
            when st_read2 =>
                if sel < 6 then
                    sel <= sel + 1;
                    stop <= '0';
                    ack_inv <= '0';
                    state <= st1_start;
                else
                    sel <= 0;
                    state <= st0_idle;
                end if;
                fsm <= x"5";
            when st_write => 
                if byte_done = '1' then
                    state <= st2_sendAddr;
                    state_after_sendAddr <= st_read;
                    rw <= '1';
                    rp_start <= '1';
                    --inv_ack <= '1';
                elsif error = '1' then
                    state <= st0_idle;
                end if;
                fsm <= x"6";
                
            when others =>
                state <= st0_idle;
        end case;
    end if;
    end process;
-- Inst_vio: entity work.vio_1
    -- port map(
    -- clk => clk_i,
    -- probe_out0(0) => read_temp,
    -- probe_out1(0) => read_pwr,
    -- probe_out2 => slave_sel,
    -- probe_out3 => reg_sel,
    -- probe_out4(0) => open
    -- );
    slave_addr <= TEMP1 when sel = 0 else 
                  TEMP2 when sel = 1 else 
                  TEMP3 when sel = 2 else 
                  PWR;
    reg_addr <= SENSE when sel = 3 else 
                  VIN when sel = 4 else 
                  ADIN;
-- Inst_ila: entity work.ila_2
    -- port map(
    -- clk => clk_i,
    -- probe0 => data_o,
    -- probe1(0) => byte_done,
    -- probe2 => state,
    -- probe3 => temp1_reg,
    -- probe4(0) => scl_i,
    -- probe5(0) => rw,
    -- probe6(0) => sda_i,
    -- probe7(0) => start,
    -- probe8(0) => stop,
    -- probe9(0) => error
    -- );
end Behavioral;
