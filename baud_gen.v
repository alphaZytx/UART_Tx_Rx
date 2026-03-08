module baud_gen #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9600
)(
    input  wire clk,
    input  wire rst_n,
    output reg  baud_tick_16x
);

    // 16x oversampling ratio
    localparam integer MAX_COUNT = CLK_FREQ / (BAUD_RATE * 16);
    
    // Calculate required width for the counter
    localparam COUNTER_WIDTH = $clog2(MAX_COUNT);
    
    reg [COUNTER_WIDTH-1:0] count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 0;
            baud_tick_16x <= 1'b0;
        end else begin
            if (count == MAX_COUNT - 1) begin
                count <= 0;
                baud_tick_16x <= 1'b1;
            end else begin
                count <= count + 1'b1;
                baud_tick_16x <= 1'b0;
            end
        end
    end

endmodule
