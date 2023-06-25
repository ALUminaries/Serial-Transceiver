-------------------------------------------------------------------------------------
-- Transceiver Hardware Component Container
-------------------------------------------------------------------------------------
-- Author:      Maxwell Phillips
-- Copyright:   Ohio Northern University, 2023.
-- License:     GPL v3
-- Description: Container for hardware to be wrapped by serial transceiver.
-------------------------------------------------------------------------------------
--
-- This file is the hardware component container wrapped by the top level
-- serial transceiver. You should modify this file to wrap your hardware
-- in order to utilize it with the transceiver. See the transceiver file
-- for more details on its functionality.
--
-------------------------------------------------------------------------------------
-- Generics
-------------------------------------------------------------------------------------
--
-- [G_byte_bits]: Should be 8. Mapped from transceiver.
--
-- [G_total_bits]: The capacity, in bits, of the transceiver. 
--                 Mapped directly from the transceiver.
--                 Should be used to help structure hardware components.
--
-- [G_clk_freq]: Should match the clock frequency of the FPGA board.
--               Again, mapped by top-level transceiver.
--
-------------------------------------------------------------------------------------
-- Ports
-------------------------------------------------------------------------------------
--
-- [clk]: Input clock signal; should match [G_clk_freq] generic.
--
-- [reset]: Asynchronous reset signal. The module should be initially 
--          reset automatically by the transceiver, and will remain reset
--          until all bytes are received and the processing stage begins.
--          To preserve state, the hardware is NOT reset after the processing
--          stage and during the transmission stage. This allows you to display
--          output on the LEDs from the hardware container freely.
--
-- [load]: Signal which is received for one clock cycle ([G_clk_freq]) at the 
--         beginning of the processing stage, to allow for any hardware setup.
--
-- [start]: Signal which is asserted for as long as the processing stage is active.
--          Will remain high until [done] is asserted.
--
-- [btn_X]: These four signals are mapped to their corresponding buttons
--          on the FPGA development board. By default, left and right are 
--          used by the transceiver to display the delay counter on the LEDS.
--          In order to utilize the LEDs for your hardware, you must assert
--          [override_leds] when a button is pressed and set [leds] as desired. 
--
-- [switches]: The 16 dip switches on the FPGA development board. 
--
-- [input]: Parallel input of size [G_total_bits] from the transceiver.
-- 
-- [output]: Parallel output of size [G_total_bits] back to the transceiver.
--
-- [done]: Done signal for the transceiver to terminate the processing stage
--         and begin to transmit the result (from [output]) back over UART.
--
-- [override_leds]: Signal for the transceiver to use [leds] from the hardware
--                  instead of its own display.
--
-- [leds]: Output LEDs. Controlled by the transceiver based on [override_leds].
--
-------------------------------------------------------------------------------------

library IEEE;
  use IEEE.std_logic_1164.all;
  use IEEE.numeric_std.all;
  use IEEE.std_logic_unsigned.all;
  use IEEE.math_real.all;

entity hw_container is
  generic (
    G_byte_bits  : integer;
    G_total_bits : integer;
    G_clk_freq   : integer
  );
  port (
    clk           : in    std_logic; -- board clk
    reset         : in    std_logic; -- async reset which is high when xcvr is not in processing stage
    load          : in    std_logic; -- pseudo-async pulse received from xcvr at the start of processing stage
    start         : in    std_logic; -- consistent signal received from xcvr as long as processing stage is active
    btn_up        : in    std_logic;
    btn_left      : in    std_logic; -- left is by default used for displaying left half of delay counter from xcvr
    btn_right     : in    std_logic; -- right is by default used for displaying right half of delay counter from xcvr
    btn_down      : in    std_logic;
    switches      : in    std_logic_vector(15 downto 0);
    input         : in    std_logic_vector(G_total_bits - 1 downto 0);
    output        : out   std_logic_vector(G_total_bits - 1 downto 0);
    done          : out   std_logic; -- tells xcvr to finish processing stage and transmit back result ([output])
    override_leds : out   std_logic; -- tells xcvr to use [leds] instead of displaying bytes received or delay
    leds          : out   std_logic_vector(15 downto 0)
  );
end entity hw_container;

architecture behavioral of hw_container is

  -- clock divider
  constant div_clk_bits    : integer := 2;
  signal   div_clk         : std_logic;
  signal   div_clk_counter : std_logic_vector(div_clk_bits - 1 downto 0);
  constant div_clk_max     : std_logic_vector(div_clk_bits - 1 downto 0) := (others => '1');

  -- example internal data
  signal data_reg : std_logic_vector(G_total_bits - 1 downto 0);

begin

  -- clock divider
  div_clk <= '1' when (div_clk_counter(div_clk_counter'left) = '1') else '0';

  process (clk, reset) begin
    if (reset = '1') then
      override_leds <= '0'; -- IMPORTANT!
      leds            <= (others => '0');
      div_clk_counter <= (others => '0');
    elsif (clk'event and clk = '1') then
      -- example clock division logic
      if (div_clk_counter = div_clk_max) then
        div_clk_counter <= (others => '0');
      else
        div_clk_counter <= div_clk_counter + 1;
      end if;

      -- example LED multiplexing
      if (btn_up = '1') then
        override_leds <= '1';
        leds          <= (others => '1');
      elsif (btn_down = '1') then
        override_leds <= '1';
        leds          <= switches;
      -- elsif (btn_left = '1') then -- left is by default used for displaying delay counter from xcvr
      --   override_leds     <= '1';
      --   leds(15 downto 8) <= (others => '1');
      --   leds(7 downto 0)  <= (others => '0');
      -- elsif (btn_right = '1') then
      --   override_leds <= '1';
      --   -- leds          <= "1010101010101010";
      --   leds(15) <= div_clk;
      --   leds(14 downto 0) <= (others => '0');
      else
        override_leds <= '0';
      end if;
    end if;
  end process;

  -- example process using clock division
  process (div_clk, reset, load) begin
    if (reset = '1') then
      data_reg <= (others => '0');
      output <= (others => '0');
      done <= '0';
    elsif (load = '1') then
      -- example load usage
      data_reg <= input;
    elsif (div_clk'event and div_clk = '1') then

      -- example processing logic
      if (start = '1') then
        -- do something
        data_reg <= data_reg(data_reg'left - 1 downto 0) & '1';
      end if;

      if (and data_reg) then
        output <= data_reg;
        done   <= '1';
      else
        done <= '0';
      end if;
    end if;
  end process;
end architecture behavioral;
