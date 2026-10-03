library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ma_engine is
    port (
        clk    : in  std_logic;
        clear  : in  std_logic;
        start  : in  std_logic;
        sel    : in  std_logic;
        price  : in  std_logic_vector(15 downto 0);
        action : out std_logic_vector(1 downto 0);
        done   : out std_logic
    );
end entity;

architecture rtl of ma_engine is
    constant ACT_NONE : std_logic_vector(1 downto 0) := "00";
    constant ACT_SELL : std_logic_vector(1 downto 0) := "01";
    constant ACT_BUY  : std_logic_vector(1 downto 0) := "10";

    type win_t is array (0 to 15) of std_logic_vector(15 downto 0);

    signal win_a  : win_t := (others => (others => '0'));
    signal win_b  : win_t := (others => (others => '0'));
    signal vld_a  : std_logic_vector(15 downto 0) := (others => '0');
    signal vld_b  : std_logic_vector(15 downto 0) := (others => '0');
    signal sum_a  : unsigned(19 downto 0) := (others => '0');
    signal sum_b  : unsigned(19 downto 0) := (others => '0');
    signal last_a : std_logic_vector(1 downto 0) := ACT_NONE;
    signal last_b : std_logic_vector(1 downto 0) := ACT_NONE;

    attribute syn_srlstyle : string;
    attribute syn_srlstyle of win_a : signal is "registers";
    attribute syn_srlstyle of win_b : signal is "registers";
    attribute syn_srlstyle of vld_a : signal is "registers";
    attribute syn_srlstyle of vld_b : signal is "registers";

    signal full     : std_logic;
    signal tail     : std_logic_vector(15 downto 0);
    signal prev     : unsigned(15 downto 0);
    signal sum_cur  : unsigned(19 downto 0);
    signal last_cur : std_logic_vector(1 downto 0);
    signal price_u  : unsigned(15 downto 0);
    signal oldest   : unsigned(15 downto 0);
    signal new_sum  : unsigned(19 downto 0);
    signal old_avg  : unsigned(15 downto 0);
    signal new_avg  : unsigned(15 downto 0);
    signal buy      : std_logic;
    signal sell     : std_logic;
    signal next_act : std_logic_vector(1 downto 0);
begin
    full     <= vld_b(15) when sel = '1' else vld_a(15);
    tail     <= win_b(15) when sel = '1' else win_a(15);
    prev     <= unsigned(win_b(0)) when sel = '1' else unsigned(win_a(0));
    sum_cur  <= sum_b when sel = '1' else sum_a;
    last_cur <= last_b when sel = '1' else last_a;
    price_u  <= unsigned(price);

    oldest  <= unsigned(tail) when full = '1' else (others => '0');
    
    new_sum <= sum_cur + price_u - oldest;
    old_avg <= sum_cur(19 downto 4);
    new_avg <= new_sum(19 downto 4);

    buy  <= '1' when full = '1' and prev <= old_avg and price_u > new_avg else '0';
    sell <= '1' when full = '1' and prev >= old_avg and price_u < new_avg else '0';

    next_act <= ACT_BUY  when buy = '1' else
                ACT_SELL when sell = '1' else
                last_cur;

    process(clk)
    begin
        if rising_edge(clk) then
            done <= '0';

            if clear = '1' then
                vld_a  <= (others => '0');
                vld_b  <= (others => '0');
                sum_a  <= (others => '0');
                sum_b  <= (others => '0');
                last_a <= ACT_NONE;
                last_b <= ACT_NONE;
            elsif start = '1' then
                action <= next_act;
                done   <= '1';
                if sel = '1' then
                    win_b(0) <= price;
                    for k in 1 to 15 loop
                        win_b(k) <= win_b(k - 1);
                    end loop;
                    vld_b  <= vld_b(14 downto 0) & '1';
                    sum_b  <= new_sum;
                    last_b <= next_act;
                else
                    win_a(0) <= price;
                    for k in 1 to 15 loop
                        win_a(k) <= win_a(k - 1);
                    end loop;
                    vld_a  <= vld_a(14 downto 0) & '1';
                    sum_a  <= new_sum;
                    last_a <= next_act;
                end if;
            end if;
        end if;
    end process;
end architecture;
