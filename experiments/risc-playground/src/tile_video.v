module tile_video #(parameter FONT_FILE="assets/font.hex", parameter EXTERNAL_TIMING=0)(
    input wire clk,resetn,vram_we,flip_request,
    input wire [10:0] vram_addr,
    input wire [15:0] vram_data,
    output reg flip_pending,front_page,
    output wire frame_tick,
    output wire [23:0] rgb,
    output reg de,hsync,vsync,
    input wire [9:0] video_x,video_y,
    input wire video_tick,video_advance
);
    wire [9:0] internal_x,internal_y;
    wire [9:0] x=EXTERNAL_TIMING?video_x:internal_x;
    wire [9:0] y=EXTERNAL_TIMING?video_y:internal_y;
    wire internal_tick;
    wire advance=!EXTERNAL_TIMING||video_advance;
    assign frame_tick=EXTERNAL_TIMING?video_tick:internal_tick;
    wire scan_de,scan_hs,scan_vs;
    video_timing scan(.clk(clk),.resetn(resetn),.x(internal_x),.y(internal_y),.de(scan_de),.hsync(scan_hs),.vsync(scan_vs),.frame_tick(internal_tick));
    (* ram_style="block" *) reg [15:0] page0[0:2047],page1[0:2047];
    (* rom_style="block" *) reg [15:0] font[0:4095];
    initial $readmemh(FONT_FILE,font);
    wire [10:0] row={6'b0,y[8:4]};
    wire [10:0] cell_addr=(row<<5)+(row<<3)+{5'b0,x[9:4]};
    reg [15:0] cell0,cell1;
    reg page_d,visible;
    wire [15:0] cell_value=page_d?cell1:cell0;
    reg [3:0] x_d,y_d,x_d2,fg,bg;
    reg de_d,hs_d,vs_d;
    reg [15:0] pixels;
    always @(posedge clk) begin
        if(vram_we)begin
            if(front_page)page0[vram_addr]<=vram_data;
            else page1[vram_addr]<=vram_data;
        end
        if(advance)begin
        cell0<=page0[cell_addr];cell1<=page1[cell_addr];
        page_d<=front_page;
        x_d<=x[3:0];y_d<=y[3:0];
        pixels<=font[{cell_value[7:0],y_d}];
        x_d2<=x_d;fg<=cell_value[11:8];bg<=cell_value[15:12];
        end
        if(!resetn) begin
            flip_pending<=0;front_page<=0;visible<=0;
            de_d<=0;hs_d<=1;vs_d<=1;de<=0;hsync<=1;vsync<=1;
        end else begin
            if(flip_request)flip_pending<=1;
            if(frame_tick&&flip_pending)begin front_page<=!front_page;flip_pending<=0;visible<=1;end
            if(advance)begin
                de_d<=(EXTERNAL_TIMING?1'b1:scan_de)&&visible;hs_d<=scan_hs;vs_d<=scan_vs;
                de<=de_d;hsync<=hs_d;vsync<=vs_d;
            end
        end
    end
    function [23:0] palette;
        input [3:0] index;
        begin case(index)
            0:palette=24'h080f1d;1:palette=24'hf8eddf;2:palette=24'h22d3ee;3:palette=24'hfb7185;
            4:palette=24'ha78bfa;5:palette=24'h4ade80;6:palette=24'hfbbf24;7:palette=24'hf8fafc;
            8:palette=24'h334155;9:palette=24'h1e293b;10:palette=24'he11d48;11:palette=24'h94a3b8;
            12:palette=24'h2563eb;13:palette=24'h0f766e;14:palette=24'h171024;15:palette=24'h513244;
        endcase end
    endfunction
    assign rgb=!de?24'b0:palette(pixels[15-x_d2]?fg:bg);
endmodule
