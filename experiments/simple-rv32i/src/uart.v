module uart #(parameter DIV = 117) (
    input wire clk, reset, rx,
    output wire tx,
    input wire tx_start,
    input wire [7:0] tx_data,
    output wire tx_busy,
    input wire rx_take,
    output reg [7:0] rx_data,
    output reg rx_valid,
    output reg rx_overrun
);
    reg [9:0] tx_shift;
    reg [3:0] tx_left;
    reg [15:0] tx_timer;
    assign tx_busy = tx_left != 0;
    assign tx = tx_busy ? tx_shift[0] : 1'b1;
    reg [1:0] rx_sync;
    reg rx_running;
    reg [3:0] rx_bit;
    reg [15:0] rx_timer;
    reg [7:0] rx_shift;
    always @(posedge clk) begin
        if (reset) begin
            tx_shift <= 10'h3ff; tx_left <= 0; tx_timer <= 0;
            rx_sync <= 3; rx_running <= 0; rx_bit <= 0; rx_timer <= 0;
            rx_shift <= 0; rx_data <= 0; rx_valid <= 0; rx_overrun <= 0;
        end else begin
            rx_sync <= {rx_sync[0], rx};
            if (tx_start && !tx_busy) begin
                tx_shift <= {1'b1, tx_data, 1'b0};
                tx_left <= 10; tx_timer <= DIV - 1;
            end else if (tx_busy) begin
                if (tx_timer != 0) tx_timer <= tx_timer - 1;
                else begin
                    tx_timer <= DIV - 1; tx_left <= tx_left - 1;
                    tx_shift <= {1'b1, tx_shift[9:1]};
                end
            end
            if (rx_take) rx_valid <= 0;
            if (!rx_running) begin
                if (!rx_sync[1]) begin
                    rx_running <= 1; rx_bit <= 0; rx_timer <= DIV/2 - 1;
                end
            end else if (rx_timer != 0) rx_timer <= rx_timer - 1;
            else begin
                rx_timer <= DIV - 1;
                if (rx_bit == 0) begin
                    if (rx_sync[1]) rx_running <= 0;
                    else rx_bit <= 1;
                end else if (rx_bit <= 8) begin
                    rx_shift[rx_bit-1] <= rx_sync[1]; rx_bit <= rx_bit + 1;
                end else begin
                    rx_running <= 0;
                    if (rx_sync[1]) begin
                        if (rx_valid && !rx_take) rx_overrun <= 1;
                        rx_data <= rx_shift; rx_valid <= 1;
                    end
                end
            end
        end
    end
endmodule
