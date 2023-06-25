# VHDL Serial Transceiver
This repository contains resources for implementing a serial transceiver (combined transmitter and receiver) for an FPGA using an emulated RS-232 interface over USB.

The transceiver first listens for incoming serial traffic, and waits until a certain number of bytes have been successfully received. Then, the processing stage begins. This is where a high-precision algorithm may be placed. Once a done flag has been received from the processing hardware, the result is transmitted back to the host.

### Files
Files required for the serial transceiver to work:
- Receiver Module (`mk7_rx_module.vhd`)
- Transmitter Module (`mk7_tx_module.vhd`)
- Top Level Transceiver File (`mk7_xcvr_####b.vhd`)
- Constraint File (`basys3_mk7_xcvr.xdc` or `nexys_mk7_xcvr.xdc`)
    - The provided constraint files are for either a Digilent Basys 3 (Artix-7 based) FPGA, or a Digilent Nexys A7-100T. Customize or replace this as necessary for your device.
- Hardware Container File (ex. `mk7_container_template.vhd`)
- Any files required by the hardware used for the processing stage

#### Adding your Hardware
This transceiver is designed to be generic, modular, compartmentalized, and easy to work with. You can add virtually any algorithm or hardware design into the processing stage by working with the provided hardware container template, `mk7_container_template.vhd`. The container provides a layer of abstraction from the transceiver, and has several ports to interface with the top-level transceiver. Essentially, the transceiver passes a parallel input in once received serially, and takes a parallel output to transmit back. It also provides access to buttons, dip switches, and LEDs for the aforementioned FPGA development boards. The file is well documented and contains usage examples. You can also see a discrete example in our [Two Level Multiplier](https://www.github.com/ALUminaries/Two-Level-Multiplier).

#### Modifying for Different Bit Precisions
The following files require no modification for any given size of transceiver:
- Receiver Module (`mk7_rx_module.vhd`)
- Transmitter Module (`mk7_tx_module.vhd`)
- Constraint File (`basys3_mk7_xcvr.xdc` or `nexys_mk7_xcvr.xdc`)

The top-level transceiver file must be modified slightly for each bit count. This can be done manually by changing the generics declared in the `entity` of `mk7_xcvr_####b.vhd`, or automatically by modifying the bit count in the provided generator script (`/Mk7-XCVR-Generator`).