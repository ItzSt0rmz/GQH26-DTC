library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bram1 is
    generic (
        AW : positive := 7
    );
    port (
        clk : in  std_logic;
        we  : in  std_logic;
        wa  : in  std_logic_vector(AW - 1 downto 0);
        din : in  std_logic;
        ra  : in  std_logic_vector(AW - 1 downto 0);
        q   : out std_logic
    );
end entity;

architecture rtl of bram1 is
    type mem_t is array (natural range 0 to 2 ** AW - 1) of std_logic_vector(0 downto 0);
    signal mem : mem_t := (others => "0");
    signal qr  : std_logic_vector(0 downto 0) := "0";
    signal dv  : std_logic_vector(0 downto 0);
    attribute syn_ramstyle : string;
    attribute syn_ramstyle of mem : signal is "block_ram";
begin
    q     <= qr(0);
    dv(0) <= din;

    process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                mem(to_integer(unsigned(wa))) <= dv;
            end if;
            qr <= mem(to_integer(unsigned(ra)));
        end if;
    end process;
end architecture;
