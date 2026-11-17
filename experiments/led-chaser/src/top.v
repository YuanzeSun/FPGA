// Tang Nano 9K: 27 MHz clock, six active-low user LEDs.
// One LED is lit at a time; advance every 0.5 seconds by default.
module top #(
    parameter integer STEP_CYCLES = 13_500_000
) (
    input wire clk,
    output wire [5:0] led
);
    localparam integer COUNTER_WIDTH = (STEP_CYCLES < 2) ? 1 : $clog2(STEP_CYCLES);
    localparam [COUNTER_WIDTH-1:0] LAST_COUNT = STEP_CYCLES - 1;
    reg [COUNTER_WIDTH-1:0] counter = 0;
    reg [5:0] lit = 6'b000001;

    always @(posedge clk) begin
        if (counter == LAST_COUNT) begin
            counter <= 0;
            lit <= {lit[4:0], lit[5]};
        end else begin
            counter <= counter + 1'b1;
        end
    end

    assign led = ~lit;
endmodule
