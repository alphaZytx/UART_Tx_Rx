# UART Transceiver (Verilog)

Finally got this full-duplex UART working after spending way too long debugging ModelSim timing issues. Wrote this from scratch in Verilog. It supports standard baud rates (9600 to 115200) and handles parity (none, even, odd).

The main headache I had was making the receiver robust. I ended up implementing a standard 16x oversampler and a 2-FF synchronizer on the RX line to handle metastability and noisy edges. It samples right at the middle of the bit (tick 7/15) which helps avoid glitches.

### Modules
* `baud_gen.v` - Generates the 16x tick based on whatever CLK_FREQ / BAUD_RATE you pass in as parameters. 
* `uart_tx.v` - Moore FSM for shifting out the bits. Straightforward implementation.
* `uart_rx.v` - The receiver FSM. Took a few iterations to get the parity checking perfectly synced with the stop bit sampling without throwing frame errors.
* `uart_top.v` - Wraps everything up into a clean interface.
* `uart_tb.v` & `tb_uart.py` - The testing setup. 

### Simulation & Testing
Originally I tried driving ModelSim directly using TCL `force` commands from a Python testing script to validate the state machines. Do not do this. It took literally 30+ minutes to run just 10k packets because of the massive TCL evaluation overhead in Questa/ModelSim. 

I ended up scrapping that and rewriting the testbench so Python generates `.txt` files with binary payloads, and `uart_tb.v` just reads them natively using `$fscanf`. The simulation time dropped from 30 minutes to like 3 seconds. Huge lesson learned.

To run the automated tests yourself (it covers 10,800 packets across all baud/parity combos):
```bash
python tb_uart.py
```
*(Make sure `vsim` is in your environment PATH)*

The script checks everything against a golden Python model and spits out the Bit Error Rate (BER) at the end. Right now it's thankfully hitting 0.00 BER across all 86k bits tested.

### Viewing Waves in GTKWave
The Verilog testbench automatically dumps a `uart_waves.vcd` file when it finishes. If you want to see the FSM transitions or how the 16x tick aligns with the start bit, you can open it in GTKWave.

If you're on Windows doing this through WSL like I am:
```bash
# navigate to wherever your windows drive is mounted
cd /mnt/d/RAHUL/UART
gtkwave uart_waves.vcd
```
*(Note for WSL: WSLg handles the GUI automatically on Win11, but on Win10 you might need to run VcXsrv/Xming first)*
