library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Entité pour piloter un moteur via un driver BTS7960 (43A)
-- Ce module génère un signal PWM et gère la direction de rotation.
entity Motor_Controller is
    Port ( 
        clk       : in  STD_LOGIC;                    -- Horloge système (50 MHz)
        speed     : in  STD_LOGIC_VECTOR(7 downto 0); -- Vitesse de 0 à 255
        direction : in  STD_LOGIC;                    -- '0' = Avant, '1' = Arrière
        enable    : in  STD_LOGIC;                    -- '1' = Activé, '0' = Arrêt sécurité
        
        -- Sorties vers le module BTS7960
        R_PWM     : out STD_LOGIC;                    -- PWM côté droit du pont
        L_PWM     : out STD_LOGIC;                    -- PWM côté gauche du pont
        R_EN      : out STD_LOGIC;                    -- Enable côté droit
        L_EN      : out STD_LOGIC                     -- Enable côté gauche
    );
end Motor_Controller;

architecture Behavioral of Motor_Controller is

    -- Signaux pour le Prescaler (Diviseur d'horloge)
    -- 50 MHz / 10 = 5 MHz. Fréquence PWM finale : 5 MHz / 256 = 19.53 kHz
    signal prescaler_reg : integer range 0 to 9 := 0;
    signal pwm_tick      : std_logic := '0';
    
    -- Signaux pour la génération du PWM
    signal pwm_counter   : unsigned(7 downto 0) := (others => '0');
    signal pwm_signal    : std_logic := '0';

begin

    -----------------------------------------------------------
    -- BLOC 1 : PRESCALER (Génération du tick à 5 MHz)
    -----------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if prescaler_reg = 9 then
                prescaler_reg <= 0;
                pwm_tick <= '1'; 
            else
                prescaler_reg <= prescaler_reg + 1;
                pwm_tick <= '0';
            end if;
        end if;
    end process;

    -----------------------------------------------------------
    -- BLOC 2 : COMPTEUR PWM (0 à 255)
    -----------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if pwm_tick = '1' then
                pwm_counter <= pwm_counter + 1;
            end if;
        end if;
    end process;

    -----------------------------------------------------------
    -- BLOC 3 : COMPARAISON
    -----------------------------------------------------------
    -- Génère un signal '1' si le compteur est inférieur à la consigne 'speed'
    pwm_signal <= '1' when (pwm_counter < unsigned(speed)) else '0';

    -----------------------------------------------------------
    -- BLOC 4 : LOGIQUE DE DIRECTION SYNCHRONE
    -----------------------------------------------------------
    -- Protection : On s'assure qu'une seule sortie PWM est active à la fois.
    -- Les sorties sont synchronisées sur 'clk' pour éviter les glitchs.
    process(clk)
    begin
        if rising_edge(clk) then
            if enable = '1' then
                -- On réveille le driver (Enable pins à 1)
                R_EN <= '1';
                L_EN <= '1';
                
                if direction = '0' then
                    R_PWM <= pwm_signal; -- Signal sur le côté droit
                    L_PWM <= '0';        -- On force impérativement l'autre à 0
                else
                    R_PWM <= '0';        -- On force impérativement l'autre à 0
                    L_PWM <= pwm_signal; -- Signal sur le côté gauche
                end if;
            else
                -- Si enable = '0', on coupe TOUT (Roue libre)
                R_EN  <= '0';
                L_EN  <= '0';
                R_PWM <= '0';
                L_PWM <= '0';
            end if;
        end if;
    end process;

end Behavioral;