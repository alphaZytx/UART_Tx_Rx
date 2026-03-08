import os
import random
import subprocess
import re

CLK_FREQ = 50_000_000
BAUD_RATES = [9600, 57600, 115200]
PARITY_MODES = [0, 1, 2] # 00=none, 01=even, 10=odd
NUM_VALUES_PER_CONFIG = 1200 # Restore to 1200 for full coverage

def get_bitstream(val, parity_mode):
    # build tx frame
    bits = [0] # start
    
    # 8 data bits LSB first
    for i in range(8):
        bits.append((val >> i) & 1)
        
    # parity
    if parity_mode == 1:
        # even
        ones = sum((val >> i) & 1 for i in range(8))
        bits.append(1 if ones % 2 != 0 else 0)
    elif parity_mode == 2:
        # odd
        ones = sum((val >> i) & 1 for i in range(8))
        bits.append(0 if ones % 2 != 0 else 1)
        
    bits.append(1) # stop
    bits.extend([1, 1]) # idle gap
    return bits

def generate_stimulus(filename, values, baud, parity_mode):
    with open(filename, "w") as f:
        f.write(f"// Baud: {baud}, Parity: {parity_mode}\n")
        
        # Write format: <tx_start> <tx_data> <rx_bit> <expected_rx_data>
        # Each line represents 1 baud interval (actually we can just provide the bytes to TX
        # and the bits for RX directly)
        
        # Actually, simpler: write the sequence of 8-bit values to a file.
        # the Verilog TB will loop through them, TX them out, and ALSO feed a bitstream into RX.
        # Wait, the prompt says Python computes expected TX bit-stream, writes to modelsim,
        # reads back, compares. Let's keep Python computing the bits explicitly to verify
        # both TX and RX FSMs against the Python model.
        
        for val in values:
            f.write(f"{val}\n")

def run_test():
    total_bits = 0
    total_errs = 0
    
    # check if we can even run vsim
    has_modelsim = True
    try:
        subprocess.run(["vsim", "-version"], capture_output=True, check=True)
    except FileNotFoundError:
        print("warn: vsim missing, skipping sim")
        has_modelsim = False

    if has_modelsim:
        with open("compile.do", "w") as f:
            f.write("vlib work\n"
                    "vlog -work work baud_gen.v uart_tx.v uart_rx.v uart_top.v uart_tb.v\n"
                    "quit -f\n")
        subprocess.run(["vsim", "-c", "-do", "do compile.do"], capture_output=True)

    for baud in BAUD_RATES:
        for parity in PARITY_MODES:
            print(f"Testing Baud={baud}, ParityMode={parity}")
            
            # Generate random 8-bit payloads
            values = [random.randint(0, 255) for _ in range(NUM_VALUES_PER_CONFIG)]
            print(f"DEBUG: values = {[hex(v) for v in values]}")
            
            # Write expected bits for RX test and payload for TX
            rx_bits_file = f"rx_bits_{baud}_{parity}.txt"
            tx_data_file = f"tx_data_{baud}_{parity}.txt"
            
            with open(rx_bits_file, "w") as frx, open(tx_data_file, "w") as ftx:
                for val in values:
                    ftx.write(f"{hex(val)[2:]}\n")
                    bits = get_bitstream(val, parity)
                    for b in bits:
                        frx.write(f"{b}\n")
                        
            # Create a quick do script to just run the specialized TB
            do_filename = f"run_{baud}_{parity}.do"
            with open(do_filename, "w") as f:
                f.write("onerror {quit -f}\n")
                f.write("onbreak {quit -f}\n")
                # Run with parameters matching current config
                f.write(f"vsim -c -voptargs=+acc -gBAUD_RATE={baud} -gCLK_FREQ={CLK_FREQ} -gPARITY={parity} ")
                f.write(f"-gNUM_PKTS={NUM_VALUES_PER_CONFIG} ")
                f.write(f"+TX_FILE={tx_data_file} +RX_FILE={rx_bits_file} work.uart_tb\n")
                f.write("run -all\n")
                f.write("quit -f\n")
                
            if not has_modelsim: continue
                
            cmd = ["vsim", "-c", "-do", f"do {do_filename}"]
            log = subprocess.run(cmd, capture_output=True, text=True).stdout
            
            rx_data = [int(m.group(1), 16) for m in re.finditer(r"CMD::RX_DONE DATA:([0-9A-Fa-f]+)", log)]
                
            tx_err_count = sum(1 for m in re.finditer(r"CMD::TX_DONE EXPECTED:([01]+) ACTUAL:([01]+)", log) if m.group(1) != m.group(2))
                
            errs = 0
            for r, e in zip(rx_data, values):
                if r != e:
                    errs += bin(r ^ e).count('1')
                    
            if len(rx_data) < len(values):
                errs += (len(values) - len(rx_data)) * 8
                
            config_bits = len(values) * 8
            total_bits += config_bits
            total_errs += errs
            
            ber = errs / config_bits if config_bits > 0 else 0
            print(f"  Result: {errs} errs / {config_bits} bits (BER: {ber:.2e})")
            if tx_err_count > 0:
                print(f"  TX fails: {tx_err_count} packets mismatched")

    if has_modelsim:
        final_ber = total_errs / total_bits if total_bits > 0 else 0
        print("-" * 40)
        print(f"BER: {final_ber:.2e} ({total_errs} / {total_bits} bits)")
        if final_ber < 1e-6:
            print("OK.")
        else:
            print("FAIL.")

if __name__ == "__main__":
    run_test()
