-- ECE 520/L Lab 3: parameterized, single-clock BRAM FIFO.
-- Student-level implementation using a synchronous memory read so Vivado can
-- infer a block RAM. FIFO Generator IP is not used.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package fifo_math_pkg is
    -- Return the number of bits needed to represent values 0 through n-1.
    -- The result is at least one bit, including when n=1.
    function clog2(n : positive) return positive;
end package;

package body fifo_math_pkg is
    function clog2(n : positive) return positive is
        variable value : natural := n - 1;
        variable bits  : natural := 0;
    begin
        while value > 0 loop
            value := value / 2;
            bits := bits + 1;
        end loop;

        if bits = 0 then
            return 1;
        else
            return bits;
        end if;
    end function;
end package body;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fifo_math_pkg.all;

entity sc_fifo is
    generic (
        WIDTH                  : positive := 16;
        DEPTH                  : positive := 32;
        ALMOST_EMPTY_THRESHOLD : natural  := 1;
        ALMOST_FULL_THRESHOLD  : natural  := 31;
        READ_LATENCY           : positive := 1
    );
    port (
        CLK          : in  std_logic;
        SRST         : in  std_logic;
        DIN          : in  std_logic_vector(WIDTH - 1 downto 0);
        WR_EN        : in  std_logic;
        RD_EN        : in  std_logic;
        DOUT         : out std_logic_vector(WIDTH - 1 downto 0);
        FULL         : out std_logic;
        EMPTY        : out std_logic;
        ALMOST_FULL  : out std_logic;
        ALMOST_EMPTY : out std_logic;
        VALID        : out std_logic;
        DATA_COUNT   : out std_logic_vector(clog2(DEPTH + 1) - 1 downto 0)
    );
end entity sc_fifo;

architecture rtl of sc_fifo is
    constant PTR_WIDTH   : positive := clog2(DEPTH);
    constant COUNT_WIDTH : positive := clog2(DEPTH + 1);

    type ram_t is array (0 to DEPTH - 1) of
        std_logic_vector(WIDTH - 1 downto 0);

    type data_pipe_t is array (natural range <>) of
        std_logic_vector(WIDTH - 1 downto 0);

    -- Do not reset the RAM array; resetting it can prevent BRAM inference.
    signal memory : ram_t;

    attribute ram_style : string;
    attribute ram_style of memory : signal is "block";

    signal wr_ptr     : unsigned(PTR_WIDTH - 1 downto 0) := (others => '0');
    signal rd_ptr     : unsigned(PTR_WIDTH - 1 downto 0) := (others => '0');
    signal occupancy  : natural range 0 to DEPTH := 0;
    signal wr_accept  : std_logic;
    signal rd_accept  : std_logic;

    signal data_pipe : data_pipe_t(0 to READ_LATENCY - 1) :=
        (others => (others => '0'));
    signal valid_pipe : std_logic_vector(0 to READ_LATENCY - 1) :=
        (others => '0');
begin
    assert DEPTH >= 2
        report "DEPTH must be at least 2."
        severity failure;

    assert (2 ** PTR_WIDTH) = DEPTH
        report "DEPTH must be a power of two."
        severity failure;

    assert ALMOST_EMPTY_THRESHOLD <= DEPTH
        report "ALMOST_EMPTY_THRESHOLD must be between 0 and DEPTH."
        severity failure;

    assert ALMOST_FULL_THRESHOLD <= DEPTH
        report "ALMOST_FULL_THRESHOLD must be between 0 and DEPTH."
        severity failure;

    assert (READ_LATENCY >= 1) and (READ_LATENCY <= 8)
        report "READ_LATENCY must be between 1 and 8."
        severity failure;

    -- A write is accepted only if the FIFO is not full.
    -- A read is accepted only if the FIFO is not empty.
    wr_accept <= '1' when (WR_EN = '1' and occupancy < DEPTH) else '0';
    rd_accept <= '1' when (RD_EN = '1' and occupancy > 0) else '0';

    FULL         <= '1' when occupancy = DEPTH else '0';
    EMPTY        <= '1' when occupancy = 0 else '0';
    ALMOST_FULL  <= '1' when occupancy >= ALMOST_FULL_THRESHOLD else '0';
    ALMOST_EMPTY <= '1' when occupancy <= ALMOST_EMPTY_THRESHOLD else '0';

    DATA_COUNT <= std_logic_vector(to_unsigned(occupancy, COUNT_WIDTH));
    DOUT       <= data_pipe(READ_LATENCY - 1);
    VALID      <= valid_pipe(READ_LATENCY - 1);

    process (CLK)
    begin
        if rising_edge(CLK) then
            if SRST = '1' then
                wr_ptr     <= (others => '0');
                rd_ptr     <= (others => '0');
                occupancy  <= 0;
                data_pipe  <= (others => (others => '0'));
                valid_pipe <= (others => '0');
            else
                -- Additional stages delay data and VALID by the same amount.
                for stage in 1 to READ_LATENCY - 1 loop
                    data_pipe(stage)  <= data_pipe(stage - 1);
                    valid_pipe(stage) <= valid_pipe(stage - 1);
                end loop;

                valid_pipe(0) <= '0';

                if wr_accept = '1' then
                    memory(to_integer(wr_ptr)) <= DIN;

                    if wr_ptr = to_unsigned(DEPTH - 1, PTR_WIDTH) then
                        wr_ptr <= (others => '0');
                    else
                        wr_ptr <= wr_ptr + 1;
                    end if;
                end if;

                if rd_accept = '1' then
                    -- Clocked read: this form supports synchronous BRAM inference.
                    data_pipe(0)  <= memory(to_integer(rd_ptr));
                    valid_pipe(0) <= '1';

                    if rd_ptr = to_unsigned(DEPTH - 1, PTR_WIDTH) then
                        rd_ptr <= (others => '0');
                    else
                        rd_ptr <= rd_ptr + 1;
                    end if;
                end if;

                -- A simultaneous accepted read and write keep the count steady.
                if (wr_accept = '1') and (rd_accept = '0') then
                    occupancy <= occupancy + 1;
                elsif (wr_accept = '0') and (rd_accept = '1') then
                    occupancy <= occupancy - 1;
                end if;
            end if;
        end if;
    end process;
end architecture rtl;