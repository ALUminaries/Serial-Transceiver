# VHDL Serial Transceiver
This repository contains resources for implementing a serial transceiver (combined transmitter and receiver) for an FPGA using an emulated RS-232 interface over USB.

The transceiver first listens for incoming serial traffic, and waits until a certain number of bytes have been successfully received. Then, the processing stage begins. This is where a high-precision algorithm may be placed. Once a done flag has been received from the processing hardware, the result is transmitted back to the host.

Files required for the serial transceiver to work:
- Receiver Module (rx_module.vhd)
- Transmitter Module (tx_module.vhd)
- Top Level Transceiver File (xcvr_####b.vhd)
- Constraint File (xcvr_nB.vhd)
    - Note that the provided constraint file is for a Digilent Basys 3 (Artix-7 based) FPGA. Customize or replace this as necessary for your device.
- Any files required by the hardware used for the processing stage

Two example generator programs are provided. These can be modified to use virtually any algorithm or hardware design in the processing stage.
- 2LMR-XCVR-Generator generates a top level component designed to work with our [Two Level Multiplier](https://www.github.com/ALUminaries/Two-Level-Multiplier).
- Invert-XCVR-Generator generates a top level component with a processing stage that inverts the input before sending it back.