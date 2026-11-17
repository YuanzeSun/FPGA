module hd_reset_sync(input wire clk,async_resetn,output wire resetn);
    reg [3:0] pipe=0;
    always @(posedge clk or negedge async_resetn)
        if(!async_resetn)pipe<=0;else pipe<={pipe[2:0],1'b1};
    assign resetn=pipe[3];
endmodule

module hd_top #(parameter HD1080=0, parameter HD45=0)(
    input wire clk,resetn,ser_rx,
    output wire ser_tx,
    output wire [5:0] led,
    output wire tmds_clk_n,tmds_clk_p,
    output wire [2:0] tmds_d_n,tmds_d_p
);
    wire cpu_fast,cpu_clk,video_fast,pixel_clk,cpu_lock,video_lock;
    wire cpu_resetn,pixel_resetn;
    Gowin_rPLL u_cpu_pll(.clkin(clk),.clkout(cpu_fast),.lock(cpu_lock));
    Gowin_CLKDIV u_cpu_div(.hclkin(cpu_fast),.clkout(cpu_clk),.resetn(cpu_lock));
    HD_rPLL #(.HD45(HD45)) u_video_pll(.clkin(clk),.clkout(video_fast),.lock(video_lock));
    Gowin_CLKDIV u_video_div(.hclkin(video_fast),.clkout(pixel_clk),.resetn(video_lock));
    wire pll_ready=resetn&&cpu_lock&&video_lock;
    wire all_ready;
    generate if(HD45)begin:clock_startup
        // Qualify both locks in the oscillator domain before releasing either
        // application domain. Clock dividers and serializers already run here.
        reg [17:0] stable_count=0;
        reg stable=0;
        always @(posedge clk or negedge pll_ready)
            if(!pll_ready)begin stable_count<=0;stable<=0;end
            else if(!stable)begin
                if(&stable_count)stable<=1;
                else stable_count<=stable_count+1'b1;
            end
        assign all_ready=pll_ready&&stable;
    end else begin:original_startup
        assign all_ready=pll_ready;
    end endgenerate
    hd_reset_sync cpu_reset(cpu_clk,all_ready,cpu_resetn);
    hd_reset_sync pixel_reset(pixel_clk,all_ready,pixel_resetn);

    // Game timing remains 60 Hz at each supported display refresh rate.
    reg [18:0] tick_counter;
    wire game_tick=tick_counter==419999;
    always @(posedge cpu_clk)
        if(!cpu_resetn)tick_counter<=0;
        else tick_counter<=game_tick?0:tick_counter+1'b1;
    wire write_enable,flip_request,pending,front,trap,overflow;
    wire [10:0] address;
    wire [15:0] data;
    wire [31:0] frames,status;
    risc_soc soc(.clk(cpu_clk),.resetn(cpu_resetn),.ser_rx(ser_rx),.frame_tick(game_tick),.ser_tx(ser_tx),.trap(trap),
        .vram_we(write_enable),.flip_request(flip_request),.vram_addr(address),.vram_data(data),
        .flip_pending(pending),.front_page(front),.frame_count(frames),.debug0(status),
        .debug1(),.debug2(),.debug3(),.debug4(),.debug5(),.rx_overflow(overflow));
    wire valid,ready,sof,encoded_valid;
    wire [23:0] pixels,encoded_pixels;
    wire [3:0] timing;
    hd_tile_stream #(.HD1080(HD1080),.HD45(HD45)) pixels_source(
        .cpu_clk(cpu_clk),.cpu_resetn(cpu_resetn),.pixel_clk(pixel_clk),.pixel_resetn(pixel_resetn),
        .vram_we(write_enable),.flip_request(flip_request),.vram_addr(address),.vram_data(data),
        .flip_pending(pending),.front_page(front),.out_valid(valid),.out_ready(ready),.out_data(pixels),.out_sof(sof));
    hd_svo_enc #(.HD1080(HD1080),.HD45(HD45)) raster(pixel_clk,pixel_resetn,valid,ready,pixels,sof,
        encoded_valid,1'b1,encoded_pixels,timing);
    wire [9:0] blue,green,red;
    hd_tmds b(pixel_clk,pixel_resetn,!timing[3],timing[2:1],encoded_pixels[23:16],blue);
    hd_tmds g(pixel_clk,pixel_resetn,!timing[3],2'b00,encoded_pixels[15:8],green);
    hd_tmds r(pixel_clk,pixel_resetn,!timing[3],2'b00,encoded_pixels[7:0],red);
    wire [2:0] serial_data;
    // Configuration GSR initializes the serializers, which then run continuously.
    OSER10 #(.GSREN("true"),.LSREN("false")) serializer[2:0](.Q(serial_data),
        .D0({red[0],green[0],blue[0]}),.D1({red[1],green[1],blue[1]}),
        .D2({red[2],green[2],blue[2]}),.D3({red[3],green[3],blue[3]}),
        .D4({red[4],green[4],blue[4]}),.D5({red[5],green[5],blue[5]}),
        .D6({red[6],green[6],blue[6]}),.D7({red[7],green[7],blue[7]}),
        .D8({red[8],green[8],blue[8]}),.D9({red[9],green[9],blue[9]}),
        .PCLK(pixel_clk),.FCLK(video_fast),.RESET(1'b0));
    ELVDS_OBUF buffers[3:0](.I({pixel_clk,serial_data}),
        .O({tmds_clk_p,tmds_d_p}),.OB({tmds_clk_n,tmds_d_n}));
    assign led=~{trap,overflow,status[9],status[8],frames[5],cpu_resetn};
endmodule

module top_720p60(input clk,resetn,ser_rx,output ser_tx,output [5:0] led,
    output tmds_clk_n,tmds_clk_p,output [2:0] tmds_d_n,tmds_d_p);
    hd_top #(.HD1080(0)) hd(.clk(clk),.resetn(resetn),.ser_rx(ser_rx),.ser_tx(ser_tx),.led(led),.tmds_clk_n(tmds_clk_n),.tmds_clk_p(tmds_clk_p),.tmds_d_n(tmds_d_n),.tmds_d_p(tmds_d_p));
endmodule
module top_1080p30(input clk,resetn,ser_rx,output ser_tx,output [5:0] led,
    output tmds_clk_n,tmds_clk_p,output [2:0] tmds_d_n,tmds_d_p);
    hd_top #(.HD1080(1)) hd(.clk(clk),.resetn(resetn),.ser_rx(ser_rx),.ser_tx(ser_tx),.led(led),.tmds_clk_n(tmds_clk_n),.tmds_clk_p(tmds_clk_p),.tmds_d_n(tmds_d_n),.tmds_d_p(tmds_d_p));
endmodule
module top_1080p45(input clk,resetn,ser_rx,output ser_tx,output [5:0] led,
    output tmds_clk_n,tmds_clk_p,output [2:0] tmds_d_n,tmds_d_p);
    hd_top #(.HD1080(1),.HD45(1)) hd(.clk(clk),.resetn(resetn),.ser_rx(ser_rx),.ser_tx(ser_tx),.led(led),.tmds_clk_n(tmds_clk_n),.tmds_clk_p(tmds_clk_p),.tmds_d_n(tmds_d_n),.tmds_d_p(tmds_d_p));
endmodule
