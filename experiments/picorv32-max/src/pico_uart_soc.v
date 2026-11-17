// Full-featured PicoRV32 configuration using the unmodified Sipeed core.
module pico_uart_soc #(
    parameter integer IRQ_RELOAD = 13500000,
    parameter FIRMWARE_FILE = "build/firmware.hex"
) (
    input wire clk, resetn, ser_rx,
    output wire ser_tx,
    output reg [5:0] gpio,
    output wire trap
);
    wire mem_valid;
    wire [31:0] mem_addr, mem_wdata, mem_rdata;
    wire [3:0] mem_wstrb;
    reg mem_ready;
    reg [31:0] io_rdata;
    wire [31:0] irq;
    reg soft_irq;
    wire [31:0] eoi;
    wire trace_valid;
    wire [35:0] trace_data;
    reg [31:0] trace_count;
    reg [35:0] trace_last;
    wire pcpi_valid, pcpi_ready;
    wire [31:0] pcpi_insn, pcpi_rs1, pcpi_rs2, pcpi_rd;

    picorv32 #(
        .PROGADDR_RESET(32'h00000000), .PROGADDR_IRQ(32'h00000010),
        .STACKADDR(32'h00001200),
        .ENABLE_COUNTERS(1), .ENABLE_COUNTERS64(1),
        .ENABLE_REGS_16_31(1), .ENABLE_REGS_DUALPORT(1),
        .LATCHED_MEM_RDATA(0), .TWO_STAGE_SHIFT(1),
        .BARREL_SHIFTER(1), .COMPRESSED_ISA(1),
        .TWO_CYCLE_COMPARE(1), .TWO_CYCLE_ALU(1),
        .ENABLE_MUL(1), .ENABLE_FAST_MUL(0), .ENABLE_DIV(1),
        .ENABLE_IRQ(1), .ENABLE_IRQ_QREGS(1), .ENABLE_IRQ_TIMER(1),
        .ENABLE_PCPI(1), .ENABLE_TRACE(1), .REGS_INIT_ZERO(1),
        .CATCH_MISALIGN(1), .CATCH_ILLINSN(1),
        .MASKED_IRQ(32'h00000000), .LATCHED_IRQ(32'hffffffff)
    ) cpu (
        .clk(clk), .resetn(resetn), .trap(trap),
        .mem_valid(mem_valid), .mem_ready(mem_ready),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb), .mem_rdata(mem_rdata),
        .pcpi_valid(pcpi_valid), .pcpi_insn(pcpi_insn),
        .pcpi_rs1(pcpi_rs1), .pcpi_rs2(pcpi_rs2),
        .pcpi_wr(pcpi_ready), .pcpi_rd(pcpi_rd),
        .pcpi_wait(1'b0), .pcpi_ready(pcpi_ready),
        .irq(irq), .eoi(eoi), .trace_valid(trace_valid), .trace_data(trace_data)
    );
    // Demonstration PCPI coprocessor: custom-1 opcode, bit-reverse 32 bits.
    assign pcpi_ready = pcpi_valid && (pcpi_insn & 32'hfff0707f) == 32'h0000002b;
    genvar bit_number;
    generate for (bit_number = 0; bit_number < 32; bit_number = bit_number + 1) begin: reverse_bits
        assign pcpi_rd[bit_number] = pcpi_rs1[31-bit_number];
    end endgenerate
    assign irq = {27'b0, soft_irq, 4'b0};

    // Separate immutable program ROM and writable data/stack RAM.
    // This works with the installed nextpnr-gowin, without block RAM support.
    reg [31:0] rom [0:1023];
    reg [31:0] ram [0:127];
    reg [31:0] rom_rdata, ram_rdata;
    initial $readmemh(FIRMWARE_FILE, rom);
    wire rom_selected = mem_addr < 32'h00001000;
    wire ram_selected = mem_addr >= 32'h00001000 && mem_addr < 32'h00001200;
    wire request = mem_valid && !mem_ready;
    always @(posedge clk) begin
        rom_rdata <= rom[mem_addr[11:2]];
        ram_rdata <= ram[mem_addr[8:2]];
        if (resetn && request && ram_selected) begin
            if (mem_wstrb[0]) ram[mem_addr[8:2]][7:0] <= mem_wdata[7:0];
            if (mem_wstrb[1]) ram[mem_addr[8:2]][15:8] <= mem_wdata[15:8];
            if (mem_wstrb[2]) ram[mem_addr[8:2]][23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3]) ram[mem_addr[8:2]][31:24] <= mem_wdata[31:24];
        end
    end
    assign mem_rdata = rom_selected ? rom_rdata : ram_selected ? ram_rdata : io_rdata;

    wire uart_div_selected = mem_addr == 32'h02000000;
    wire uart_data_selected = mem_addr == 32'h02000004;
    wire [31:0] uart_div_data, uart_read_data;
    wire uart_wait;
    reg [1:0] rx_sync = 2'b11;
    always @(posedge clk) begin
        if (!resetn) rx_sync <= 2'b11;
        else rx_sync <= {rx_sync[0], ser_rx};
    end
    simpleuart uart (
        .clk(clk), .resetn(resetn), .ser_tx(ser_tx), .ser_rx(rx_sync[1]),
        .reg_div_we((request && uart_div_selected) ? mem_wstrb : 4'b0),
        .reg_div_di(mem_wdata), .reg_div_do(uart_div_data),
        .reg_dat_we(request && uart_data_selected && mem_wstrb[0]),
        .reg_dat_re(request && uart_data_selected && !(|mem_wstrb)),
        .reg_dat_di(mem_wdata), .reg_dat_do(uart_read_data), .reg_dat_wait(uart_wait)
    );
    always @(posedge clk) begin
        if (!resetn) begin
            mem_ready <= 0;
            io_rdata <= 0;
            gpio <= 1;
            soft_irq <= 0;
            trace_count <= 0;
            trace_last <= 0;
        end else begin
            mem_ready <= 0;
            soft_irq <= 0;
            if (trace_valid) begin
                trace_count <= trace_count + 1;
                trace_last <= trace_data;
            end
            if (request) begin
                if (rom_selected || ram_selected) begin
                    mem_ready <= 1;
                end else if (uart_div_selected) begin
                    mem_ready <= 1;
                    io_rdata <= uart_div_data;
                end else if (uart_data_selected) begin
                    mem_ready <= !uart_wait;
                    io_rdata <= uart_read_data;
                end else begin
                    mem_ready <= 1;
                    case (mem_addr)
                        32'h02000008: begin
                            io_rdata <= {26'b0, gpio};
                            if (mem_wstrb[0]) gpio <= mem_wdata[5:0];
                        end
                        32'h02000010: io_rdata <= IRQ_RELOAD;
                        32'h02000020: begin
                            io_rdata <= 0;
                            if (mem_wstrb[0]) soft_irq <= mem_wdata[0];
                        end
                        32'h02000024: io_rdata <= trace_count;
                        32'h02000028: io_rdata <= trace_last[31:0];
                        32'h0200002c: io_rdata <= {28'b0, trace_last[35:32]};
                        default: io_rdata <= 32'hdeadbeef;
                    endcase
                end
            end
        end
    end
endmodule
