--------------------------------------------------------------------------------
-- Module      : uart_rx.vhd
-- Description : Récepteur UART 8N1 pour DE10-Lite (50 MHz)
--               Désérialise une trame : start bit → 8 bits data → stop bit.
--               Échantillonnage au milieu de chaque bit (tick 8 sur 16).
--               Double flip-flop sur i_rx pour éviter la métastabilité.
--
-- Utilisation :
--   Connecter i_tick au o_tick du module baud_gen (tick à 16x baud rate).
--   Lorsqu'un octet est reçu, o_valid est actif 1 cycle d'horloge.
--   Lire o_data pendant ce cycle (ou le registrer en aval).
--
-- Format : 8N1 (8 bits de données, pas de parité, 1 bit de stop)
-- Durée d'un bit : 16 ticks de baud_gen
-- Échantillonnage : tick 7 (milieu du bit, index 0 à 15)
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
    port (
        i_clk50   : in  std_logic;                     -- Horloge système (50 MHz)
        i_reset_n : in  std_logic;                     -- Reset actif bas
        i_tick    : in  std_logic;                     -- Tick à 16x baud rate (depuis baud_gen)
        i_rx      : in  std_logic;                     -- Ligne série UART RX
        o_data    : out std_logic_vector(7 downto 0);  -- Octet reçu
        o_valid   : out std_logic                      -- Strobe : o_data valide (1 cycle)
    );
end entity uart_rx;

architecture rtl of uart_rx is

    -- États de la FSM
    type t_state is (IDLE, START, DATA, STOP);
    signal s_state    : t_state := IDLE;

    -- Double flip-flop anti-métastabilité sur i_rx
    signal s_rx_d1    : std_logic := '1';
    signal s_rx_sync  : std_logic := '1';

    -- Compteur de ticks (0 à 15 : durée d'un bit = 16 ticks)
    signal s_tick_cnt : integer range 0 to 15         := 0;

    -- Compteur de bits de données reçus (0 à 7)
    signal s_bit_idx  : integer range 0 to 7          := 0;

    -- Registre de décalage pour reconstruire l'octet reçu
    signal s_shift_reg : std_logic_vector(7 downto 0) := (others => '0');

begin

    process(i_clk50, i_reset_n)
    begin
        if i_reset_n = '0' then
            s_rx_d1     <= '1';
            s_rx_sync   <= '1';
            s_state     <= IDLE;
            s_tick_cnt  <= 0;
            s_bit_idx   <= 0;
            s_shift_reg <= (others => '0');
            o_data      <= (others => '0');
            o_valid     <= '0';

        elsif rising_edge(i_clk50) then
            -- Double flip-flop : resynchronisation de i_rx sur i_clk50
            s_rx_d1   <= i_rx;
            s_rx_sync <= s_rx_d1;

            -- Strobe o_valid actif 1 seul cycle par défaut
            o_valid <= '0';

            case s_state is

                -- ----------------------------------------------------------------
                when IDLE =>
                    -- Détection du front descendant du start bit
                    if s_rx_sync = '0' then
                        s_tick_cnt <= 0;
                        s_state    <= START;
                    end if;

                -- ----------------------------------------------------------------
                when START =>
                    -- Attendre le milieu du start bit (tick 7) pour vérifier
                    -- que la ligne est toujours à '0' (pas un glitch)
                    if i_tick = '1' then
                        if s_tick_cnt = 7 then
                            if s_rx_sync = '0' then
                                -- Start bit valide : démarrer la réception des données
                                s_tick_cnt <= 0;
                                s_bit_idx  <= 0;
                                s_state    <= DATA;
                            else
                                -- Glitch : retour en IDLE
                                s_state <= IDLE;
                            end if;
                        else
                            s_tick_cnt <= s_tick_cnt + 1;
                        end if;
                    end if;

                -- ----------------------------------------------------------------
                when DATA =>
                    -- Échantillonnage au milieu de chaque bit (tick 15 après reset à 0)
                    if i_tick = '1' then
                        if s_tick_cnt = 15 then
                            s_tick_cnt                <= 0;
                            s_shift_reg(s_bit_idx)    <= s_rx_sync;   -- LSB en premier

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
                    -- Vérification du stop bit au milieu (tick 15)
                    if i_tick = '1' then
                        if s_tick_cnt = 15 then
                            s_tick_cnt <= 0;
                            s_state    <= IDLE;

                            if s_rx_sync = '1' then
                                -- Stop bit valide : publier l'octet reçu
                                o_data  <= s_shift_reg;
                                o_valid <= '1';
                            end if;
                            -- Si stop bit = '0' : erreur de trame, octet ignoré

                        else
                            s_tick_cnt <= s_tick_cnt + 1;
                        end if;
                    end if;

            end case;
        end if;
    end process;

end architecture rtl;