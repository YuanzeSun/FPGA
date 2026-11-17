// Shared-clock RV32IMC SoC. All game rules run in C, not in this module.
module risc_soc #(parameter FIRMWARE_FILE="build/firmware.hex")(
    input wire clk,resetn,ser_rx,frame_tick,
    output wire ser_tx,trap,
    output wire vram_we,flip_request,
    output wire [10:0] vram_addr,
    output wire [15:0] vram_data,
    input wire flip_pending,front_page,
    output reg [31:0] frame_count,
    output reg [31:0] debug0,debug1,debug2,debug3,debug4,debug5,
    output reg rx_overflow
);
    wire valid;
    wire [31:0] addr,wdata;
    wire [3:0] wstrb;
    wire [31:0] rdata;
    reg ready;
    picorv32 #(
        .PROGADDR_RESET(0),.STACKADDR(32'h00012000),
        .ENABLE_COUNTERS(1),.ENABLE_COUNTERS64(1),.ENABLE_REGS_16_31(1),.ENABLE_REGS_DUALPORT(1),
        .TWO_CYCLE_ALU(1),.TWO_CYCLE_COMPARE(1),.BARREL_SHIFTER(1),.COMPRESSED_ISA(1),
        .ENABLE_MUL(1),.ENABLE_DIV(1),.ENABLE_FAST_MUL(0),.ENABLE_IRQ(0),.ENABLE_PCPI(0),.ENABLE_TRACE(0),
        .REGS_INIT_ZERO(1),.CATCH_MISALIGN(1),.CATCH_ILLINSN(1)
    ) cpu(.clk(clk),.resetn(resetn),.trap(trap),.mem_valid(valid),.mem_addr(addr),.mem_wdata(wdata),.mem_wstrb(wstrb),.mem_rdata(rdata),.mem_ready(ready),.irq(32'b0),.pcpi_wr(1'b0),.pcpi_ready(1'b0),.pcpi_wait(1'b0),.pcpi_rd(32'b0));
    (* rom_style="block" *) reg [31:0] rom[0:4095];
    // Four byte lanes allow native byte/halfword stores to infer block RAM.
    (* ram_style="block" *) reg [7:0] ram0[0:2047],ram1[0:2047],ram2[0:2047],ram3[0:2047];
    reg [31:0] rom_q,ram_q,io_q;
    initial $readmemh(FIRMWARE_FILE,rom);
    wire rom_sel=addr[31:14]==0;
    wire ram_sel=addr[31:13]==19'h00008; // 0x10000..0x11fff
    wire request=valid&&!ready;
    always @(posedge clk) begin
        rom_q<=rom[addr[13:2]];
        ram_q<={ram3[addr[12:2]],ram2[addr[12:2]],ram1[addr[12:2]],ram0[addr[12:2]]};
        if(resetn&&request&&ram_sel) begin
            if(wstrb[0])ram0[addr[12:2]]<=wdata[7:0];
            if(wstrb[1])ram1[addr[12:2]]<=wdata[15:8];
            if(wstrb[2])ram2[addr[12:2]]<=wdata[23:16];
            if(wstrb[3])ram3[addr[12:2]]<=wdata[31:24];
        end
    end
    assign rdata=rom_sel?rom_q:ram_sel?ram_q:io_q;
    wire vram_sel=addr[31:13]==19'h01800;
    assign vram_we=resetn&&request&&vram_sel&&wstrb[0];
    assign vram_addr=addr[12:2];
    assign vram_data=wdata[15:0];
    assign flip_request=resetn&&request&&addr==32'h02000014&&wstrb[0];
    wire div_sel=addr==32'h02000000;
    wire data_sel=addr==32'h02000004;
    wire [31:0] uart_rx,uart_div;
    wire tx_wait;
    reg [1:0] rx_sync=3;
    reg [7:0] fifo[0:15];
    reg [3:0] read_pointer,write_pointer;
    reg [4:0] fifo_count;
    wire pop=request&&data_sel&&!(|wstrb)&&fifo_count!=0;
    wire push=uart_rx!=32'hffffffff&&(fifo_count<16||pop);
    simpleuart uart(.clk(clk),.resetn(resetn),.ser_rx(rx_sync[1]),.ser_tx(ser_tx),
        .reg_div_we(request&&div_sel?wstrb:4'b0),.reg_div_di(wdata),.reg_div_do(uart_div),
        .reg_dat_re(push),.reg_dat_do(uart_rx),.reg_dat_we(request&&data_sel&&wstrb[0]),.reg_dat_di(wdata),.reg_dat_wait(tx_wait));
    always @(posedge clk) begin
        if(!resetn) begin
            rx_sync<=3;fifo_count<=0;read_pointer<=0;write_pointer<=0;rx_overflow<=0;
        end else begin
            rx_sync<={rx_sync[0],ser_rx};
            if(push)begin fifo[write_pointer]<=uart_rx[7:0];write_pointer<=write_pointer+1'b1;end
            if(pop)read_pointer<=read_pointer+1'b1;
            case({push,pop}) 2'b10:fifo_count<=fifo_count+1'b1;2'b01:fifo_count<=fifo_count-1'b1;default:begin end endcase
            if(fifo_count==16&&uart_rx!=32'hffffffff&&!pop)rx_overflow<=1;
        end
    end
    always @(posedge clk) begin
        if(!resetn) begin ready<=0;io_q<=0;frame_count<=0;debug0<=0;debug1<=0;debug2<=0;debug3<=0;debug4<=0;debug5<=0;end
        else begin
            ready<=0;
            if(frame_tick)frame_count<=frame_count+1'b1;
            if(request) begin
                ready<=1;
                if(div_sel)io_q<=uart_div;
                else if(data_sel)begin
                    ready<=!tx_wait;io_q<=fifo_count!=0?{24'b0,fifo[read_pointer]}:32'hffffffff;
                end else case(addr)
                    32'h02000010:io_q<=frame_count;
                    32'h02000014:io_q<={30'b0,front_page,flip_pending};
                    32'h02000018:io_q<={31'b0,rx_overflow};
                    32'h02000020:begin io_q<=debug0;if(wstrb[0])debug0<=wdata;end
                    32'h02000024:begin io_q<=debug1;if(wstrb[0])debug1<=wdata;end
                    32'h02000028:begin io_q<=debug2;if(wstrb[0])debug2<=wdata;end
                    32'h0200002c:begin io_q<=debug3;if(wstrb[0])debug3<=wdata;end
                    32'h02000030:begin io_q<=debug4;if(wstrb[0])debug4<=wdata;end
                    32'h02000034:begin io_q<=debug5;if(wstrb[0])debug5<=wdata;end
                    default:io_q<=0;
                endcase
            end
        end
    end
endmodule
