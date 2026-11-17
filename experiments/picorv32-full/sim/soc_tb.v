`timescale 1ns/1ps
module soc_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg resetn = 0, rx = 1;
    wire tx, trap;
    wire [5:0] gpio;
    localparam integer BIT_CYCLES = 117;
    pico_uart_soc #(.IRQ_RELOAD(135000)) dut (
        .clk(clk), .resetn(resetn), .ser_rx(rx), .ser_tx(tx), .gpio(gpio), .trap(trap)
    );
    integer tick_lines = 0, pcpi_operations = 0, trace_events = 0;
    reg boot_seen = 0, pong_seen = 0, m_seen = 0, soft_seen = 0, status_seen = 0, gpio_seen = 0;
    string line = "";
    reg [7:0] character;
    integer bit_index;
    initial begin
        repeat (20) @(posedge clk);
        @(negedge clk) resetn = 1;
    end
    always @(posedge clk) begin
        if (resetn && trap === 1'b1) $fatal(1, "CPU trapped");
        if (resetn && dut.pcpi_ready) pcpi_operations = pcpi_operations + 1;
        if (resetn && dut.trace_valid) trace_events = trace_events + 1;
        if (resetn && dut.request && dut.mem_wstrb != 0 && !dut.ram_selected && dut.mem_addr < 32'h02000000)
            $fatal(1, "Unexpected write below peripheral range: %h", dut.mem_addr);
    end
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
            if (line == "RV32IMC selftest=000000FF") boot_seen = 1;
            if (line == "PONG") pong_seen = 1;
            if (line == "M=PASS") m_seen = 1;
            if (line == "SOFTIRQ=00000002") soft_seen = 1;
            if (line == "GPIO=00000008") gpio_seen = 1;
            if (line.len() > 25 && line.substr(0,24) == "CPU=RV32IMC SELF=000000FF") status_seen = 1;
            if (line.len() >= 9 && line.substr(0,8) == "IRQ_TICK=") tick_lines = tick_lines + 1;
            line = "";
        end else if (character != 13) line = {line, character};
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
        // Let the help line finish before testing the single-byte RX register.
        repeat (100000) @(posedge clk);
        send_character("p"); wait (pong_seen);
        send_character("m"); wait (m_seen);
        send_character("i"); wait (soft_seen);
        send_character("3"); wait (gpio_seen);
        send_character("?"); wait (status_seen);
        wait (tick_lines >= 3);
        if (pcpi_operations < 1 || trace_events < 100) $fatal(1, "PCPI or trace missing");
        $display("TEST PASS: RV32IMC M/C/counters/shift/PCPI/timer IRQ/waitirq/qregs/fault recovery/trace and UART commands");
        $finish;
    end
    initial begin
        repeat (4000000) @(posedge clk);
        $fatal(1, "Simulation timed out; boot=%b status=%b", boot_seen, status_seen);
    end
endmodule
