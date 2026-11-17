// CPU writes the back page at 25.2 MHz; video runs at 74.25 or 105.3 MHz.
// A toggle request/acknowledgement transfers page ownership at a frame boundary.
module hd_tile_stream #(
    parameter HD1080=0,
    parameter HD45=0,
    parameter FONT_FILE="assets/font.hex",
    parameter WIDTH=HD1080?1920:1280,
    parameter HEIGHT=HD1080?1080:720
)(
    input wire cpu_clk,cpu_resetn,pixel_clk,pixel_resetn,
    input wire vram_we,flip_request,
    input wire [10:0] vram_addr,
    input wire [15:0] vram_data,
    output wire flip_pending,front_page,
    output reg out_valid,
    input wire out_ready,
    output reg [23:0] out_data,
    output reg out_sof
);
    localparam SCALE_SHIFT=HD1080?1:0;
    localparam XOFFSET=(WIDTH-(640<<SCALE_SHIFT))/2;
    localparam YOFFSET=(HEIGHT-(480<<SCALE_SHIFT))/2;
    localparam [63:0] TITLE=HD45?"1080P45 ":HD1080?"1080P30 ":"720P60  ";
    (* ram_style="block" *) reg [15:0] page0[0:2047],page1[0:2047];
    (* rom_style="block" *) reg [15:0] font[0:4095];
    initial $readmemh(FONT_FILE,font);

    reg request_toggle;
    reg ack_toggle;
    (* syn_preserve=1, ASYNC_REG="TRUE" *) reg [2:0] request_sync,ack_sync;
    assign flip_pending=request_toggle!=ack_sync[2];
    assign front_page=ack_sync[2];
    always @(posedge cpu_clk)begin
        if(!cpu_resetn)begin request_toggle<=0;ack_sync<=0;end
        else begin
            ack_sync<={ack_sync[1:0],ack_toggle};
            if(flip_request&&!flip_pending)request_toggle<=!request_toggle;
        end
        if(cpu_resetn&&vram_we)begin
            if(front_page)page0[vram_addr]<=vram_data;
            else page1[vram_addr]<=vram_data;
        end
    end

    reg [10:0] x,y;
    reg last_column,last_row;
    reg front_pixel,visible,swap_wait,swap_target;
    reg last1;
    wire advance=!out_valid||out_ready;
    wire line_end=HD45?last_column:x==WIDTH-1;
    wire frame_end=HD45?last_row:y==HEIGHT-1;
    wire last_pixel=advance&&line_end&&frame_end;
    always @(posedge pixel_clk)begin
        if(!pixel_resetn)begin
            request_sync<=0;ack_toggle<=0;front_pixel<=0;visible<=0;swap_wait<=0;swap_target<=0;
        end else begin
            request_sync<={request_sync[1:0],request_toggle};
            if(last_pixel&&!swap_wait&&request_sync[2]!=ack_toggle)begin
                front_pixel<=!front_pixel;swap_target<=request_sync[2];swap_wait<=1;visible<=1;
            end
            // Return page ownership only after the old page's last RAM read.
            if(advance&&last1&&swap_wait)begin
                ack_toggle<=swap_target;swap_wait<=0;
            end
        end
    end

    wire [10:0] source_x=(x-XOFFSET)>>SCALE_SHIFT;
    wire [10:0] source_y=(y-YOFFSET)>>SCALE_SHIFT;
    wire in_canvas=x>=XOFFSET&&x<XOFFSET+(640<<SCALE_SHIFT)&&
                   y>=YOFFSET&&y<YOFFSET+(480<<SCALE_SHIFT);
    wire in_header=x>=16&&x<144&&y>=16&&y<32;
    wire [7:0] header_x=x-11'd16;
    reg [9:0] logical_x1,logical_y1;
    reg [3:0] font_x1,font_y1,font_x2,font_y2,font_x3;
    reg [2:0] header_index1;
    reg valid1,valid2,valid3,valid4,sof1,sof2,sof3,sof4;
    reg page1_d,page2_d,canvas1,canvas2,canvas3;
    reg canvas4,header1,header2,header3,header4,visible1,visible2,visible3,visible4;
    reg border1,border2,border3,border4;
    reg [23:0] background1,background2,background3,background4;
    reg [15:0] cell0,cell1,header_cell;
    wire [10:0] row={6'b0,logical_y1[8:4]};
    wire [10:0] cell_address=(row<<5)+(row<<3)+{5'b0,logical_x1[9:4]};
    wire [15:0] cell_value=header2?header_cell:(page2_d?cell1:cell0);
    // At 105.3 MHz, separate page selection from the following font RAM read.
    reg [15:0] selected_cell;
    reg [3:0] selected_x,selected_y;
    reg selected_valid,selected_sof,selected_visible,selected_canvas,selected_header,selected_border;
    reg [23:0] selected_background;
    wire [15:0] font_cell=HD45?selected_cell:cell_value;
    wire [3:0] font_y=HD45?selected_y:font_y2;
    reg [15:0] glyph_row;
    reg [3:0] fg3,bg3,fg4,bg4;
    reg ink4;
    function [23:0] palette;
        input [3:0] index;
        begin case(index)
            0:palette=24'h080f1d;1:palette=24'hf8eddf;2:palette=24'h22d3ee;3:palette=24'hfb7185;
            4:palette=24'ha78bfa;5:palette=24'h4ade80;6:palette=24'hfbbf24;7:palette=24'hf8fafc;
            8:palette=24'h334155;9:palette=24'h1e293b;10:palette=24'he11d48;11:palette=24'h94a3b8;
            12:palette=24'h2563eb;13:palette=24'h0f766e;14:palette=24'h171024;15:palette=24'h513244;
        endcase end
    endfunction
    wire [23:0] glyph_rgb=palette(ink4?fg4:bg4);
    wire [23:0] rgb=border4?24'hffffff:
        (header4||(canvas4&&visible4))?glyph_rgb:background4;
    always @(posedge pixel_clk)begin
        if(!pixel_resetn)begin
            x<=0;y<=0;last_column<=0;last_row<=0;
            valid1<=0;valid2<=0;valid3<=0;valid4<=0;last1<=0;out_valid<=0;
            selected_valid<=0;selected_sof<=0;
            sof1<=0;sof2<=0;sof3<=0;sof4<=0;out_sof<=0;out_data<=0;
        end else if(advance)begin
            // Coordinate and page ownership stage.
            valid1<=1;sof1<=x==0&&y==0;
            last1<=line_end&&frame_end;
            logical_x1<=source_x[9:0];logical_y1<=source_y[9:0];
            font_x1<=in_header?x[3:0]:source_x[3:0];
            font_y1<=in_header?y[3:0]:source_y[3:0];
            header_index1<=header_x[6:4];
            page1_d<=front_pixel;visible1<=visible;
            canvas1<=in_canvas;header1<=in_header;
            border1<=x==0||x==WIDTH-1||y==0||y==HEIGHT-1;
            if(x>=WIDTH-96&&y<96)background1<=(x[0]^y[0])?24'hffffff:24'h000000;
            else if(y<8||y>=HEIGHT-8)background1<=x[4]?24'h334155:24'h94a3b8;
            else background1<=HD1080?24'h1d0b20:24'h081b2a;
            last_column<=x==WIDTH-2;
            if(line_end)last_row<=y==HEIGHT-2;
            if(line_end)begin x<=0;if(frame_end)y<=0;else y<=y+1'b1;end
            else x<=x+1'b1;
            // Both pages have independent CPU-write and video-read clocks.
            cell0<=page0[cell_address];cell1<=page1[cell_address];
            header_cell<={4'h0,4'h7,TITLE[63-header_index1*8-:8]};
            font_x2<=font_x1;font_y2<=font_y1;page2_d<=page1_d;
            valid2<=valid1;sof2<=sof1;visible2<=visible1;
            canvas2<=canvas1;header2<=header1;border2<=border1;background2<=background1;
            selected_cell<=cell_value;selected_x<=font_x2;selected_y<=font_y2;
            selected_valid<=valid2;selected_sof<=sof2;selected_visible<=visible2;
            selected_canvas<=canvas2;selected_header<=header2;selected_border<=border2;
            selected_background<=background2;
            // Synchronous glyph ROM stage.
            glyph_row<=font[{font_cell[7:0],font_y}];
            font_x3<=HD45?selected_x:font_x2;fg3<=font_cell[11:8];bg3<=font_cell[15:12];
            valid3<=HD45?selected_valid:valid2;sof3<=HD45?selected_sof:sof2;
            visible3<=HD45?selected_visible:visible2;
            canvas3<=HD45?selected_canvas:canvas2;header3<=HD45?selected_header:header2;
            border3<=HD45?selected_border:border2;background3<=HD45?selected_background:background2;
            // Register the glyph bit before the palette and final output mux.
            ink4<=glyph_row[15-font_x3];fg4<=fg3;bg4<=bg3;
            valid4<=valid3;sof4<=sof3;visible4<=visible3;
            canvas4<=canvas3;header4<=header3;border4<=border3;background4<=background3;
            out_valid<=valid4;out_sof<=sof4;
            out_data<={rgb[7:0],rgb[15:8],rgb[23:16]};
        end
    end
endmodule
