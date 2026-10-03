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
        action : out std_logic_vector(1 downto 0) := "00";
        done   : out std_logic := '0'
    );
end entity;

architecture rtl of ma_engine is
    constant ACT_NONE : std_logic_vector(1 downto 0) := "00";
    constant ACT_SELL : std_logic_vector(1 downto 0) := "01";
    constant ACT_BUY  : std_logic_vector(1 downto 0) := "10";

    -- price window: addr = sel & ptr, 16 slots per item
    type win_t is array (0 to 31) of std_logic_vector(15 downto 0);
    -- per-item state: sum(37..18) & prev(17..2) & last(1..0)
    type st_t  is array (0 to 1) of std_logic_vector(37 downto 0);

    signal mem    : win_t := (others => (others => '0'));
    signal st     : st_t  := (others => (others => '0'));
    signal rd_win : std_logic_vector(15 downto 0) := (others => '0');
    signal rd_st  : std_logic_vector(37 downto 0) := (others => '0');

    attribute syn_ramstyle : string;
    attribute syn_ramstyle of mem : signal is "block_ram";
    attribute syn_ramstyle of st  : signal is "block_ram";

    -- cnt(0) = item within packet, cnt(4..1) = window ptr (shared: every packet carries both items)
    signal cnt   : unsigned(5 downto 0) := (others => '0');
    signal full  : std_logic := '0';
    signal first : std_logic := '1';
    signal s1    : std_logic := '0';
    signal calc  : std_logic := '0';

    -- stage registers; sync resets replace AND-gating
    signal tail   : unsigned(15 downto 0) := (others => '0');
    signal sum_r  : unsigned(19 downto 0) := (others => '0');
    signal last_r : std_logic_vector(1 downto 0) := ACT_NONE;

    signal sel_i    : natural range 0 to 1;
    signal addr     : natural range 0 to 31;
    signal prev     : unsigned(15 downto 0);
    signal price_u  : unsigned(15 downto 0);
    signal new_sum  : unsigned(19 downto 0);
    signal old_avg  : unsigned(15 downto 0);
    signal new_avg  : unsigned(15 downto 0);
    signal next_act : std_logic_vector(1 downto 0);

    -- compares as subtractions; bit 16 is the borrow (carry chain, not LUTs)
    signal d_le : unsigned(16 downto 0);  -- old_avg - prev   : borrow -> prev > old_avg
    signal d_ge : unsigned(16 downto 0);  -- prev - old_avg   : borrow -> prev < old_avg
    signal d_gt : unsigned(16 downto 0);  -- new_avg - price  : borrow -> price > new_avg
    signal d_lt : unsigned(16 downto 0);  -- price - new_avg  : borrow -> price < new_avg

    attribute syn_keep : integer;
    attribute syn_keep of d_le : signal is 1;
    attribute syn_keep of d_ge : signal is 1;
    attribute syn_keep of d_gt : signal is 1;
    attribute syn_keep of d_lt : signal is 1;

    signal buy  : std_logic;
    signal sell : std_logic;
begin
    sel_i   <= 1 when sel = '1' else 0;
    addr    <= to_integer(sel & cnt(4 downto 1));
    prev    <= unsigned(rd_st(17 downto 2));
    price_u <= unsigned(price);

    new_sum <= sum_r + price_u - tail;
    old_avg <= sum_r(19 downto 4);
    new_avg <= new_sum(19 downto 4);

    d_le <= ('0' & old_avg) - ('0' & prev);
    d_ge <= ('0' & prev)    - ('0' & old_avg);
    d_gt <= ('0' & new_avg) - ('0' & price_u);
    d_lt <= ('0' & price_u) - ('0' & new_avg);

    buy  <= full and not d_le(16) and d_gt(16);
    sell <= full and not d_ge(16) and d_lt(16);

    next_act <= ACT_BUY  when buy = '1' else
                ACT_SELL when sell = '1' else
                last_r;

    process(clk)
    begin
        if rising_edge(clk) then
            if calc = '1' then
                mem(addr) <= price;
            end if;
            if start = '1' then
                rd_win <= mem(addr);
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if calc = '1' then
                st(sel_i) <= std_logic_vector(new_sum) & price & next_act;
            end if;
            if start = '1' then
                rd_st <= st(sel_i);
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            done <= '0';
            s1   <= start;
            calc <= s1;

            if full = '0' then
                tail <= (others => '0');
            else
                tail <= unsigned(rd_win);
            end if;

            if first = '1' then
                sum_r  <= (others => '0');
                last_r <= ACT_NONE;
            else
                sum_r  <= unsigned(rd_st(37 downto 18));
                last_r <= rd_st(1 downto 0);
            end if;

            if cnt(5) = '1' then
                full <= '1';
            end if;

            if clear = '1' then
                cnt   <= (others => '0');
                full  <= '0';
                first <= '1';
            elsif calc = '1' then
                action <= next_act;
                done   <= '1';
                cnt    <= cnt + 1;
                if cnt(0) = '1' then
                    first <= '0';
                end if;
            end if;
        end if;
    end process;
end architecture;
