// Minimal on-chip-RAM SoC around the unmodified official-example CPU/UART.
module pico_uart_soc #(
    parameter integer TIMER_INCREMENT = 1,
    parameter FIRMWARE_FILE = "build/firmware.hex"
) (
    input wire clk,
    input wire resetn,
    input wire ser_rx,
    output wire ser_tx,
    output reg [5:0] gpio,
    output wire trap
);
    wire mem_valid;
    wire [31:0] mem_addr, mem_wdata;
    wire [3:0] mem_wstrb;
    reg mem_ready;
    wire [31:0] mem_rdata;
    reg [31:0] io_rdata;
    reg [31:0] timer;

    picorv32 #(
        .PROGADDR_RESET(32'h00000000),
        .STACKADDR(32'h00000400),
        .ENABLE_COUNTERS(0), .ENABLE_COUNTERS64(0),
        .ENABLE_MUL(0), .ENABLE_DIV(0), .ENABLE_IRQ(0),
        .COMPRESSED_ISA(0), .CATCH_MISALIGN(1), .CATCH_ILLINSN(1)
    ) cpu (
        .clk(clk), .resetn(resetn), .trap(trap),
        .mem_valid(mem_valid), .mem_ready(mem_ready),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb), .mem_rdata(mem_rdata),
        .pcpi_wr(1'b0), .pcpi_rd(32'b0), .pcpi_wait(1'b0), .pcpi_ready(1'b0),
        .irq(32'b0)
    );

    // 1 KiB distributed RAM. Firmware bytes are included in the FPGA configuration image.
    reg [31:0] memory [0:255];
    reg [31:0] ram_rdata;
    initial $readmemh(FIRMWARE_FILE, memory);
    wire ram_selected = mem_addr < 32'h00000400;
    wire request = mem_valid && !mem_ready;
    always @(posedge clk) begin
        ram_rdata <= memory[mem_addr[9:2]];
        if (resetn && request && ram_selected) begin
            if (mem_wstrb[0]) memory[mem_addr[9:2]][7:0] <= mem_wdata[7:0];
            if (mem_wstrb[1]) memory[mem_addr[9:2]][15:8] <= mem_wdata[15:8];
            if (mem_wstrb[2]) memory[mem_addr[9:2]][23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3]) memory[mem_addr[9:2]][31:24] <= mem_wdata[31:24];
        end
    end

    wire uart_div_selected = mem_addr == 32'h02000000;
    wire uart_data_selected = mem_addr == 32'h02000004;
    wire [31:0] uart_div_data, uart_read_data;
    wire uart_wait;
    simpleuart uart (
        .clk(clk), .resetn(resetn), .ser_tx(ser_tx), .ser_rx(ser_rx),
        .reg_div_we((request && uart_div_selected) ? mem_wstrb : 4'b0),
        .reg_div_di(mem_wdata), .reg_div_do(uart_div_data),
        .reg_dat_we(request && uart_data_selected && mem_wstrb[0]),
        .reg_dat_re(request && uart_data_selected && !(|mem_wstrb)),
        .reg_dat_di(mem_wdata), .reg_dat_do(uart_read_data), .reg_dat_wait(uart_wait)
    );
    assign mem_rdata = ram_selected ? ram_rdata : io_rdata;

    always @(posedge clk) begin
        if (!resetn) begin
            mem_ready <= 0;
            io_rdata <= 0;
            gpio <= 1;
            timer <= 0;
        end else begin
            timer <= timer + TIMER_INCREMENT;
            mem_ready <= 0;
            if (request) begin
                if (ram_selected) begin
                    mem_ready <= 1;
                end else if (uart_div_selected) begin
                    mem_ready <= 1;
                    io_rdata <= uart_div_data;
                end else if (uart_data_selected) begin
                    mem_ready <= !uart_wait;
                    io_rdata <= uart_read_data;
                end else if (mem_addr == 32'h02000008) begin
                    mem_ready <= 1;
                    io_rdata <= {26'b0, gpio};
                    if (mem_wstrb[0]) gpio <= mem_wdata[5:0];
                end else if (mem_addr == 32'h0200000c) begin
                    mem_ready <= 1;
                    io_rdata <= timer;
                end else begin
                    mem_ready <= 1;
                    io_rdata <= 32'hdeadbeef;
                end
            end
        end
    end
endmodule
