-- Authors: Maxwell Phillips
-- Copyright: Ohio Northern University, 2023.
-- License: GPL v3
-- Description: Serial transceiver for use with 512-bit multiplier.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;
use IEEE.math_real.all;

entity transceiver is
  generic (
    bits: integer := 8;
    clk_freq: integer := 100000000; -- board clk
    baud_rate: integer := 9600;
    bytes: integer := 128; -- how many bytes to process/expect
    g_n: integer := 512;  -- Input (multiplier) length is n
    g_m: integer := 512   -- Input (multiplicand) length is m
  );
  port( 
    clk: in std_logic;
    reset: in std_logic;
    input: in std_logic;
    output: out std_logic;
    leds: out std_logic_vector(15 downto 0) -- for debug
  );
end transceiver;

architecture behavioral of transceiver is
  type state_type is (
    IDLE, -- Base idle state (loopable)
    RX_WAIT, -- Triggered once receiver is active, wait until it has recieved a byte (loopable)
    RX_INC_BYTE, -- Increment byte counter, load data from `rx_reg` into `data_reg` (instantaneous)
    RXD_BYTE, -- Prepare for next byte (instantaneous)
    RX_DONE, -- Received all bytes (instantaneous)
    PROC_START,  -- Starts the processing stage (instantaneous)
    PROC_WAIT, -- Wait for processing to complete (loopable)
    PROC_DONE, -- Transition to transmission stage (instantaneous)
    TX_LOAD, -- Load transmitter in parallel (instantaneous)
    TX_SEND, -- Assert send signal to tx (instantaneous)
    TX_WAIT, -- Wait for transmitter to transmit byte
    TX_INC_BYTE, -- Increment byte counter, load data from `data_reg` into `tx_reg` (instantaneous)
    TXD_BYTE, -- Prepare for next byte (instantaneous)
    TX_DONE -- Transmitted all bytes (instantaneous)
  );
  signal state: state_type;
  signal next_state: state_type;
    
  component rx_controller
    port( 
      clk: in std_logic;
      reset: in std_logic;
      input: in std_logic;
      data: out std_logic_vector(bits - 1 downto 0); -- will be 0s if reset is high
      idle: out std_logic;
      receiving: out std_logic;
      done: out std_logic
    );
  end component;
  
  component tx_controller
    port( 
      clk: in std_logic;  
      send: in std_logic;
      data: in std_logic_vector (bits - 1 downto 0);
      ready: out std_logic;
      serial_out: out std_logic
    );
  end component;

  -- rx controller handling
  signal rx_reset, rx_idle, rx_active, rx_done_sig: std_logic;
  signal rx_reg: std_logic_vector(bits - 1 downto 0); -- rx output

  -- tx controller handling
  signal tx_send_sig, tx_ready, load_tx_reg: std_logic;
  signal tx_reg: std_logic_vector(bits - 1 downto 0); -- tx input

  -- shift register to hold serial IO data, excluding start and stop bits.
  constant DATA_REG_BITS: integer := bytes * bits;
  signal data_reg: std_logic_vector(DATA_REG_BITS - 1 downto 0);
  signal shift_data_reg, load_data_reg: std_logic;
  -- attribute dont_touch: string;
  -- attribute dont_touch of data_reg: signal is "true";
  signal data_reg_processed: std_logic_vector(DATA_REG_BITS - 1 downto 0);
  signal start_processing, done_processing: std_logic := '0';
  
  -- counter to record number of bytes received or transmitted
  -- needs to have (bytes + 1) values, so no (-1) on upper bound
  -- 0 is for no bytes received or transmitted yet
  constant LOG_BYTES: integer := integer(round(ceil(log2(real(bytes)))));
  signal byte_counter: std_logic_vector(LOG_BYTES downto 0); 
  signal en_byte_counter, clr_byte_counter: std_logic;
  
  -- clock divider
  signal div_clk: std_logic;
  signal hw_reset: std_logic;
  signal div_clk_counter: std_logic_vector(0 downto 0);
  constant DIV_CLK_MAX: std_logic_vector(0 downto 0) := (others => '1');
    
