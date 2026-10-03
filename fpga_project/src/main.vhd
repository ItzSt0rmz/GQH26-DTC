library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
    port (
        sys_clk   : in  std_logic;
        reset_btn : in  std_logic;
        uart_rx_i : in  std_logic;
        uart_tx_o : out std_logic;
        led0_n    : out std_logic;
        led1_n    : out std_logic
    );
end entity;

architecture rtl of top is
    constant HALF_SEC : natural := 13_500_000;
    signal div  : natural range 0 to HALF_SEC - 1 := 0;
    signal tick : std_logic;
    signal cnt  : std_logic_vector(2 downto 0) := "001";
begin
    tick <= '1' when div = HALF_SEC - 1 else '0';

    process(sys_clk)
    begin
        if rising_edge(sys_clk) then
            if tick = '1' then
                div <= 0;
            else
                div <= div + 1;
            end if;
        end if;
    end process;

    process(sys_clk, reset_btn)
    begin
        if reset_btn = '1' then
            cnt <= "001";
        elsif rising_edge(sys_clk) then
            if tick = '1' then
                cnt(0) <= '1';
                cnt(1) <= not cnt(1);
                cnt(2) <= cnt(2) xor cnt(1);
            end if;
        end if;
    end process;

    led0_n <= not cnt(1);
    led1_n <= not cnt(2);

    uart_tx_o <= '1';
end architecture;