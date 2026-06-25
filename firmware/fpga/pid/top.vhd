library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
    port (
        MAX10_CLK1_50 	: in    std_logic;
        KEY           	: in    std_logic_vector(1 downto 0);
		  GPIO				: inout std_logic_vector(35 downto 0)		-- [0 ; 35] Digital PINs
    );
end entity top;	

architecture rtl of top is

		-- =========================================================
		-- DÉCLARATIONS DES COMPOSANTS
		-- =========================================================

		component motor_controller is
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
		end component motor_controller;


		component adc0 is
        port (
            CLOCK : in  std_logic                     := 'X'; -- clk
            RESET : in  std_logic                     := 'X'; -- reset
            CH0   : out std_logic_vector(11 downto 0);        -- CH0
            CH1   : out std_logic_vector(11 downto 0);        -- CH1
            CH2   : out std_logic_vector(11 downto 0);        -- CH2
            CH3   : out std_logic_vector(11 downto 0);        -- CH3
            CH4   : out std_logic_vector(11 downto 0);        -- CH4
            CH5   : out std_logic_vector(11 downto 0);        -- CH5
            CH6   : out std_logic_vector(11 downto 0);        -- CH6
            CH7   : out std_logic_vector(11 downto 0)         -- CH7
        );
    end component adc0;



		-- =========================================================
		-- SIGNAUX INTERNES
		-- =========================================================
	 
		-- Signaux ADC
		signal s_ADCIN0           	: std_logic_vector(11 downto 0);
		signal s_ADCIN1           	: std_logic_vector(11 downto 0);
		
		-- Signaux UART
		signal s_baud_tick 			: std_logic;
		
		-- Signaux VITESSE
		signal s_period 			   : std_logic_vector(34 downto 0);
		signal s_angle_deg 			: std_logic_vector(8 downto 0);
		signal s_event_type			: std_logic_vector(1 downto 0);
		signal s_temp           	: std_logic_vector(11 downto 0);
		
		
		-- =========================================================
		-- ALIASES
		-- =========================================================

		alias RESET_n        : std_logic is KEY(0);
		
		alias SS49E_0			: std_logic_vector(11 downto 0) is s_ADCIN0;
		alias SS49E_1			: std_logic_vector(11 downto 0) is s_ADCIN1;
		
		alias UART_TX			: std_logic is GPIO(0);

	  

begin
		-- =========================================================
		-- INSTANCES
		-- =========================================================
		
		u0 : component adc0
        port map (
            CLOCK => MAX10_CLK1_50,
            RESET => not RESET_n, --    reset.reset
            CH0   => s_ADCIN0,   -- readings.CH0
            CH1   => s_ADCIN1,   --         .CH1
            CH2   => open,   --         .CH2
            CH3   => open,   --         .CH3
            CH4   => open,   --         .CH4
            CH5   => open,   --         .CH5
            CH6   => open,   --         .CH6
            CH7   => open    --         .CH7
        );

				
		baud_gen_inst : entity work.baud_gen
			generic map (
					g_CLK_FREQ  => 50_000_000,
					g_BAUD_RATE => 115_200
			)
			
			port map (
					i_clk50   => MAX10_CLK1_50,
					i_reset_n => RESET_n,
					o_tick    => s_baud_tick
			);
			
		uart_mux_inst : entity work.uart_mux
			generic map (
				g_N_BITS 	=> 12
			)
    
			port map (
					i_clk50   => MAX10_CLK1_50,
					i_reset_n => RESET_n,
					i_tick    => s_baud_tick,
					i_ch0     => s_ADCIN0,
					i_ch1     => s_period(24 downto 13),--s_event_type & (9 downto 0 => '0'),
					o_tx      => UART_TX
			);
			
		adc_period_inst : entity work.adc_period
			port map(
				i_clk50    	=> MAX10_CLK1_50,
				i_reset_n  	=> RESET_n,
				i_adc_data 	=> s_ADCIN0,
				o_mean		=> s_temp,
				o_period   	=> s_period
    );
		



end architecture rtl;


		-- =========================================================
		-- REMARQUES
		-- =========================================================
		

-- 		ADC Signals sur JP8 (ADCIN0 et ADCIN1 activés via Plateform Designer)
-- 		s_adc_resp_data contient la valeur 12 bits quand s_adc_resp_valid = '1'
-- 		Tension réelle = s_adc_resp_data / 4095 * 5.0 V