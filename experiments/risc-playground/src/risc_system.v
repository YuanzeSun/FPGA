`include "hdmi/svo_defines.vh"
// C firmware runs on PicoRV32 and publishes character VRAM pages to tile_stream.
module risc_system #( `SVO_DEFAULT_PARAMS ) (
    input wire clk,resetn,ser_rx,
    output wire ser_tx,
    output wire [5:0] led,
    output wire out_axis_tvalid,
    input wire out_axis_tready,
    output wire [SVO_BITS_PER_PIXEL-1:0] out_axis_tdata,
    output wire [0:0] out_axis_tuser
);
    wire write_enable,flip_request,pending,front,tick,trap,overflow;
    wire [10:0] address;
    wire [15:0] data;
    wire [31:0] frames,status;
    risc_soc soc(.clk(clk),.resetn(resetn),.ser_rx(ser_rx),.frame_tick(tick),.ser_tx(ser_tx),.trap(trap),
        .vram_we(write_enable),.flip_request(flip_request),.vram_addr(address),.vram_data(data),
        .flip_pending(pending),.front_page(front),.frame_count(frames),.debug0(status),
        .debug1(),.debug2(),.debug3(),.debug4(),.debug5(),.rx_overflow(overflow));
    tile_stream pixels(.clk(clk),.resetn(resetn),.vram_we(write_enable),.flip_request(flip_request),
        .vram_addr(address),.vram_data(data),.flip_pending(pending),.front_page(front),.frame_tick(tick),
        .out_axis_tvalid(out_axis_tvalid),.out_axis_tready(out_axis_tready),
        .out_axis_tdata(out_axis_tdata),.out_axis_tuser(out_axis_tuser));
    assign led=~{trap,overflow,status[9],status[8],frames[5],resetn};
endmodule
