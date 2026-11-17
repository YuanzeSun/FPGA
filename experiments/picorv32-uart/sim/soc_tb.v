`timescale 1ns/1ps
module soc_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg resetn = 0;
    reg rx = 1;
    wire tx, trap;
    wire [5:0] gpio;
    localparam integer BIT_CYCLES = 234;
    pico_uart_soc #(.TIMER_INCREMENT(1000)) dut (
        .clk(clk), .resetn(resetn), .ser_rx(rx), .ser_tx(tx), .gpio(gpio), .trap(trap)
    );
    integer tick_lines = 0;
    reg boot_seen = 0, pong_seen = 0, gpio_seen = 0;
    string line = "";
    reg [7:0] character;
    integer bit_index;

    initial begin
        repeat (20) @(posedge clk);
        @(negedge clk) resetn = 1;
    end
    always @(posedge clk)
        if (resetn && trap === 1'b1) $fatal(1, "CPU trapped");

    initial forever begin
        @(negedge tx);
        repeat (BIT_CYCLES + BIT_CYCLES/2) @(posedge clk);
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            character[bit_index] = tx;
            if (bit_index != 7) repeat (BIT_CYCLES) @(posedge clk);
        end
        repeat (BIT_CYCLES) @(posedge clk);
        if (tx !== 1'b1) $fatal(1, "UART stop-bit error");
        if (character == 10) begin
            $display("UART: %s", line);
            if (line == "PicoRV32 C firmware ready") boot_seen = 1;
            if (line == "PONG") pong_seen = 1;
            if (line == "GPIO=00000008") gpio_seen = 1;
            if (line.len() >= 5 && line.substr(0,4) == "TICK=") tick_lines = tick_lines + 1;
            line = "";
        end else if (character != 13) begin
            line = {line, character};
        end
    end

    task send_character(input [7:0] value);
        integer i;
        begin
            @(negedge clk) rx = 0;
            repeat (BIT_CYCLES) @(negedge clk);
            for (i = 0; i < 8; i = i + 1) begin
                rx = value[i];
                repeat (BIT_CYCLES) @(negedge clk);
            end
            rx = 1;
            repeat (BIT_CYCLES) @(negedge clk);
        end
    endtask

    initial begin
        wait (boot_seen);
        send_character("p");
        wait (pong_seen);
        send_character("3");
        wait (gpio_seen);
        wait (tick_lines >= 3);
        $display("TEST PASS: compiled RV32I firmware boots, responds PONG, updates GPIO, and emits three ticks");
        $finish;
    end
    initial begin
        repeat (4000000) @(posedge clk);
        $fatal(1, "Simulation timed out");
    end
endmodule
