`timescale 1ns/1ps

module uart_tb;

    parameter CLK_FREQ  = 50_000_000;
    parameter BAUD_RATE = 9600;
    parameter PARITY    = 0;
    parameter NUM_PKTS  = 1200;

    reg clk;
    reg rst_n;
    
    reg [7:0] tx_data;
    reg tx_start;
    wire tx;
    wire tx_busy;
    
    reg rx;
    wire [7:0] rx_data;
    wire rx_done;
    wire rx_error;
    
    wire [1:0] parity_mode = PARITY;

    uart_top #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .tx(tx),
        .tx_busy(tx_busy),
        .rx(rx),
        .rx_data(rx_data),
        .rx_done(rx_done),
        .rx_error(rx_error),
        .parity_mode(parity_mode)
    );

    // 50 MHz clock
    always #10 clk = ~clk;

    // Bit period
    localparam real BIT_PERIOD_NS = 1_000_000_000.0 / BAUD_RATE;

    integer tx_fd, rx_fd;
    reg [255:0] tx_file;
    reg [255:0] rx_file;
    integer i, j;
    reg [7:0] temp_rx_val;
    reg temp_rx_bit;
    
    reg [12:0] expected_tx_stream; // start(1) + data(8) + parity(1) + stop(1) + margin(2)
    reg [12:0] actual_tx_stream;

    initial begin
        $dumpfile("uart_waves.vcd");
        $dumpvars(0, uart_tb);
        clk = 0;
        rst_n = 0;
        tx_data = 0;
        tx_start = 0;
        rx = 1;
        
        if (!$value$plusargs("TX_FILE=%s", tx_file)) tx_file = "tx_data.txt";
        if (!$value$plusargs("RX_FILE=%s", rx_file)) rx_file = "rx_bits.txt";
        
        tx_fd = $fopen(tx_file, "r");
        rx_fd = $fopen(rx_file, "r");

        #100;
        rst_n = 1;
        #100;
        
        // Parallel block for driving RX and checking TX
        fork
            // Thread A: Drive RX bits
            begin
                while (!$feof(rx_fd)) begin
                    if ($fscanf(rx_fd, "%b", temp_rx_bit) == 1) begin
                        rx = temp_rx_bit;
                        #(BIT_PERIOD_NS);
                    end
                end
            end
            
            // Thread B: Drive TX data and capture output
            begin
                for (i=0; i<NUM_PKTS; i=i+1) begin
                    if ($fscanf(tx_fd, "%h", temp_rx_val) == 1) begin
                        @(posedge clk);
                        wait(!tx_busy);
                        tx_data = temp_rx_val;
                        tx_start = 1;
                        @(posedge clk);
                        tx_start = 0;
                        
                        // Wait for simulation to shift out bits
                        // In parallel, python compares what actually came out on the tx wire
                    end
                end
                // Wait for last packet to complete and RX to catch up
                wait(!tx_busy);
                #(BIT_PERIOD_NS * 50); // wait ~50 bit periods to let RX drain securely
                $finish;
            end
        join

        $fclose(tx_fd);
        $fclose(rx_fd);
    end

    // Monitor RX output
    always @(posedge clk) begin
        if (rx_done) begin
            $display("CMD::RX_DONE DATA:%02X ERROR:%b TIME:%0t", rx_data, rx_error, $time);
        end
    end

endmodule
