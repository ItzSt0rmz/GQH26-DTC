library ieee;
use ieee.std_logic_1164.all;

entity uart_rx is
    generic (
        CLKS_PER_BIT : positive := 234
    );
    port (
        clk   : in  std_logic;
        rx    : in  std_logic;
        data  : out std_logic_vector(7 downto 0);
        valid : out std_logic
    );
end entity;

architecture rtl of uart_rx is
    type state_t is (S_IDLE, S_START, S_DATA, S_STOP);
    signal state   : state_t := S_IDLE;
    signal sync    : std_logic_vector(1 downto 0) := "11";
    signal cnt     : natural range 0 to CLKS_PER_BIT - 1 := 0;
    signal bit_idx : natural range 0 to 7 := 0;
    signal sh      : std_logic_vector(7 downto 0) := (others => '0');
begin
    data <= sh;

    process(clk)
    begin
        if rising_edge(clk) then
            sync  <= sync(0) & rx;
            valid <= '0';

            case state is
                when S_IDLE =>
                    cnt <= 0;
                    if sync(1) = '0' then
                        state <= S_START;
                    end if;

                when S_START =>
                    if cnt = CLKS_PER_BIT / 2 - 1 then
                        cnt <= 0;
                        if sync(1) = '0' then
                            bit_idx <= 0;
                            state   <= S_DATA;
                        else
                            state <= S_IDLE;
                        end if;
                    else
                        cnt <= cnt + 1;
                    end if;

                when S_DATA =>
                    if cnt = CLKS_PER_BIT - 1 then
                        cnt <= 0;
                        sh  <= sync(1) & sh(7 downto 1);
                        if bit_idx = 7 then
                            state <= S_STOP;
                        else
                            bit_idx <= bit_idx + 1;
                        end if;
                    else
                        cnt <= cnt + 1;
                    end if;

                when S_STOP =>
                    if cnt = CLKS_PER_BIT - 1 then
                        cnt   <= 0;
                        valid <= sync(1);
                        state <= S_IDLE;
                    else
                        cnt <= cnt + 1;
                    end if;
            end case;
        end if;
    end process;
end architecture;
