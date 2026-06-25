--------------------------------------------------------------------------------
-- Module      : uart_mux.vhd
-- Description : Multiplexeur UART pour deux canaux ADC 12 bits.
--               Envoie alternativement i_ch0 et i_ch1 via uart_framer.
--               Une nouvelle trame est déclenchée dès que la précédente
--               est terminée.
--
-- Correction : ajout de l'état SEND pour séparer la capture des données
--              (LOAD) du strobe d'envoi (SEND), garantissant que s_data
--              est stable quand uart_framer construit la trame.
--
-- FSM :
--   LOAD       : capture du canal actif dans s_data
--   SEND       : pulse s_send (s_data stable depuis 1 cycle)
--   WAIT_START : attente que uart_framer lève o_busy
--   WAIT_END   : attente que uart_framer redescende o_busy (fin de trame)
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_mux is
    generic (
        g_N_BITS  : integer := 12
    );
    port (
        i_clk50   : in  std_logic;
        i_reset_n : in  std_logic;
        i_tick    : in  std_logic;
        i_ch0     : in  std_logic_vector(g_N_BITS - 1 downto 0);
        i_ch1     : in  std_logic_vector(g_N_BITS - 1 downto 0);
        o_tx      : out std_logic
    );
end entity uart_mux;

architecture rtl of uart_mux is

    type t_state is (LOAD, SEND, WAIT_START, WAIT_END);
    signal s_state   : t_state := LOAD;

    signal s_channel : std_logic := '0';
    signal s_data    : std_logic_vector(g_N_BITS - 1 downto 0) := (others => '0');
    signal s_send    : std_logic := '0';
    signal s_busy    : std_logic;

begin

    uart_framer_inst : entity work.uart_framer
        generic map (
            g_N_BITS => g_N_BITS
        )
        port map (
            i_clk50   => i_clk50,
            i_reset_n => i_reset_n,
            i_tick    => i_tick,
            i_data    => s_data,
            i_send    => s_send,
            o_tx      => o_tx,
            o_busy    => s_busy
        );

    process(i_clk50, i_reset_n)
    begin
        if i_reset_n = '0' then
            s_state   <= LOAD;
            s_channel <= '0';
            s_data    <= (others => '0');
            s_send    <= '0';

        elsif rising_edge(i_clk50) then
            s_send <= '0';  -- strobe par défaut

            case s_state is

                -- Cycle 1 : capture les données du canal actif
                when LOAD =>
                    if s_channel = '0' then
                        s_data <= i_ch0;
                    else
                        s_data <= i_ch1;
                    end if;
                    s_state <= SEND;

                -- Cycle 2 : s_data est stable, envoyer le strobe
                when SEND =>
                    s_send  <= '1';
                    s_state <= WAIT_START;

                -- Attente que uart_framer accepte la trame (o_busy monte)
                when WAIT_START =>
                    if s_busy = '1' then
                        s_state <= WAIT_END;
                    end if;

                -- Attente de fin de trame (o_busy redescend)
                when WAIT_END =>
                    if s_busy = '0' then
                        s_channel <= not s_channel;
                        s_state   <= LOAD;
                    end if;

            end case;
        end if;
    end process;

end architecture rtl;