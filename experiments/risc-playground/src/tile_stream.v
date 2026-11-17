// Two synchronous RAM-read stages advance together with the pixel stream.
// CPU writes and flip requests remain live while the video reader is stalled.
module tile_stream(
    input wire clk,resetn,vram_we,flip_request,
    input wire [10:0] vram_addr,
    input wire [15:0] vram_data,
    output wire flip_pending,front_page,frame_tick,
    output wire out_axis_tvalid,
    input wire out_axis_tready,
    output wire [23:0] out_axis_tdata,
    output wire [0:0] out_axis_tuser
);
    reg [9:0] x,y;
    reg sof_d,sof_d2;
    wire [23:0] rgb;
    wire advance=!out_axis_tvalid||out_axis_tready;
    assign frame_tick=resetn&&advance&&x==639&&y==479;
    tile_video #(.EXTERNAL_TIMING(1)) video(
        .clk(clk),.resetn(resetn),.vram_we(vram_we),.flip_request(flip_request),
        .vram_addr(vram_addr),.vram_data(vram_data),.flip_pending(flip_pending),.front_page(front_page),
        .frame_tick(),.rgb(rgb),.de(out_axis_tvalid),.hsync(),.vsync(),
        .video_x(x),.video_y(y),.video_tick(frame_tick),.video_advance(advance));
    assign out_axis_tdata={rgb[7:0],rgb[15:8],rgb[23:16]};
    assign out_axis_tuser=sof_d2;
    always @(posedge clk)begin
        if(!resetn)begin x<=0;y<=0;sof_d<=0;sof_d2<=0;end
        else if(advance)begin
            sof_d<=x==0&&y==0;sof_d2<=sof_d;
            if(x==639)begin x<=0;if(y==479)y<=0;else y<=y+1'b1;end
            else x<=x+1'b1;
        end
    end
endmodule
