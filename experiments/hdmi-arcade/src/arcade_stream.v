`include "hdmi/svo_defines.vh"
// Hold both the pixel and its frame marker until the video FIFO accepts them.
module arcade_stream #( `SVO_DEFAULT_PARAMS ) (
    input wire clk,resetn,ser_rx,
    output wire ser_tx,
    output wire [5:0] led,
    output reg out_axis_tvalid,
    input wire out_axis_tready,
    output reg [SVO_BITS_PER_PIXEL-1:0] out_axis_tdata,
    output reg [0:0] out_axis_tuser
);
    reg [9:0] x,y;
    wire advance=!out_axis_tvalid||out_axis_tready;
    wire frame_tick=resetn&&advance&&x==639&&y==479;
    wire paused,autoplay;
    wire [1:0] mode;
    wire [31:0] frames;
    wire [23:0] rgb;
    arcade_system #(.EXTERNAL_TIMING(1)) game(
        .clk(clk),.resetn(resetn),.ser_rx(ser_rx),.ser_tx(ser_tx),
        .video_tick(frame_tick),.video_x(x),.video_y(y),
        .rgb(rgb),.de(),.hsync(),.vsync(),.paused(paused),.autoplay(autoplay),
        .mode(mode),.frame_count(frames),.rx_count(),.score(),.lives(),.state(),
        .player_x(),.object_x(),.object_y());
    assign led=~{mode,paused,autoplay,frames[5],resetn};
    always @(posedge clk)begin
        if(!resetn)begin
            x<=0;y<=0;out_axis_tvalid<=0;out_axis_tdata<=0;out_axis_tuser<=0;
        end else if(advance)begin
            out_axis_tvalid<=1;
            // Stock SVO pixel words store R in the least significant byte.
            out_axis_tdata<={rgb[7:0],rgb[15:8],rgb[23:16]};
            out_axis_tuser<=x==0&&y==0;
            if(x==639)begin x<=0;if(y==479)y<=0;else y<=y+1'b1;end
            else x<=x+1'b1;
        end
    end
endmodule
