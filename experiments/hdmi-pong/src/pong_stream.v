`include "hdmi/svo_defines.vh"
// Supply visible Pong pixels using the stock video's valid/ready protocol.
module pong_stream #( `SVO_DEFAULT_PARAMS ) (
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
    wire [31:0] frames;
    wire [11:0] left_y,right_y,ball_x,ball_y;
    wire [6:0] left_score,right_score;
    wire [23:0] rgb;
    pong_system #(.EXTERNAL_TIMING(1)) game(
        .clk(clk),.resetn(resetn),.ser_rx(ser_rx),.ser_tx(ser_tx),.video_tick(frame_tick),
        .rgb(),.de(),.hsync(),.vsync(),.paused(paused),.autoplay(autoplay),.frame_count(frames),
        .left_y(left_y),.right_y(right_y),.ball_x(ball_x),.ball_y(ball_y),
        .left_score(left_score),.right_score(right_score),.rx_count());
    pong_render render(.x(x),.y(y),.de(1'b1),.paused(paused),.autoplay(autoplay),
        .left_y(left_y),.right_y(right_y),.ball_x(ball_x),.ball_y(ball_y),
        .left_score(left_score),.right_score(right_score),.rgb(rgb));
    assign led=~{2'b0,paused,autoplay,frames[5],resetn};
    always @(posedge clk)begin
        if(!resetn)begin
            x<=0;y<=0;out_axis_tvalid<=0;out_axis_tdata<=0;out_axis_tuser<=0;
        end else if(advance)begin
            out_axis_tvalid<=1;
            out_axis_tdata<={rgb[7:0],rgb[15:8],rgb[23:16]};
            out_axis_tuser<=x==0&&y==0;
            if(x==639)begin x<=0;if(y==479)y<=0;else y<=y+1'b1;end
            else x<=x+1'b1;
        end
    end
endmodule
