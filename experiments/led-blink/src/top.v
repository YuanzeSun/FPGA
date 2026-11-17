// Tang Nano 9K: 27 MHz clock, active-low LEDs.
// LED0: 0.5 seconds on, 0.5 seconds off. LED1..LED5: off.
module top (
    input wire clk,
    output wire [5:0] led
);
    localparam [23:0] HALF_PERIOD_MINUS_ONE = 24'd13_499_999;
    reg [23:0] counter = 24'd0;
    reg led_on = 1'b0;

    always @(posedge clk) begin
        if (counter == HALF_PERIOD_MINUS_ONE) begin
            counter <= 24'd0;
            led_on <= ~led_on;
        end else begin
            counter <= counter + 1'b1;
        end
    end

    assign led[0] = ~led_on;
    assign led[5:1] = 5'b11111;
endmodule
