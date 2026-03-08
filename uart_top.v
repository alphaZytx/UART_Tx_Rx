module uart_top #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9600
)(
    input  wire       clk,
    input  wire       rst_n,
    
    // TX side
    input  wire [7:0] tx_data,
    input  wire       tx_start,
    output wire       tx,
    output wire       tx_busy,
    
    // RX side
    input  wire       rx,
    output wire [7:0] rx_data,
    output wire       rx_done,
    output wire       rx_error,
    
    // Parity config
    input  wire [1:0] parity_mode // 00=none, 01=even, 10=odd
);

    wire tick_16x;

    baud_gen #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) i_baud_gen (
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick_16x(tick_16x)
    );

    uart_tx i_uart_tx (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .tick_16x(tick_16x),
        .parity_mode(parity_mode),
        .tx(tx),
        .tx_busy(tx_busy)
    );

    uart_rx i_uart_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .tick_16x(tick_16x),
        .parity_mode(parity_mode),
        .rx_data(rx_data),
        .rx_done(rx_done),
        .rx_error(rx_error)
    );

endmodule
