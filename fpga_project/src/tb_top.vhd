library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_top is
    generic (
        GAP_BITS     : natural  := 10;
        CLKS_PER_BIT : positive := 234;
        IDLE_WIDTH   : positive := 20;
        REAL_BAUD    : boolean  := true;
        VEC_FILE     : string   := "testbench/vectors.txt"
    );
end entity;

architecture sim of tb_top is
    constant CLK_PERIOD : time := 37037 ps;
    function bit_time_f return time is
    begin
        if REAL_BAUD then
            return 8680556 ps;
        end if;
        return CLK_PERIOD * CLKS_PER_BIT;
    end function;
    constant BIT_TIME   : time := bit_time_f;

    signal clk      : std_logic := '0';
    signal rx_line  : std_logic := '1';
    signal tx_line  : std_logic;
    signal led0_n   : std_logic;
    signal led1_n   : std_logic;
    signal finished : boolean := false;

    signal rx_total : natural := 0;
    signal rx_shift : std_logic_vector(63 downto 0) := (others => '0');
begin
    clk <= not clk after CLK_PERIOD / 2 when not finished else '0';

    dut : entity work.top
        generic map (CLKS_PER_BIT => CLKS_PER_BIT, GAP_BITS => GAP_BITS, IDLE_WIDTH => IDLE_WIDTH)
        port map (
            sys_clk   => clk,
            reset_btn => '0',
            uart_rx_i => rx_line,
            uart_tx_o => tx_line,
            led0_n    => led0_n,
            led1_n    => led1_n
        );

    monitor : process
        variable b : std_logic_vector(7 downto 0);
    begin
        wait until falling_edge(tx_line);
        wait for BIT_TIME / 2;
        assert tx_line = '0' report "bad start bit" severity failure;
        for k in 0 to 7 loop
            wait for BIT_TIME;
            b(k) := tx_line;
        end loop;
        wait for BIT_TIME;
        assert tx_line = '1' report "bad stop bit" severity failure;
        rx_shift <= rx_shift(55 downto 0) & b;
        rx_total <= rx_total + 1;
    end process;

    stim : process
        file f        : text open read_mode is VEC_FILE;
        variable l    : line;
        variable cmd  : character;
        variable req  : std_logic_vector(63 downto 0);
        variable exp  : std_logic_vector(63 downto 0);
        variable sb   : std_logic_vector(7 downto 0);
        variable dly  : integer;
        variable sent : natural := 0;
        variable errs : natural := 0;
        variable t0   : time;
        variable tmax : time := 0 ns;

        procedure send_byte(b : std_logic_vector(7 downto 0)) is
        begin
            rx_line <= '0';
            wait for BIT_TIME;
            for k in 0 to 7 loop
                rx_line <= b(k);
                wait for BIT_TIME;
            end loop;
            rx_line <= '1';
            wait for BIT_TIME;
        end procedure;
    begin
        wait for 100 * BIT_TIME;
        while not endfile(f) loop
            readline(f, l);
            read(l, cmd);
            if cmd = 'S' then
                hread(l, sb);
                send_byte(sb);
            elsif cmd = 'W' then
                read(l, dly);
                wait for dly * 120 * BIT_TIME;
                assert rx_total = 8 * sent report "unsolicited bytes" severity failure;
            elsif cmd = 'R' then
                hread(l, req);
                hread(l, exp);
                t0 := now;
                for k in 7 downto 0 loop
                    send_byte(req(8 * k + 7 downto 8 * k));
                end loop;
                sent := sent + 1;
                if rx_total /= 8 * sent then
                    wait until rx_total = 8 * sent for 2000 * BIT_TIME;
                end if;
                assert rx_total = 8 * sent report "TIMEOUT on packet " & integer'image(sent) severity failure;
                if now - t0 > tmax then
                    tmax := now - t0;
                end if;
                if rx_shift /= exp then
                    errs := errs + 1;
                    report "MISMATCH on packet " & integer'image(sent) severity error;
                end if;
            end if;
        end loop;
        wait for 500 * BIT_TIME;
        assert rx_total = 8 * sent report "unsolicited bytes at end" severity failure;
        report "packets=" & integer'image(sent) & " mismatches=" & integer'image(errs)
             & " max_roundtrip_us=" & integer'image(tmax / 1 us);
        finished <= true;
        wait;
    end process;
end architecture;
