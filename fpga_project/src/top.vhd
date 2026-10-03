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

    u_time : entity work.rom_time  port map (clk => sys_clk, addr => time_q(8 downto 0), q => time_q);
    u_rxf  : entity work.rom_rxfsm port map (clk => sys_clk, addr => rxf_a, q => rxf_q);
    u_idle : entity work.rom_idle  port map (clk => sys_clk, addr => idle_a, q => idle_q);
    u_seq  : entity work.rom_seq   port map (clk => sys_clk, addr => seq_a, q => pc);
    u_ctrl : entity work.rom_ctrl  port map (clk => sys_clk, addr => pc, q => ctrl);
    u_alu  : entity work.rom_alu   port map (clk => sys_clk, addr => alu_a, q => alu_q);

    u_r : entity work.bram1
        generic map (AW => 7)
        port map (clk => sys_clk, we => ctrl(37), wa => ctrl(27 downto 21), din => res,
                  ra => ctrl(6 downto 0), q => r_q);

    u_s : entity work.bram1
        generic map (AW => 6)
        port map (clk => sys_clk, we => ctrl(38), wa => s_wa, din => res, ra => s_ra, q => s_q);

    u_w : entity work.bram1
        generic map (AW => 9)
        port map (clk => sys_clk, we => ctrl(39), wa => w_wa, din => res, ra => w_ra, q => w_q);

    process(sys_clk)
    begin
        if rising_edge(sys_clk) then
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
