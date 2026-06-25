--------------------------------------------------------------------------------
-- Module      : uart_framer.vhd
-- Description : Encapsule un vecteur de données dans une trame UART et l'envoie
--               octet par octet via uart_tx.vhd.
--
--               Format de trame :
--                 [0]     : En-tête fixe 0xAA (sync)
--                 [1]     : Longueur c_N_BYTES (nombre d'octets de données)
--                 [2..N+1]: Données (octet 0 = bits 7..0, ..., padding MSB si besoin)
--                 [N+2]   : Checksum XOR de tous les octets de données
--
-- Correction  : état SEND scindé en LOAD_BYTE (charge s_tx_data) et
--               SEND_BYTE (pulse s_tx_send le cycle suivant, données stables)
--
-- Utilisation :
--   - Définir g_N_BITS via le generic (nombre de bits utiles en entrée).
--   - i_data est exactement std_logic_vector(g_N_BITS - 1 downto 0).
--   - Le padding vers le byte supérieur est géré en interne.
--   - Pulser i_send 1 cycle pour démarrer l'envoi.
--   - o_busy reste à '1' pendant toute la durée de l'envoi.
--   - Ne pas modifier i_data ni pulser i_send tant que o_busy = '1'.
--
-- Exemple : g_N_BITS = 12 (ADC 12 bits)
--   c_N_BYTES = (12 + 7) / 8 = 2
--   i_data = "101010110101" (0xAB5)
--   → trame : 0xAA 0x02 0xB5 0x0A 0xBF
--             (octet 0 = bits 7..0 = 0xB5, octet 1 = bits 11..8 paddé = 0x0A)
--             (checksum = 0xB5 XOR 0x0A = 0xBF)
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_framer is
    generic (
        g_N_BITS  : integer := 12   -- Nombre de bits utiles en entrée
    );
    port (
        i_clk50   : in  std_logic;                                  -- Horloge système (50 MHz)
        i_reset_n : in  std_logic;                                  -- Reset actif bas
        i_tick    : in  std_logic;                                  -- Tick baud_gen (16x baud rate)
        i_data    : in  std_logic_vector(g_N_BITS - 1 downto 0);   -- Données à envoyer
        i_send    : in  std_logic;                                  -- Strobe : démarrer l'envoi (1 cycle)
        o_tx      : out std_logic;                                  -- Ligne série UART TX
        o_busy    : out std_logic                                   -- '1' pendant l'envoi
    );
end entity uart_framer;

architecture rtl of uart_framer is

    -- Calcul du nombre d'octets nécessaires
    constant c_N_BYTES   : integer := (g_N_BITS + 7) / 8;

    -- Taille totale de la trame : header(1) + length(1) + données(N) + checksum(1)
    constant c_FRAME_LEN : integer := c_N_BYTES + 3;

    -- Taille paddée au multiple de 8 bits
    constant c_PAD_BITS  : integer := c_N_BYTES * 8;

    -- Données paddées
    signal s_data_pad  : std_logic_vector(c_PAD_BITS - 1 downto 0) := (others => '0');

    -- Tableau d'octets pour la trame complète
    type t_frame is array(0 to c_FRAME_LEN - 1) of std_logic_vector(7 downto 0);
    signal s_frame : t_frame := (others => (others => '0'));

    -- FSM
    -- IDLE      : attente de i_send
    -- BUILD     : construction de la trame en 1 cycle
    -- LOAD_BYTE : charge s_tx_data depuis s_frame(s_byte_idx)
    -- SEND_BYTE : pulse s_tx_send (s_tx_data stable depuis 1 cycle)
    -- WAIT_BYTE : attente que uart_tx finisse l'octet courant
    type t_state is (IDLE, BUILD, BUILD_WAIT, LOAD_BYTE, SEND_BYTE, WAIT_BYTE, WAIT_BYTE_END);
    signal s_state : t_state := IDLE;

    -- Index de l'octet en cours d'envoi
    signal s_byte_idx : integer range 0 to c_FRAME_LEN := 0;

    -- Signaux vers uart_tx
    signal s_tx_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal s_tx_send  : std_logic := '0';
    signal s_tx_busy  : std_logic;

begin

    -- Padding MSB : bits au-dessus de g_N_BITS mis à '0'
    s_data_pad(g_N_BITS - 1 downto 0)          <= i_data;
    s_data_pad(c_PAD_BITS - 1 downto g_N_BITS) <= (others => '0');

    -- -------------------------------------------------------------------------
    -- Instanciation de uart_tx
    -- -------------------------------------------------------------------------
    uart_tx_inst : entity work.uart_tx
        port map (
            i_clk50   => i_clk50,
            i_reset_n => i_reset_n,
            i_tick    => i_tick,
            i_data    => s_tx_data,
            i_send    => s_tx_send,
            o_tx      => o_tx,
            o_busy    => s_tx_busy
        );

    -- -------------------------------------------------------------------------
    -- FSM principale
    -- -------------------------------------------------------------------------
    process(i_clk50, i_reset_n)
        variable v_checksum : std_logic_vector(7 downto 0);
    begin
        if i_reset_n = '0' then
            s_state    <= IDLE;
            s_byte_idx <= 0;
            s_tx_data  <= (others => '0');
            s_tx_send  <= '0';
            o_busy     <= '0';

        elsif rising_edge(i_clk50) then
            s_tx_send <= '0';   -- strobe par défaut

            case s_state is

                -- ----------------------------------------------------------------
                when IDLE =>
                    o_busy <= '0';
                    if i_send = '1' then
                        o_busy  <= '1';
                        s_state <= BUILD;
                    end if;

                -- ----------------------------------------------------------------
                -- Construction de la trame en 1 cycle
                -- ----------------------------------------------------------------
                when BUILD =>
                    -- Calcul du checksum XOR sur tous les octets de données
                    v_checksum := (others => '0');
                    for k in 0 to c_N_BYTES - 1 loop
                        v_checksum := v_checksum xor
                                      s_data_pad((k * 8 + 7) downto (k * 8));
                    end loop;

                    -- Octet 0 : en-tête
                    s_frame(0) <= x"AA";

                    -- Octet 1 : longueur
                    s_frame(1) <= std_logic_vector(to_unsigned(c_N_BYTES, 8));

                    -- Octets 2..c_N_BYTES+1 : données
                    for k in 0 to c_N_BYTES - 1 loop
                        s_frame(k + 2) <= s_data_pad((k * 8 + 7) downto (k * 8));
                    end loop;

                    -- Octet c_N_BYTES+2 : checksum
                    s_frame(c_N_BYTES + 2) <= v_checksum;

                    s_byte_idx <= 0;
                    s_state    <= BUILD_WAIT;
						  
					 when BUILD_WAIT =>
						  s_state <= LOAD_BYTE;       -- s_frame stable maintenant

                -- ----------------------------------------------------------------
                -- Cycle 1 : charge l'octet courant dans s_tx_data
                -- ----------------------------------------------------------------
                when LOAD_BYTE =>
                    if s_byte_idx = c_FRAME_LEN then
                        -- Tous les octets ont été envoyés
                        s_state <= IDLE;
                    else
                        s_tx_data <= s_frame(s_byte_idx);
                        s_state   <= SEND_BYTE;
                    end if;

                -- ----------------------------------------------------------------
                -- Cycle 2 : s_tx_data stable → pulse s_tx_send
                -- ----------------------------------------------------------------
                when SEND_BYTE =>
                    s_tx_send  <= '1';
                    s_byte_idx <= s_byte_idx + 1;
                    s_state    <= WAIT_BYTE;

                -- ----------------------------------------------------------------
                -- Attente de fin de transmission de l'octet courant
                -- ----------------------------------------------------------------
                when WAIT_BYTE =>
						 -- Attend d'abord que uart_tx soit occupé, puis qu'il libère
						 if s_tx_busy = '1' then
							  s_state <= WAIT_BYTE_END;
						 end if;

					 when WAIT_BYTE_END =>
						 if s_tx_busy = '0' then
							  s_state <= LOAD_BYTE;
						 end if;

            end case;
        end if;
    end process;

end architecture rtl;