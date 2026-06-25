library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_period is
	port(
		i_clk50      : in  std_logic;
		i_reset_n    : in  std_logic;
		i_adc_data   : in  std_logic_vector(11 downto 0);
		
		o_mean		 : out std_logic_vector(11 downto 0);
		o_period 	 : out std_logic_vector(34 downto 0)
	);
end entity adc_period;


architecture rtl of adc_period is
	type t_init_state is (
        ST_FIND_MAX,
        ST_SYNC,
		  ST_WAIT_MID,
        ST_FIND_MIN_0,
        ST_FIND_MAX_1,
        ST_FIND_MIN_1,
        ST_FIND_MAX_2,
        ST_FIND_MIN_2,
		  ST_CALC_MEAN,
        ST_DONE
    );
	 
	 type t_state is (
		 ST_SEG_MAX_0,
		 ST_SEG_MEAN_01,
		 ST_SEG_MIN_0,
		 ST_SEG_MEAN_12,
		 ST_SEG_MAX_1,
		 ST_SEG_MEAN_23,
		 ST_SEG_MIN_1,
		 ST_SEG_MEAN_34,
		 ST_SEG_MAX_2,
		 ST_SEG_MEAN_45,
		 ST_SEG_MIN_2,
		 ST_SEG_MEAN_50
	 );
	 
    constant c_ADC_MID      : unsigned(11 downto 0) 						:= to_unsigned(2048, 12);
	 constant c_ADC_MARGIN	 : unsigned(11 downto 0) 						:= to_unsigned(16, 12);
    constant c_MID_CONFIRM  : integer               						:= 10;
	 constant C_TICKS_MAX	 : unsigned(30 downto 0) 						:= (others => '1');	  

    signal s_init_state     : t_init_state          						:= ST_FIND_MAX;
    signal s_init_done      : std_logic             						:= '0';
    signal s_trigger			 : std_logic             						:= '0';
    signal s_mid_count      : integer range 0 to c_MID_CONFIRM+1 		:= 0;

    signal s_max_0          : unsigned(11 downto 0) 						:= (others => '0');
    signal s_min_0          : unsigned(11 downto 0) 						:= to_unsigned(4095, 12);
    signal s_max_1          : unsigned(11 downto 0) 						:= (others => '0');
    signal s_min_1          : unsigned(11 downto 0) 						:= to_unsigned(4095, 12);
    signal s_max_2          : unsigned(11 downto 0) 						:= (others => '0');
    signal s_min_2          : unsigned(11 downto 0) 						:= to_unsigned(4095, 12);
    signal s_mean           : unsigned(11 downto 0) 						:= to_unsigned(2048, 12);
	 
	 signal s_seg_state 		 : t_state 											:= ST_SEG_MAX_0; 
	 signal s_tick_period    : unsigned(34 downto 0) 						:= (others => '0');
	 signal s_tick_count     : unsigned(30 downto 0) 						:= (others => '0');
	 
	 signal s_tick_max0      : unsigned(30 downto 0) 						:= (others => '0');
	 signal s_tick_mean01    : unsigned(30 downto 0) 						:= (others => '0');
	 signal s_tick_min0      : unsigned(30 downto 0) 						:= (others => '0');
	 signal s_tick_mean12    : unsigned(30 downto 0) 						:= (others => '0');
	 signal s_tick_max1      : unsigned(30 downto 0) 						:= (others => '0');
	 signal s_tick_mean23    : unsigned(30 downto 0) 						:= (others => '0');
	 signal s_tick_min1      : unsigned(30 downto 0) 						:= (others => '0');
	 signal s_tick_mean34    : unsigned(30 downto 0) 						:= (others => '0');
	 signal s_tick_max2      : unsigned(30 downto 0) 						:= (others => '0');
	 signal s_tick_mean45    : unsigned(30 downto 0) 						:= (others => '0');
	 signal s_tick_min2      : unsigned(30 downto 0) 						:= (others => '0');
	 signal s_tick_mean50    : unsigned(30 downto 0) 						:= (others => '0');
	 

	
	
	