begin

  rx: rx_controller port map (
    clk => clk,
    reset => rx_reset,
    input => input,
    data => rx_reg,
    idle => rx_idle,
    receiving => rx_active,
    done => rx_done_sig
  );

  tx: tx_controller port map (
    clk => clk,
    data => tx_reg,
    serial_out => output,
    ready => tx_ready,
    send => tx_send_sig
  );

  -- clock divider
  div_clk <= '1' when (div_clk_counter(div_clk_counter'left) = '1') else '0';

  process (clk, reset) begin
    if (reset = '1') then
      state <= IDLE;
      byte_counter <= (others => '0');
      data_reg <= (others => '0');
      leds <= (others => '0');
      tx_reg <= (others => '0');
      div_clk_counter <= (others => '0');
    elsif (clk'event and clk = '1') then
      state <= next_state;
      
      -- show last byte shifted in on right side LEDs
      leds(15 downto 8) <= data_reg(data_reg'left downto DATA_REG_BITS - bits);
      
      -- show byte counter on rest of leds
      leds(byte_counter'left downto 0) <= byte_counter;
      leds(7 downto byte_counter'left + 1) <= (others => '0');
      
      if (load_tx_reg = '1') then
        tx_reg <= data_reg(data_reg'left downto data_reg'left - bits + 1);
      end if;
      
      if (load_data_reg = '1') then
        data_reg <= data_reg_processed;
      elsif (shift_data_reg = '1') then
        data_reg <= data_reg(data_reg'left - bits downto 0) & rx_reg;
      end if;
      
      -- handle byte counter
      if (clr_byte_counter = '1') then
        byte_counter <= (others => '0');
      elsif (en_byte_counter = '1') then
        byte_counter <= byte_counter + 1;
      end if;
      
      if (div_clk_counter = DIV_CLK_MAX) then
        div_clk_counter <= (others => '0');
      else
        div_clk_counter <= div_clk_counter + 1;
      end if;
    end if;
  end process;

  -- State Machine
  -- Inputs: state, rx_idle, rx_active, rx_done_sig, tx_ready
  -- Outputs: next_state, rx_reset, tx_send_sig, load_tx_reg,  
  --          shift_data_reg, load_data_reg, clr_byte_counter, en_byte_counter
  -- Outputs are selected via muxes to make state machine cleaner and more compact.

  -- reset receiver when reset is high or if transmitting
  rx_reset <= '1' when (reset = '1' or
                        state = TX_LOAD or state = TX_SEND or 
                        state = TX_WAIT or state = TX_INC_BYTE or 
                        state = TXD_BYTE or state = TX_DONE) else '0';

  load_tx_reg <= '1' when (state = TX_LOAD) else '0';
  tx_send_sig <= '1' when (state = TX_SEND) else '0';

  load_data_reg <= '1' when (state = PROC_DONE) else '0';
  shift_data_reg <= '1' when (state = RX_INC_BYTE or state = TX_INC_BYTE) else '0';

  clr_byte_counter <= '1' when (state = PROC_START or state = PROC_WAIT or state = PROC_DONE) else '0';
  en_byte_counter <= '1' when (state = RX_INC_BYTE or state = TX_INC_BYTE) else '0';

  start_processing <= '1' when (state = PROC_START or state = PROC_WAIT) else '0';
  
  process (state) begin
    case state is
      when IDLE =>
        if (rx_active = '1') then
          next_state <= RX_WAIT;
        else -- input = '1'
          next_state <= IDLE;
        end if;
        -- byte counter disabled but NOT reset
      when RX_WAIT =>
        if (rx_done_sig = '1') then
          next_state <= RX_INC_BYTE;
        else
          next_state <= RX_WAIT;
        end if;      
      when RX_INC_BYTE =>
        next_state <= RXD_BYTE;
        -- shift data reg and enable byte counter
      when RXD_BYTE =>
        if (byte_counter = bytes) then 
          next_state <= RX_DONE;
        else
          next_state <= IDLE;
        end if;
        -- stop shifting and disable byte counter
      when RX_DONE =>
        -- wait for synchronization at the end
        if (rx_idle = '1') then
          next_state <= PROC_START;
        else
          next_state <= RX_DONE;
        end if;
      when PROC_START =>
        next_state <= PROC_START;
      when PROC_WAIT =>
        -- if (done_processing = '1') then 
        --   next_state <= PROC_DONE;
        -- else
        --   next_state <= PROC_WAIT;
        -- end if;
        next_state <= PROC_DONE;
        data_reg_processed <= not data_reg;
      when PROC_DONE =>
        next_state <= TX_LOAD;
      when TX_LOAD =>
        next_state <= TX_SEND;
      when TX_SEND =>
        next_state <= TX_WAIT;
      when TX_WAIT =>
        if (tx_ready = '1') then
          next_state <= TX_INC_BYTE;
        else
          next_state <= TX_WAIT;
        end if;
      when TX_INC_BYTE =>
        next_state <= TXD_BYTE;
      when TXD_BYTE =>
        if (byte_counter = bytes) then
            next_state <= TX_DONE;
        else
          next_state <= TX_LOAD;
        end if;
      when TX_DONE =>
        if (reset = '1') then
          next_state <= IDLE;
        else
          next_state <= TX_DONE;
        end if;
    end case;  
  end process;
end architecture behavioral;