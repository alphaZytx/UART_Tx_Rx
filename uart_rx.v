module uart_rx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    input  wire       tick_16x,
    input  wire [1:0] parity_mode, // 00=none, 01=even, 10=odd
    
    output reg [7:0]  rx_data,
    output reg        rx_done,
    output reg        rx_error
);

    // rx sync chain
    reg sync1, sync2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync1 <= 1;
            sync2 <= 1;
        end else begin
            sync1 <= rx;
            sync2 <= sync1;
        end
    end

    localparam IDLE    = 0;
    localparam WAIT_ST = 1;
    localparam DATA    = 2;
    localparam PARITY  = 3;
    localparam STOP    = 4;

    reg [2:0] st;
    reg [3:0] clk_div;
    reg [2:0] bit_idx;
    reg [7:0] rx_shift;
    
    // parity stuff
    reg p_rx;
    reg p_err;
    reg p_expected;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= IDLE;
            clk_div <= 0;
            bit_idx <= 0;
            rx_shift <= 0;
            rx_done <= 0;
            rx_error <= 0;
            rx_data <= 0;
            p_rx <= 0;
        end else begin
            rx_done <= 0; // pulse

            case (st)
                IDLE: begin
                    clk_div <= 0;
                    bit_idx <= 0;
                    rx_error <= 0;
                    
                    if (sync2 == 0) st <= WAIT_ST; // caught an edge
                end

                WAIT_ST: begin
                    if (tick_16x) begin
                        clk_div <= clk_div + 1;
                        if (clk_div == 7) begin // check middle of start bit
                            if (sync2 == 0) begin
                                clk_div <= 0;
                                st <= DATA;
                            end else begin
                                st <= IDLE; // false alarm
                            end
                        end
                    end
                end

                DATA: begin
                    if (tick_16x) begin
                        clk_div <= clk_div + 1;
                        if (clk_div == 15) begin
                            rx_shift[bit_idx] <= sync2;
                            if (bit_idx == 7) begin
                                st <= (parity_mode != 0) ? PARITY : STOP;
                            end else begin
                                bit_idx <= bit_idx + 1;
                            end
                        end
                    end
                end

                PARITY: begin
                    if (tick_16x) begin
                        clk_div <= clk_div + 1;
                        if (clk_div == 15) begin
                            p_rx <= sync2;
                            st   <= STOP;
                        end
                    end
                end

                STOP: begin
                    if (tick_16x) begin
                        clk_div <= clk_div + 1;
                        if (clk_div == 15) begin
                            if (sync2 == 1) begin // proper stop bit
                                if (parity_mode != 0) begin
                                    p_expected = (parity_mode == 1) ? (^rx_shift) : ~(^rx_shift);
                                    p_err = (p_rx != p_expected);
                                end else begin
                                    p_err = 0;
                                end
                                rx_error <= p_err;
                            end else begin
                                rx_error <= 1; // frame error
                            end
                            
                            rx_data <= rx_shift;
                            rx_done <= 1;
                            st <= IDLE;
                        end
                    end
                end
                
                default: st <= IDLE;
            endcase
        end
    end

endmodule
