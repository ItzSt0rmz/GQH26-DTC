library ieee;
use ieee.std_logic_1164.all;

entity uart_tx is
    generic (
        CLKS_PER_BIT : positive := 234;
        GAP_BITS     : natural  := 10
    );
    port (
        clk   : in  std_logic;
        data  : in  std_logic_vector(7 downto 0);
        start : in  std_logic;
        tx    : out std_logic;
        busy  : out std_logic
    );
end entity;

architecture rtl of uart_tx is
    constant FRAME_BITS : positive := 10 + GAP_BITS;
    signal sh        : std_logic_vector(9 downto 0) := (others => '1');
    signal cnt       : natural range 0 to CLKS_PER_BIT - 1 := 0;
    signal bits_left : natural range 0 to FRAME_BITS := 0;
begin
    tx   <= sh(0);
    busy <= '0' when bits_left = 0 else '1';

    process(clk)
    begin
        if rising_edge(clk) then
            if bits_left = 0 then
                cnt <= 0;
                if start = '1' then
                    sh        <= '1' & data & '0';
                    bits_left <= FRAME_BITS;
                end if;
            elsif cnt = CLKS_PER_BIT - 1 then
                cnt       <= 0;
                sh        <= '1' & sh(9 downto 1);
                bits_left <= bits_left - 1;
            else
                cnt <= cnt + 1;
            end if;
        end if;
    end process;
end architecture;
