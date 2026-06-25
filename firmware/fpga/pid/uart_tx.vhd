--------------------------------------------------------------------------------
-- Module      : uart_tx.vhd
-- Description : Transmetteur UART 8N1 pour DE10-Lite (50 MHz)
--               Sérialise un octet en : start bit (0) → 8 bits data → stop bit (1)
--               La transmission débute sur un front montant de i_send.
--               i_send doit être actif 1 seul cycle d'horloge (strobe).
--
-- Utilisation :
--   Connecter i_tick au o_tick du module baud_gen (tick à 16x baud rate).
--   Placer l'octet à envoyer sur i_data, puis pulser i_send 1 cycle.
--   o_busy reste à '1' pendant toute la durée de la transmission.
--   Ne pas envoyer un nouvel octet tant que o_busy = '1'.
--
-- Format : 8N1 (8 bits de données, pas de parité, 1 bit de stop)
-- Durée d'un bit : 16 ticks de baud_gen
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
    port (
        i_clk50   : in  std_logic;                     -- Horloge système (50 MHz)
        i_reset_n : in  std_logic;                     -- Reset actif bas
        i_tick    : in  std_logic;                     -- Tick à 16x baud rate (depuis baud_gen)
        i_data    : in  std_logic_vector(7 downto 0);  -- Octet à transmettre
        i_send    : in  std_logic;                     -- Strobe : envoyer i_data (1 cycle)
        o_tx      : out std_logic;                     -- Ligne série UART TX
        o_busy    : out std_logic                      -- '1' pendant la transmission
    );
end entity uart_tx;

architecture rtl of uart_tx is

    -- États de la FSM
    type t_state is (IDLE, START, DATA, STOP);
    signal s_state     : t_state := IDLE;

    -- Compteur de ticks (0 à 15 : durée d'un bit = 16 ticks)
    signal s_tick_cnt  : integer range 0 to 15         := 0;

    -- Compteur de bits de données envoyés (0 à 7)
    signal s_bit_idx   : integer range 0 to 7          := 0;

    -- Registre de décalage contenant l'octet à transmettre
    signal s_shift_reg : std_logic_vector(7 downto 0)  := (others => '0');

begin

    process(i_clk50, i_reset_n)
    begin
        if i_reset_n = '0' then
            s_state     <= IDLE;
            s_tick_cnt  <= 0;
            s_bit_idx   <= 0;
            s_shift_reg <= (others => '0');
            o_tx        <= '1';   -- Ligne idle = '1' (repos UART)
            o_busy      <= '0';

        elsif rising_edge(i_clk50) then
            case s_state is

                -- ----------------------------------------------------------------
                when IDLE =>
                    o_tx   <= '1';
                    o_busy <= '0';

                    if i_send = '1' then
                        s_shift_reg <= i_data;
                        s_tick_cnt  <= 0;
                        s_state     <= START;
                        o_busy      <= '1';
                    end if;

                -- ----------------------------------------------------------------
                when START =>
                    o_tx <= '0';   -- Bit de start

                    if i_tick = '1' then
                        if s_tick_cnt = 15 then
                            s_tick_cnt <= 0;
                            s_bit_idx  <= 0;
                            s_state    <= DATA;
                        else
                            s_tick_cnt <= s_tick_cnt + 1;
                        end if;
                    end if;

                -- ----------------------------------------------------------------
                when DATA =>
                    o_tx <= s_shift_reg(s_bit_idx);   -- LSB en premier

                    if i_tick = '1' then
                        if s_tick_cnt = 15 then
                            s_tick_cnt <= 0;
                            if s_bit_idx = 7 then
                                s_state <= STOP;
                            else
                                s_bit_idx <= s_bit_idx + 1;
                            end if;
                        else
                            s_tick_cnt <= s_tick_cnt + 1;
                        end if;
                    end if;

                -- ----------------------------------------------------------------
                when STOP =>
                    o_tx <= '1';   -- Bit de stop

                    if i_tick = '1' then
                        if s_tick_cnt = 15 then
                            s_tick_cnt <= 0;
                            s_state    <= IDLE;
                        else
                            s_tick_cnt <= s_tick_cnt + 1;
                        end if;
                    end if;

            end case;
        end if;
    end process;

end architecture rtl;