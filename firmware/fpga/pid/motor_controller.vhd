library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity motor_controller is
    port (
        i_clk50     : in  std_logic;
        i_reset_n   : in  std_logic;
        i_speed     : in  std_logic_vector(7 downto 0);
        i_direction : in  std_logic;
        i_enable    : in  std_logic;
        o_r_pwm     : out std_logic;
        o_l_pwm     : out std_logic;
        o_r_en      : out std_logic;
        o_l_en      : out std_logic
    );
end entity;

architecture rtl of motor_controller is
    signal s_prescaler   : integer range 0 to 9  := 0;
    signal s_pwm_tick    : std_logic             := '0';
    signal s_pwm_counter : unsigned(7 downto 0)  := (others => '0');
begin
    process(i_clk50, i_reset_n)
    begin
        if i_reset_n = '0' then
            s_prescaler   <= 0;
            s_pwm_tick    <= '0';
            s_pwm_counter <= (others => '0');
            o_r_pwm       <= '0';
            o_l_pwm       <= '0';
            o_r_en        <= '0';
            o_l_en        <= '0';

        elsif rising_edge(i_clk50) then

            -- Prescaler ÷10
            if s_prescaler = 9 then
                s_prescaler <= 0;
                s_pwm_tick  <= '1';
            else
                s_prescaler <= s_prescaler + 1;
                s_pwm_tick  <= '0';
            end if;

            -- Compteur PWM 8 bits
            if s_pwm_tick = '1' then
                s_pwm_counter <= s_pwm_counter + 1;
            end if;

            -- Génération des sorties
            if i_enable = '1' then
                o_r_en <= '1';
                o_l_en <= '1';

                if i_direction = '0' then
                    -- ✅ if/else à la place de when/else
                    if s_pwm_counter <= unsigned(i_speed) then
                        o_r_pwm <= '1';
                    else
                        o_r_pwm <= '0';
                    end if;
                    o_l_pwm <= '0';
                else
                    o_r_pwm <= '0';
                    if s_pwm_counter <= unsigned(i_speed) then
                        o_l_pwm <= '1';
                    else
                        o_l_pwm <= '0';
                    end if;
                end if;

            else
                o_r_en  <= '0';
                o_l_en  <= '0';
                o_r_pwm <= '0';
                o_l_pwm <= '0';
            end if;

        end if;
    end process;
end architecture;