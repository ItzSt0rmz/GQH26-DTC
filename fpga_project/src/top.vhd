library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
    generic (
        CLKS_PER_BIT : positive := 234;
        GAP_BITS     : natural  := 10;
        IDLE_WIDTH   : positive := 20
    );
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
    type state_t is (S_WAIT, S_CLEAR, S_SEND, S_POST, S_SENDW);
    signal state : state_t := S_WAIT;

    signal rx_data  : std_logic_vector(7 downto 0);
    signal rx_valid : std_logic;

    signal req      : std_logic_vector(63 downto 0) := (others => '0');
    signal byte_cnt : unsigned(2 downto 0) := (others => '0');
    signal idle_cnt : unsigned(IDLE_WIDTH downto 0) := (others => '0');
    signal sh_n     : unsigned(1 downto 0) := (others => '0');
    signal sh_en    : std_logic;

    signal eng_clear : std_logic := '0';
    signal eng_start : std_logic := '0';
    signal eng_act   : std_logic_vector(1 downto 0);

    signal tx_idx   : unsigned(2 downto 0) := (others => '0');
    signal tx_data  : std_logic_vector(7 downto 0);
    signal tx_start : std_logic := '0';
    signal tx_busy  : std_logic;

    signal pkt_tog : std_logic := '0';
begin
    u_rx : entity work.uart_rx
        generic map (CLKS_PER_BIT => CLKS_PER_BIT)
        port map (clk => sys_clk, rx => uart_rx_i, data => rx_data, valid => rx_valid);

    u_tx : entity work.uart_tx
        generic map (CLKS_PER_BIT => CLKS_PER_BIT, GAP_BITS => GAP_BITS)
        port map (clk => sys_clk, data => tx_data, start => tx_start, tx => uart_tx_o, busy => tx_busy);

    u_eng : entity work.ma_engine
        port map (clk => sys_clk, clear => eng_clear, start => eng_start, sel => req(57),
                  price => req(55 downto 40), action => eng_act);

    with tx_idx select tx_data <=
        "000000" & eng_act when "011" | "101",
        x"00"              when "110" | "111",
        req(63 downto 56)  when others;

    sh_en <= '1' when (state = S_WAIT and rx_valid = '1') or sh_n /= 0 else '0';

    led0_n <= not pkt_tog;
    led1_n <= '1' when byte_cnt = 0 else '0';

    process(sys_clk)
    begin
        if rising_edge(sys_clk) then
            eng_clear <= '0';
            eng_start <= '0';
            tx_start  <= '0';

            if sh_en = '1' then
                req <= req(55 downto 0) & rx_data;
            end if;

            if sh_n /= 0 then
                sh_n <= sh_n - 1;
            end if;

            if byte_cnt = 0 or rx_valid = '1' then
                idle_cnt <= (others => '0');
            else
                idle_cnt <= idle_cnt + 1;
            end if;

            case state is
                when S_WAIT =>
                    if rx_valid = '1' then
                        byte_cnt <= byte_cnt + 1;
                        if byte_cnt = 7 then
                            state <= S_CLEAR;
                        end if;
                    elsif idle_cnt(IDLE_WIDTH) = '1' then
                        byte_cnt <= (others => '0');
                    end if;

                when S_CLEAR =>
                    if req(63 downto 48) = x"0000" then
                        eng_clear <= '1';
                    end if;
                    tx_idx  <= (others => '0');
                    pkt_tog <= not pkt_tog;
                    state   <= S_SEND;

                when S_SEND =>
                    if tx_busy = '0' then
                        tx_start <= '1';
                        state    <= S_POST;
                    end if;

                when S_POST =>
                    case tx_idx is
                        when "000" =>
                            sh_n <= "01";
                        when "001" =>
                            sh_n      <= "01";
                            eng_start <= '1';
                        when "010" =>
                            sh_n <= "11";
                        when "011" =>
                            eng_start <= '1';
                        when others =>
                            null;
                    end case;
                    if tx_idx = 7 then
                        state <= S_WAIT;
                    else
                        state <= S_SENDW;
                    end if;

                when S_SENDW =>
                    if tx_busy = '0' then
                        tx_idx <= tx_idx + 1;
                        state  <= S_SEND;
                    end if;
            end case;
        end if;
    end process;
end architecture;
