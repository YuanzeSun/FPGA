// One outstanding transfer. ROM 0..0x3fff, RAM 0x4000..0x43ff.
module simple_soc #(parameter TIMER_STEP=1) (
    input wire clk, reset, ser_rx,
    output wire ser_tx,
    output reg [5:0] gpio,
    output wire trap,
    output wire [31:0] trap_cause, debug_pc, retired_count
);
    wire valid, fetch;
    wire [31:0] addr, wdata, trap_value;
    wire [3:0] wstrb;
    reg ready, error;
    wire [31:0] rdata;
    rv32_core cpu (
        .clk(clk), .reset(reset), .mem_valid(valid), .mem_instr(fetch),
        .mem_addr(addr), .mem_wdata(wdata), .mem_wstrb(wstrb),
        .mem_ready(ready), .mem_error(error), .mem_rdata(rdata),
        .trap(trap), .trap_cause(trap_cause), .trap_value(trap_value),
        .debug_pc(debug_pc), .retired_count(retired_count),
        .retire_valid(), .retire_pc(), .retire_instr(), .retire_rd(), .retire_data()
    );
    (* ram_style="block" *) reg [31:0] rom [0:4095];
    (* ram_style="block" *) reg [7:0] ram0 [0:255], ram1 [0:255], ram2 [0:255], ram3 [0:255];
    initial $readmemh("build/firmware.hex", rom);
    reg [31:0] rom_data;
    reg [7:0] ram_data0, ram_data1, ram_data2, ram_data3;
    wire ram_request = !reset && valid && !ready && !fetch && addr >= 32'h4000 && addr < 32'h4400;
    // Dedicated synchronous read registers allow inference of actual block RAM.
    // Byte lanes use independent memories, making byte writes explicit.
    always @(posedge clk) begin
        rom_data <= rom[addr[13:2]];
        ram_data0 <= ram0[addr[9:2]];
        ram_data1 <= ram1[addr[9:2]];
        ram_data2 <= ram2[addr[9:2]];
        ram_data3 <= ram3[addr[9:2]];
        if (ram_request && wstrb[0]) ram0[addr[9:2]] <= wdata[7:0];
        if (ram_request && wstrb[1]) ram1[addr[9:2]] <= wdata[15:8];
        if (ram_request && wstrb[2]) ram2[addr[9:2]] <= wdata[23:16];
        if (ram_request && wstrb[3]) ram3[addr[9:2]] <= wdata[31:24];
    end
    reg [1:0] response_kind;
    reg [31:0] io_data;
    assign rdata = response_kind == 0 ? rom_data : response_kind == 1 ?
                   {ram_data3,ram_data2,ram_data1,ram_data0} : io_data;
    reg [31:0] ticks;
    reg tx_start;
    wire rx_take = !reset && valid && !ready && !fetch &&
                   addr == 32'h40000008 && wstrb == 0;
    reg [7:0] tx_data;
    wire tx_busy, rx_valid, rx_overrun;
    wire [7:0] rx_data;
    uart serial(clk, reset, ser_rx, ser_tx, tx_start, tx_data, tx_busy,
                rx_take, rx_data, rx_valid, rx_overrun);
    always @(posedge clk) begin
        ready <= 0; error <= 0; tx_start <= 0;
        if (reset) begin
            gpio <= 0; ticks <= 0; ready <= 0; io_data <= 0; response_kind <= 2;
            tx_data <= 0;
        end else begin
            ticks <= ticks + TIMER_STEP;
            if (valid && !ready) begin
                ready <= 1; io_data <= 0; response_kind <= 2;
                if (addr < 32'h4000 && wstrb == 0) response_kind <= 0;
                else if (addr >= 32'h4000 && addr < 32'h4400 && !fetch) begin
                    response_kind <= 1;
                end else if (!fetch) begin
                    case (addr)
                        32'h40000000: begin
                            io_data <= {26'b0, gpio};
                            if (wstrb[0]) gpio <= wdata[5:0];
                        end
                        32'h40000004: if (wstrb[0]) begin
                            if (tx_busy || tx_start) ready <= 0;
                            else begin tx_start <= 1; tx_data <= wdata[7:0]; end
                        end
                        32'h40000008: if (wstrb == 0) begin
                            io_data <= rx_valid ? {24'b0, rx_data} : 32'hffffffff;
                        end else error <= 1;
                        32'h4000000c: io_data <= {29'b0, rx_overrun, rx_valid, tx_busy};
                        32'h40000010: io_data <= ticks;
                        32'h40000014: io_data <= trap_cause;
                        32'h40000018: io_data <= retired_count;
                        default: error <= 1;
                    endcase
                end else error <= 1;
            end
        end
    end
endmodule
