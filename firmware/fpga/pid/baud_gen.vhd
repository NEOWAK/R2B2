--------------------------------------------------------------------------------
-- Module      : baud_gen.vhd
-- Description : Générateur de baud rate pour UART sur DE10-Lite (50 MHz)
--               Génère un tick à 16x le baud rate sélectionné.
--               Tick actif 1 cycle d'horloge sur TICK_OUT.
--
-- Utilisation :
--   Instancier ce module et connecter TICK_OUT aux modules uart_tx et uart_rx.
--   Choisir le baud rate via le generic g_BAUD_RATE.
--
-- Baud rates courants (CLK = 50 MHz) :
--   9600    → DIV = 325  (erreur : ~0.16 %)
--   19200   → DIV = 163  (erreur : ~0.16 %)
--   115200  → DIV = 27   (erreur : ~2.12 %)
--
-- Le diviseur est calculé comme : DIV = g_CLK_FREQ / (g_BAUD_RATE * 16)
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity baud_gen is
    generic (
        g_CLK_FREQ  	: integer := 50_000_000;   -- Fréquence d'horloge en Hz (DE10-Lite : 50 MHz)
        g_BAUD_RATE 	: integer := 115_200        -- Baud rate cible en bauds/s
    );
    
	 port (
        i_clk50  		: in  std_logic;   -- Horloge système (50 MHz sur DE10-Lite)
        i_reset_n 	: in  std_logic;  -- Reset actif bas (KEY0 par exemple)
        o_tick   		: out std_logic    -- Tick à 16x baud rate (1 cycle d'horloge actif)
    );
end entity baud_gen;


architecture rtl of baud_gen is

    -- Calcul du diviseur : nombre de cycles d'horloge entre deux ticks
    -- On utilise 16x le baud rate pour permettre l'échantillonnage au milieu des bits
    constant 	c_DIVISOR	: integer 									:= g_CLK_FREQ / (g_BAUD_RATE * 16);
    signal 		s_counter 	: integer range 0 to c_DIVISOR - 1 	:= 0;

begin

    process(i_clk50, i_reset_n)
    begin
        if i_reset_n = '0' then
            s_counter   <= 0;
            o_tick   	<= '0';

        elsif rising_edge(i_clk50) then
            o_tick <= '0';

            if s_counter = c_DIVISOR - 1 then
                s_counter  <= 0;
                o_tick 		<= '1';
            else
                s_counter 	<= s_counter + 1;
            end if;
        end if;
    end process;

end architecture rtl;