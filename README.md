# VHDL Serial Transceiver
This repository contains resources for implementing a serial transceiver (combined transmitter and receiver) for an FPGA using an emulated RS-232 interface over USB. It includes a customizable hardware container designed to allow insertion of any given hardware or algorithm into the serial pipeline.

### Outline of Functionality
1. Receiver module listens for incoming serial traffic
2. Transceiver controls receiver module until a certain number of bytes are received
3. Processing stage begins, activating hardware inside customizable container
4. Done flag received from hardware container
5. Transceiver controls transmitter module to transmit result back to host

### Files
Files required for the serial transceiver and hardware container:
- Top Level Linking Module (`mk8_apex_####.vhd`)
- Customizable Hardware Container File (ex. `mk8_container_template.vhd`)
  - Any files required by your custom hardware
- Transceiver File (`mk8_xcvr_generic.vhd`)
- Receiver Module (`mk8_rx_module.vhd`)
- Transmitter Module (`mk8_tx_module.vhd`)
- CDC Synchronizer (`synchronizer_2ff.vhd`)
- D Flip-Flop (`d_flip_flop.vhd`)
- Constraint File (`basys3_mk8_apex.xdc` or `nexys_mk7_apex.xdc`)
    - The provided constraint files are for either a Digilent Basys 3 (Artix-7 based) FPGA, or a Digilent Nexys A7-100T. Customize or replace this as necessary for your device.

#### Structural Block Diagram
Below is a simplified outline of the structure of the top-level module and submodules:

![structure.png](https://github.com/ALUminaries/Serial-Transceiver/blob/main/Apex%20Block%20Diagram.png)

#### Adding your Hardware
This transceiver is designed to be generic, modular, compartmentalized, and easy to work with. You can add virtually any algorithm or hardware design into the processing stage by working with the provided hardware container template, `mk8_container_template.vhd`. The container provides a layer of abstraction from the transceiver, and has several ports to interface with the top-level component. Essentially, the transceiver passes a parallel input to the hardware once received serially, and takes a parallel output to transmit back. The top-level component facilitates this and provides access to buttons, dip switches, and LEDs for the aforementioned FPGA development boards. These files are documented enough that you should be able to easily customize the hardware container to your needs. You can also see a discrete example in our [Two Level Multiplier](https://www.github.com/ALUminaries/Two-Level-Multiplier) or [Two Level Divider](https://github.com/ALUminaries/Two-Level-Divider).

#### Modifying for Different Bit Precisions
The following files require no modification for any given size of transceiver:
- Receiver Module (`mk8_rx_module.vhd`)
- Transmitter Module (`mk8_tx_module.vhd`)
- Transceiver File (`mk8_xcvr_generic.vhd`)
- Constraint File (`basys3_mk8_xcvr.xdc` or `nexys_mk8_xcvr.xdc`)

The top-level linking component must be modified slightly for each bit count. Inside `mk8_apex_####.vhd`, simply change `G_total_bits` to your desired precision. It is recommended to also change the filename to reflect the precision (ex. `mk8_apex_2048.vhd`).

#### Using the MMCM
The top-level component instantiates a Xilinx LogiCORE Clock Wizard 6.0 IP (MMCM/PLL). The Clock Wizard is available with Xilinx Vivado Design Suite. This IP core is useful for determining minimum delay on your hardware. In order to use this feature, you will need to add it to your Vivado project as follows. Breaking from the naming conventions established below will require manual modifications to `mk8_apex_####.vhd`.

- Flow Navigator → Project Manager → IP Catalog
- Search for "Clocking Wizard" (alternatively browse to Vivado Repository/FPGA Features and Design/Clocking)
- Name the IP `clk_wiz_0`
- Specify the clock input name and frequency:
  - `clk_in1` at your development board frequency (we use 100 MHz).
- (Important) Under "Input Clock Information", scroll right, and change "Source" from "Single ended clock capable pin" to "Global buffer".
  - Your design will almost certainly fail timing if you do not do this, since the input `clk` pin drives more than just the MMCM.
- Specify the following output clocks:
  - `clk_100mhz` @ `100.000` MHz (or matching your source clock frequency)
    - This output clock is not used by default in the top-level component, but can be useful if the design fails timing because of the offset of `clk_hw` or similar issues.
  - `clk_hw` at your desired frequency for your hardware.
    - The maximum frequency should be displayed on the right of the output clock table (scroll all the way to the right).
  - If not already enabled, enable the `reset` and `locked` ports for the MMCM, and ensure the reset is active high.

### Using the Transceiver to Test Hardware
The primary purpose of this transceiver is to compensate for FPGA IO constraints when testing high-precision hardware (anything above 32 bits quickly becomes problematic). On either of the two aforementioned boards (among others), the Micro-USB JTAG port can also be used to emulate a serial RS-232 protocol. Then, a terminal software such as [Realterm](https://sourceforge.net/projects/realterm/) can be used to send and receive data to verify hardware results.
