library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ultrason is
    Port (
        clk      : in  STD_LOGIC;
        res      : in  STD_LOGIC; 
        trig     : out STD_LOGIC;
        echo     : in  STD_LOGIC;
        dist_mm  : out unsigned(11 downto 0) -- 12 bits pour monter jusqu'à 4095 mm
    );
end ultrason;

architecture Behavioral of ultrason is
    signal count : integer := 0;
    signal echo_count : integer := 0;
    
    type state_type is (IDLE, TRIGGER, WAIT_ECHO, COUNT_ECHO, CALC, DELAY);
    signal state : state_type := IDLE;
begin
    process(clk)
    begin
        if rising_edge(clk) then
            -- RESET : KEY0 pressé (0)
            if res = '0' then
                state <= IDLE;
                trig <= '0';
                count <= 0;
                echo_count <= 0;
                dist_mm <= (others => '0');
            else
                case state is
                    when IDLE =>
                        trig <= '0';
                        count <= 0;
                        state <= TRIGGER;

                    when TRIGGER =>
                        trig <= '1';
                        count <= count + 1;
                        if count = 500 then -- 10 µs
                            trig <= '0';
                            state <= WAIT_ECHO;
                            count <= 0; 
                        end if;

                    when WAIT_ECHO =>
                        count <= count + 1;
                        if echo = '1' then
                            echo_count <= 0;
                            state <= COUNT_ECHO;
                        elsif count > 1000000 then -- Timeout 20ms
                            dist_mm <= (others => '0');
                            state <= DELAY;
                            count <= 0;
                        end if;

                    when COUNT_ECHO =>
                        echo_count <= echo_count + 1;
                        if echo = '0' then
                            state <= CALC;
                        elsif echo_count > 1500000 then -- Trop loin
                            dist_mm <= to_unsigned(4000, 12); -- Plafond à 4m
                            state <= DELAY;
                            count <= 0;
                        end if;

                    when CALC =>
                        -- Diviseur pour mm : 294
                        dist_mm <= to_unsigned(echo_count / 294, 12);
                        count <= 0;
                        state <= DELAY;

                    when DELAY =>
                        count <= count + 1;
                        if count > 3000000 then -- Pause 60ms
                            state <= IDLE;
                        end if;

                    when others => state <= IDLE;
                end case;
            end if;
        end if;
    end process;
end Behavioral;