library ieee;
use ieee.std_logic_1164.all;

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
    component rPLL
        generic (
            FCLKIN           : string  := "100.0";
            DEVICE           : string  := "GW2A-18";
            DYN_IDIV_SEL     : string  := "false";
            IDIV_SEL         : integer := 0;
            DYN_FBDIV_SEL    : string  := "false";
            FBDIV_SEL        : integer := 0;
            DYN_ODIV_SEL     : string  := "false";
            ODIV_SEL         : integer := 8;
            PSDA_SEL         : string  := "0000";
            DYN_DA_EN        : string  := "false";
            DUTYDA_SEL       : string  := "1000";
            CLKOUT_FT_DIR    : bit     := '1';
            CLKOUTP_FT_DIR   : bit     := '1';
            CLKOUT_DLY_STEP  : integer := 0;
            CLKOUTP_DLY_STEP : integer := 0;
            CLKFB_SEL        : string  := "internal";
            CLKOUT_BYPASS    : string  := "false";
            CLKOUTP_BYPASS   : string  := "false";
            CLKOUTD_BYPASS   : string  := "false";
            DYN_SDIV_SEL     : integer := 2;
            CLKOUTD_SRC      : string  := "CLKOUT";
            CLKOUTD3_SRC     : string  := "CLKOUT"
        );
        port (
            CLKOUT   : out std_logic;
            LOCK     : out std_logic;
            CLKOUTP  : out std_logic;
            CLKOUTD  : out std_logic;
            CLKOUTD3 : out std_logic;
            RESET    : in  std_logic;
            RESET_P  : in  std_logic;
            CLKIN    : in  std_logic;
            CLKFB    : in  std_logic;
            FBDSEL   : in  std_logic_vector(5 downto 0);
            IDSEL    : in  std_logic_vector(5 downto 0);
            ODSEL    : in  std_logic_vector(5 downto 0);
            PSDA     : in  std_logic_vector(3 downto 0);
            DUTYDA   : in  std_logic_vector(3 downto 0);
            FDLY     : in  std_logic_vector(3 downto 0)
        );
    end component;

    signal clk  : std_logic;
    signal rx_s : std_logic_vector(1 downto 0) := "11";
    signal rx   : std_logic;

    signal time_q : std_logic_vector(10 downto 0);
    signal rxf_a  : std_logic_vector(10 downto 0);
    signal rxf_q  : std_logic_vector(9 downto 0);
    signal idle_a : std_logic_vector(10 downto 0);
    signal idle_q : std_logic_vector(9 downto 0);
    signal seq_a  : std_logic_vector(12 downto 0);
    signal pc     : std_logic_vector(9 downto 0);
    signal ctrl   : std_logic_vector(42 downto 0);
    signal alu_a  : std_logic_vector(13 downto 0);
    signal alu_q  : std_logic_vector(4 downto 0);

    signal en     : std_logic;
    signal tick   : std_logic;
    signal strobe : std_logic;
    signal tmo    : std_logic;
    signal res    : std_logic;

    signal r_q  : std_logic;
    signal s_q  : std_logic;
    signal w_q  : std_logic;
    signal s_ra : std_logic_vector(5 downto 0);
    signal s_wa : std_logic_vector(5 downto 0);
    signal w_ra : std_logic_vector(8 downto 0);
    signal w_wa : std_logic_vector(8 downto 0);

    signal isel : std_logic := '0';
    signal ptr  : std_logic_vector(3 downto 0) := (others => '0');
    signal txo  : std_logic := '1';
begin
    -- 27 MHz x2 = 54 MHz (VCO 432 MHz); rom_time is tabled for 54 MHz
    u_pll : rPLL
        generic map (
            FCLKIN    => "27",
            DEVICE    => "GW2AR-18C",
            IDIV_SEL  => 0,
            FBDIV_SEL => 1,
            ODIV_SEL  => 8
        )
        port map (
            CLKOUT => clk, LOCK => open, CLKOUTP => open, CLKOUTD => open, CLKOUTD3 => open,
            RESET => '0', RESET_P => '0', CLKIN => sys_clk, CLKFB => '0',
            FBDSEL => (others => '0'), IDSEL => (others => '0'), ODSEL => (others => '0'),
            PSDA => (others => '0'), DUTYDA => (others => '0'), FDLY => (others => '0')
        );

    rx     <= rx_s(1);
    en     <= time_q(9);
    tick   <= time_q(10);
    strobe <= rxf_q(9);
    tmo    <= idle_q(9);
    res    <= alu_q(2);

    rxf_a  <= rx & en & rxf_q(8 downto 0);
    idle_a <= rx & tick & idle_q(8 downto 0);
    seq_a  <= tmo & strobe & tick & pc;
    alu_a  <= ctrl(20 downto 16) & alu_q & rx & w_q & s_q & r_q;

    s_ra <= isel & ctrl(11 downto 7);
    s_wa <= isel & ctrl(32 downto 28);
    w_ra <= isel & ptr & ctrl(15 downto 12);
    w_wa <= isel & ptr & ctrl(36 downto 33);

    u_time : entity work.rom_time  port map (clk => clk, addr => time_q(8 downto 0), q => time_q);
    u_rxf  : entity work.rom_rxfsm port map (clk => clk, addr => rxf_a, q => rxf_q);
    u_idle : entity work.rom_idle  port map (clk => clk, addr => idle_a, q => idle_q);
    u_seq  : entity work.rom_seq   port map (clk => clk, addr => seq_a, q => pc);
    u_ctrl : entity work.rom_ctrl  port map (clk => clk, addr => pc, q => ctrl);
    u_alu  : entity work.rom_alu   port map (clk => clk, addr => alu_a, q => alu_q);

    u_r : entity work.bram1
        generic map (AW => 7)
        port map (clk => clk, we => ctrl(37), wa => ctrl(27 downto 21), din => res,
                  ra => ctrl(6 downto 0), q => r_q);

    u_s : entity work.bram1
        generic map (AW => 6)
        port map (clk => clk, we => ctrl(38), wa => s_wa, din => res, ra => s_ra, q => s_q);

    u_w : entity work.bram1
        generic map (AW => 9)
        port map (clk => clk, we => ctrl(39), wa => w_wa, din => res, ra => w_ra, q => w_q);

    process(clk)
    begin
        if rising_edge(clk) then
            rx_s <= rx_s(0) & uart_rx_i;
            if ctrl(40) = '1' then
                isel <= res;
            end if;
            if ctrl(41) = '1' then
                ptr <= res & ptr(3 downto 1);
            end if;
            if ctrl(42) = '1' then
                txo <= res;
            end if;
        end if;
    end process;

    uart_tx_o <= txo;
    led0_n    <= '1';
    led1_n    <= '1';
end architecture;
