library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pince_controlleur is
    Port (
        clk          : in  STD_LOGIC; 
        reset_n      : in  STD_LOGIC; 
        ouvrir       : in  STD_LOGIC; 
        fermer       : in  STD_LOGIC; 
        motor_out    : out STD_LOGIC_VECTOR (3 downto 0) 
    );
end pince_controlleur;

architecture Behavioral of pince_controlleur is
    -- VITESSE DIAGNOSTIC (10 Hz) pour voir les LEDs clignoter
    constant CLK_DIV_VAL : integer := 50000; --62500
    constant MAX_STEPS    : integer := 10000;   --4096
    
    signal clk_en       : std_logic := '0';
    signal clk_cnt      : integer range 0 to CLK_DIV_VAL := 0;
    
    type state_type is (IDLE, MOVING_OPEN, MOVING_CLOSE, WAIT_RELEASE);
    signal state        : state_type := IDLE;
    
    signal step_counter : integer range 0 to MAX_STEPS := 0;
    signal phase_index  : integer range 0 to 7 := 0; 

begin

    -- 1. Générateur de vitesse
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            clk_cnt <= 0; clk_en <= '0';
        elsif rising_edge(clk) then
            if clk_cnt >= CLK_DIV_VAL then
                clk_cnt <= 0; clk_en <= '1';
            else
                clk_cnt <= clk_cnt + 1; clk_en <= '0';
            end if;
        end if;
    end process;

    -- 2. Logique de mouvement
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state <= IDLE; step_counter <= 0; phase_index <= 0;
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    step_counter <= 0;
                    if ouvrir = '1' then state <= MOVING_OPEN;
                    elsif fermer = '1' then state <= MOVING_CLOSE;
                    end if;

                when MOVING_OPEN =>
                    if clk_en = '1' then
                        if step_counter < MAX_STEPS then
                            step_counter <= step_counter + 1;
                            -- SENS HORAIRE (0 vers 7)
                            if phase_index = 7 then phase_index <= 0;
                            else phase_index <= phase_index + 1; end if;
                        else state <= WAIT_RELEASE; end if;
                    end if;

                when MOVING_CLOSE =>
                    if clk_en = '1' then
                        if step_counter < MAX_STEPS then
                            step_counter <= step_counter + 1;
                            -- SENS ANTI-HORAIRE (7 vers 0)
                            if phase_index = 0 then phase_index <= 7;
                            else phase_index <= phase_index - 1; end if;
                        else state <= WAIT_RELEASE; end if;
                    end if;
                
                when WAIT_RELEASE =>
                    if ouvrir = '0' and fermer = '0' then state <= IDLE; end if;
            end case;
        end if;
    end process;

    -- 3. Sortie Combinatoire (Half-Step)
    -- Remplace ton process de sortie par celui-ci juste pour un test
    process(phase_index, state)
    begin
        if state = IDLE or state = WAIT_RELEASE then
            motor_out <= "0000";
        else
            case phase_index is
                when 0 => motor_out <= "1000"; -- A
                when 1 => motor_out <= "1100"; -- A+B
                when 2 => motor_out <= "0100"; -- B
                when 3 => motor_out <= "0110"; -- B+C
                when 4 => motor_out <= "0010"; -- C
                when 5 => motor_out <= "0011"; -- C+D
                when 6 => motor_out <= "0001"; -- D
                when 7 => motor_out <= "1001"; -- D+A
                when others => motor_out <= "0000";
            end case;
        end if;
    end process;
end Behavioral;