begin

	p_main : process(i_clk50, i_reset_n)
		 variable v_adc : unsigned(11 downto 0);
	begin
		 if i_reset_n = '0' then
			  s_seg_state     <= ST_SEG_MAX_0;
			  s_tick_count    <= (others => '0');
			  s_tick_period  <= (others => '0');

		 elsif rising_edge(i_clk50) then
			  if s_init_done = '1' then
					v_adc := unsigned(i_adc_data);
					
					if s_tick_count < c_TICKS_MAX then
						s_tick_count <= s_tick_count + 1;
					end if;

					case s_seg_state is

						 when ST_SEG_MAX_0 =>
							  if v_adc >= s_max_0 - c_ADC_MARGIN then
									s_tick_max0     <= s_tick_count;
									s_tick_count    <= (others => '0');
									s_seg_state     <= ST_SEG_MEAN_01;
							  end if;
							  
							  o_mean 	<= std_logic_vector(s_max_0);

						 when ST_SEG_MEAN_01 =>
							  if v_adc <= s_mean then
									s_tick_mean01   <= s_tick_count;
									s_tick_count    <= (others => '0');
									s_seg_state     <= ST_SEG_MIN_0;
							  end if;
							  
							  o_mean 	<= std_logic_vector(s_mean);

						 when ST_SEG_MIN_0 =>
							  if v_adc <= s_min_0 + c_ADC_MARGIN then
									s_tick_min0    <= s_tick_count;
									s_tick_count    <= (others => '0');
									s_seg_state     <= ST_SEG_MEAN_12;
							  end if;
							  
							  o_mean 	<= std_logic_vector(s_min_0);

						 when ST_SEG_MEAN_12 =>
							  if v_adc >= s_mean then
									s_tick_mean12   <= s_tick_count;
									s_tick_count    <= (others => '0');
									s_seg_state     <= ST_SEG_MAX_1;
							  end if;
							  
							  o_mean 	<= std_logic_vector(s_mean);

						 when ST_SEG_MAX_1 =>
							  if v_adc >= s_max_1 - c_ADC_MARGIN then
									s_tick_max1     <= s_tick_count;
									s_tick_count    <= (others => '0');
									s_seg_state     <= ST_SEG_MEAN_23;
							  end if;
							  
							  o_mean 	<= std_logic_vector(s_max_1);

						 when ST_SEG_MEAN_23 =>
							  if v_adc <= s_mean then
									s_tick_mean23   <= s_tick_count;
									s_tick_count    <= (others => '0');
									s_seg_state     <= ST_SEG_MIN_1;
							  end if;
							  
							  o_mean 	<= std_logic_vector(s_mean);

						 when ST_SEG_MIN_1 =>
							  if v_adc <= s_min_1 + c_ADC_MARGIN then
									s_tick_min1     <= s_tick_count;
									s_tick_count    <= (others => '0');
									s_seg_state     <= ST_SEG_MEAN_34;
							  end if;
							  
							  o_mean 	<= std_logic_vector(s_min_1);

						 when ST_SEG_MEAN_34 =>
							  if v_adc >= s_mean then
									s_tick_mean34   <= s_tick_count;
									s_tick_count    <= (others => '0');
									s_seg_state     <= ST_SEG_MAX_2;
							  end if;
							  
							  o_mean 	<= std_logic_vector(s_mean);

						 when ST_SEG_MAX_2 =>
							  if v_adc >= s_max_2 - c_ADC_MARGIN then
									s_tick_max2     <= s_tick_count;
									s_tick_count    <= (others => '0');
									s_seg_state     <= ST_SEG_MEAN_45;
							  end if;
							  
							  o_mean 	<= std_logic_vector(s_max_2);

						 when ST_SEG_MEAN_45 =>
							  if v_adc <= s_mean then
									s_tick_mean45   <= s_tick_count;
									s_tick_count    <= (others => '0');
									s_seg_state     <= ST_SEG_MIN_2;
							  end if;
							  
							  o_mean 	<= std_logic_vector(s_mean);

						 when ST_SEG_MIN_2 =>
							  if v_adc <= s_min_2 + c_ADC_MARGIN then
									s_tick_min2     <= s_tick_count;
									s_tick_count    <= (others => '0');
									s_seg_state     <= ST_SEG_MEAN_50;
							  end if;
							  
							  o_mean 	<= std_logic_vector(s_min_2);

						 when ST_SEG_MEAN_50 =>
							  if v_adc >= s_mean then
									s_tick_mean50   <= s_tick_count;
									s_tick_count    <= (others => '0');
									s_seg_state     <= ST_SEG_MAX_0;
							  end if;
							  
							  o_mean 	<= std_logic_vector(s_mean);

						 when others =>
							  s_seg_state  <= ST_SEG_MAX_0;
							  s_tick_count <= (others => '0');

					end case;
					
					s_tick_period <= resize(s_tick_max0, 35) + resize(s_tick_mean01, 35) + resize(s_tick_min0, 35) + resize(s_tick_mean12, 35) 
										+ resize(s_tick_max1, 35) + resize(s_tick_mean23, 35) + resize(s_tick_min1, 35) + resize(s_tick_mean34, 35)
										+ resize(s_tick_max2, 35) + resize(s_tick_mean45, 35) + resize(s_tick_min2, 35) + resize(s_tick_mean50, 35) ;
			  end if;
		 end if;
	end process p_main;
	
	
	---------
	
	p_init : process(i_clk50, i_reset_n)
        variable v_adc  : unsigned(11 downto 0);
        variable v_sum  : unsigned(14 downto 0);    -- 15 bits : max 8 × 4095 = 32760 < 2^15
    begin
        if i_reset_n = '0' then
            s_init_state    <= ST_FIND_MAX;
            s_init_done     <= '0';
            s_trigger 		 <= '0';
            s_mid_count     <= 0;
            s_max_0         <= (others => '0');
            s_min_0         <= to_unsigned(4095, 12);
            s_max_1         <= (others => '0');
            s_min_1         <= to_unsigned(4095, 12);
            s_max_2         <= (others => '0');
            s_min_2         <= to_unsigned(4095, 12);
            s_mean          <= to_unsigned(2048, 12);

        elsif rising_edge(i_clk50) then
				if s_init_done = '0' then
					v_adc := unsigned(i_adc_data);
					
					if v_adc >= to_unsigned(2100, 12) or v_adc <= to_unsigned(1900, 12) then
						s_trigger <= '1' ;
					end if;

					case s_init_state is

						 -- ------------------------------------------------
						 -- Pré-phase : s_max_0 accumule directement le max
						 -- ------------------------------------------------
						 when ST_FIND_MAX =>
							  if v_adc > s_max_0 then
									s_max_0 <= v_adc;
							  end if;

							  if v_adc = c_ADC_MID then
									if s_trigger = '1' then
										 s_trigger <= '0' ;
										 if s_mid_count >= c_MID_CONFIRM then
											  s_mid_count  <= 0;
											  s_init_state <= ST_SYNC;
										 else
											  s_mid_count <= s_mid_count + 1;
										 end if;
									end if;
							  end if;

						 -- ------------------------------------------------
						 -- Synchronisation : attente du premier sommet
						 -- ------------------------------------------------
						 when ST_SYNC =>
							  if v_adc >= s_max_0 - c_ADC_MARGIN then
									s_init_state    <= ST_WAIT_MID;
							  end if;
						
						 -- ------------------------------------------------
						 -- Demi-cycle 0 : attente du mid
						 -- ------------------------------------------------
						 when ST_WAIT_MID =>
							  if v_adc = c_ADC_MID then
									s_trigger 		<= '0' ;
									s_init_state   <= ST_FIND_MIN_0;
							  end if;
							  
						 -- ------------------------------------------------
						 -- Demi-cycle 1 : descente — min_0
						 -- ------------------------------------------------
						 when ST_FIND_MIN_0 =>
							  if v_adc < s_min_0 then
									s_min_0 <= v_adc;
							  end if;

							  if v_adc = c_ADC_MID and s_trigger = '1' then
									s_trigger <= '0';
									s_init_state    <= ST_FIND_MAX_1;
							  end if;

						 -- ------------------------------------------------
						 -- Demi-cycle 2 : montée — max_1
						 -- ------------------------------------------------
						 when ST_FIND_MAX_1 =>
							  if v_adc > s_max_1 then
									s_max_1 <= v_adc;
							  end if;

							  if v_adc = c_ADC_MID and s_trigger = '1' then
									s_trigger <= '0';
									s_init_state    <= ST_FIND_MIN_1;
							  end if;

						 -- ------------------------------------------------
						 -- Demi-cycle 3 : descente — min_1
						 -- ------------------------------------------------
						 when ST_FIND_MIN_1 =>
							  if v_adc < s_min_1 then
									s_min_1 <= v_adc;
							  end if;

							  if v_adc = c_ADC_MID and s_trigger = '1' then
									s_trigger <= '0';
									s_init_state    <= ST_FIND_MAX_2;
							  end if;

						 -- ------------------------------------------------
						 -- Demi-cycle 4 : montée — max_2
						 -- ------------------------------------------------
						 when ST_FIND_MAX_2 =>
							  if v_adc > s_max_2 then
									s_max_2 <= v_adc;
							  end if;

							  if v_adc = c_ADC_MID and s_trigger = '1' then
									s_trigger <= '0';
									s_init_state    <= ST_FIND_MIN_2;
							  end if;

						 -- ------------------------------------------------
						 -- Demi-cycle 5 : descente — min_2
						 -- ------------------------------------------------
						 when ST_FIND_MIN_2 =>
							  if v_adc < s_min_2 then
									s_min_2 <= v_adc;
							  end if;

							  if v_adc = c_ADC_MID and s_trigger = '1' then
									s_trigger <= '0';
									s_init_state    <= ST_CALC_MEAN;
							  end if;

						 -- ------------------------------------------------
						 -- Calcul de la moyenne pondérée (1 cycle d'horloge)
						 -- s_mean = (2*max_0 + min_0 + max_1 + min_1 + max_2 + 2*min_2) / 8
						 -- ------------------------------------------------
						 when ST_CALC_MEAN =>
							  v_sum  := resize(s_max_0, 15) + resize(s_max_0, 15)  -- × 2
										 + resize(s_min_0, 15)
										 + resize(s_max_1, 15)
										 + resize(s_min_1, 15)
										 + resize(s_max_2, 15)
										 + resize(s_min_2, 15) + resize(s_min_2, 15); -- × 2
							  s_mean       <= v_sum(14 downto 3);                  -- division par 8 (shift right 3)
							  s_init_state <= ST_DONE;

						 -- ------------------------------------------------
						 -- Terminé
						 -- ------------------------------------------------
						 when ST_DONE =>
							  s_init_done <= '1';

						 when others =>
							  s_init_state <= ST_FIND_MAX;

					end case;
				end if;	
        end if;
    end process p_init;

	 o_period <= std_logic_vector(s_tick_period);

end architecture rtl;