module top (
    input wire clk,
    input wire ser_rx,
    output wire ser_tx,
    output wire [5:0] led
);
    wire cpu_clk, pll_lock;
    // 27 / (1+1) * (0+1) = 13.5 MHz; VCO = 13.5 * 32 = 432 MHz.
    rPLL #(.FCLKIN("27"), .IDIV_SEL(1), .FBDIV_SEL(0), .ODIV_SEL(32),
           .DEVICE("GW1NR-9C")) clock_pll (
        .CLKIN(clk), .CLKOUT(cpu_clk), .LOCK(pll_lock),
        .CLKOUTP(), .CLKOUTD(), .CLKOUTD3(),
        .RESET(1'b0), .RESET_P(1'b0), .CLKFB(1'b0),
        .FBDSEL(6'b0), .IDSEL(6'b0), .ODSEL(6'b0),
        .PSDA(4'b0), .DUTYDA(4'b0), .FDLY(4'b0)
    );
    reg [1:0] lock_sync = 0;
    reg [15:0] startup = 0;
    wire resetn = (&startup) && lock_sync[1];
    wire trap;
    wire [5:0] gpio;
    always @(posedge cpu_clk) begin
        lock_sync <= {lock_sync[0], pll_lock};
        if (!lock_sync[1]) startup <= 0;
        else if (!resetn) startup <= startup + 1'b1;
    end
    pico_uart_soc soc (
        .clk(cpu_clk), .resetn(resetn), .ser_rx(ser_rx), .ser_tx(ser_tx),
        .gpio(gpio), .trap(trap)
    );
    assign led = trap ? 6'b000000 : ~gpio;
endmodule
