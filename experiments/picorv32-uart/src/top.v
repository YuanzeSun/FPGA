module top (
    input wire clk,
    input wire ser_rx,
    output wire ser_tx,
    output wire [5:0] led
);
    reg [15:0] startup = 0;
    wire resetn = &startup;
    wire trap;
    wire [5:0] gpio;
    always @(posedge clk)
        if (!resetn) startup <= startup + 1'b1;

    pico_uart_soc soc (
        .clk(clk), .resetn(resetn), .ser_rx(ser_rx), .ser_tx(ser_tx),
        .gpio(gpio), .trap(trap)
    );
    assign led = trap ? 6'b000000 : ~gpio;
endmodule
