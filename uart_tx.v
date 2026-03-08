module uart_tx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] tx_data,
    input  wire       tx_start,
    input  wire       tick_16x,
    input  wire [1:0] parity_mode, // 00=none, 01=even, 10=odd
    output reg        tx,
    output reg        tx_busy
);

    localparam IDLE   = 0;
    localparam START  = 1;
    localparam DATA   = 2;
    localparam PARITY = 3;
    localparam STOP   = 4;

    reg [2:0] current_st, next_st;
    reg [7:0] tx_shift;
    reg [3:0] clk_div;   // counts 0-15 per bit
    reg [2:0] bit_idx;   
    
    // figure out parity needed
    wire is_even = ^tx_shift;
    wire is_odd  = ~is_even;
    wire p_bit   = (parity_mode == 2'b01) ? is_even :
                   (parity_mode == 2'b10) ? is_odd : 1'b0;

    // Tick counter to divide 16x tick to 1x baud interval
    wire tick_1x = tick_16x && (tick_cnt == 4'd15);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_st <= IDLE;
            clk_div <= 0;
            bit_idx  <= 0;
            tx_shift <= 0;
            tx       <= 1'b1; // line idles high
            tx_busy  <= 0;
        end else begin
            case (current_st)
                IDLE: begin
                    tx <= 1'b1;
                    tx_busy <= 0;
                    clk_div <= 0;
                    bit_idx <= 0;
                    
                    if (tx_start) begin
                        tx_shift <= tx_data;
                        current_st <= START;
                        tx_busy <= 1'b1;
                    end
                end

                START: begin
                    tx <= 0; // drop line
                    if (tick_16x) begin
                        clk_div <= clk_div + 1;
                        if (clk_div == 15) current_st <= DATA;
                    end
                end

                DATA: begin
                    tx <= tx_shift[bit_idx];
                    if (tick_16x) begin
                        clk_div <= clk_div + 1;
                        if (clk_div == 15) begin
                            if (bit_idx == 7) begin
                                current_st <= (parity_mode != 0) ? PARITY : STOP;
                            end else begin
                                bit_idx <= bit_idx + 1;
                            end
                        end
                    end
                end

                PARITY: begin
                    tx <= p_bit;
                    if (tick_16x) begin
                        clk_div <= clk_div + 1;
                        if (clk_div == 15) current_st <= STOP;
                    end
                end

                STOP: begin
                    tx <= 1'b1;
                    if (tick_16x) begin
                        clk_div <= clk_div + 1;
                        if (clk_div == 15) begin
                            current_st <= IDLE;
                            tx_busy <= 0; // done
                        end
                    end
                end
                
                default: current_st <= IDLE;
            endcase
        end
    end

endmodule
