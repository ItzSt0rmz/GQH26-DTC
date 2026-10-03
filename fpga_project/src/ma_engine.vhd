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
        action : out std_logic_vector(1 downto 0)
    );
end entity;

architecture rtl of ma_engine is
    constant ACT_SELL : std_logic_vector(1 downto 0) := "01";
    constant ACT_BUY  : std_logic_vector(1 downto 0) := "10";

    type win_t is array (0 to 15) of std_logic_vector(15 downto 0);

    signal win_a  : win_t := (others => (others => '0'));
    signal win_b  : win_t := (others => (others => '0'));
    signal vld_a  : std_logic_vector(15 downto 0) := (others => '0');
    signal vld_b  : std_logic_vector(15 downto 0) := (others => '0');
    signal sum_a  : unsigned(19 downto 0) := (others => '0');
    signal sum_b  : unsigned(19 downto 0) := (others => '0');
    signal last_a : std_logic_vector(1 downto 0) := "00";
    signal last_b : std_logic_vector(1 downto 0) := "00";
    signal le_a   : std_logic := '0';
    signal ge_a   : std_logic := '0';
    signal le_b   : std_logic := '0';
    signal ge_b   : std_logic := '0';

    attribute syn_srlstyle : string;
    attribute syn_srlstyle of win_a : signal is "registers";
    attribute syn_srlstyle of win_b : signal is "registers";
    attribute syn_srlstyle of vld_a : signal is "registers";
    attribute syn_srlstyle of vld_b : signal is "registers";

    signal calc    : std_logic := '0';
    signal price_u : unsigned(15 downto 0);
    signal ns_a    : unsigned(19 downto 0);
    signal ns_b    : unsigned(19 downto 0);
    signal gt_a    : std_logic;
    signal lt_a    : std_logic;
    signal gt_b    : std_logic;
    signal lt_b    : std_logic;
    signal nact_a  : std_logic_vector(1 downto 0);
    signal nact_b  : std_logic_vector(1 downto 0);
begin
    price_u <= unsigned(price);

    ns_a <= sum_a + price_u - unsigned(win_a(15));
    ns_b <= sum_b + price_u - unsigned(win_b(15));

    gt_a <= '1' when price_u > ns_a(19 downto 4) else '0';
    lt_a <= '1' when price_u < ns_a(19 downto 4) else '0';
    gt_b <= '1' when price_u > ns_b(19 downto 4) else '0';
    lt_b <= '1' when price_u < ns_b(19 downto 4) else '0';

    nact_a <= ACT_BUY  when (vld_a(15) and le_a and gt_a) = '1' else
              ACT_SELL when (vld_a(15) and ge_a and lt_a) = '1' else
              last_a;
    nact_b <= ACT_BUY  when (vld_b(15) and le_b and gt_b) = '1' else
              ACT_SELL when (vld_b(15) and ge_b and lt_b) = '1' else
              last_b;

    process(clk)
    begin
        if rising_edge(clk) then
            calc <= start;

            if clear = '1' then
                win_a  <= (others => (others => '0'));
                win_b  <= (others => (others => '0'));
                vld_a  <= (others => '0');
                vld_b  <= (others => '0');
                sum_a  <= (others => '0');
                sum_b  <= (others => '0');
                last_a <= "00";
                last_b <= "00";
            elsif calc = '1' then
                if sel = '1' then
                    win_b(0) <= price;
                    for k in 1 to 15 loop
                        win_b(k) <= win_b(k - 1);
                    end loop;
                    vld_b  <= vld_b(14 downto 0) & '1';
                    sum_b  <= ns_b;
                    le_b   <= not gt_b;
                    ge_b   <= not lt_b;
                    last_b <= nact_b;
                    action <= nact_b;
                else
                    win_a(0) <= price;
                    for k in 1 to 15 loop
                        win_a(k) <= win_a(k - 1);
                    end loop;
                    vld_a  <= vld_a(14 downto 0) & '1';
                    sum_a  <= ns_a;
                    le_a   <= not gt_a;
                    ge_a   <= not lt_a;
                    last_a <= nact_a;
                    action <= nact_a;
                end if;
            end if;
        end if;
    end process;
end architecture;
