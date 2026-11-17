`timescale 1ns/1ps
module hd_video_tb #(parameter HD1080=0, parameter HD45=0);
    localparam WIDTH=HD1080?1920:1280,HEIGHT=HD1080?1080:720;
    localparam HTOTAL=HD45?2080:HD1080?2200:1650,VTOTAL=HD1080?1125:750;
    localparam HSYNC=HD45?32:HD1080?44:40,SHIFT=HD1080?1:0;
    localparam LEFT=(WIDTH-(640<<SHIFT))/2,TOP=(HEIGHT-(480<<SHIFT))/2;
    localparam [63:0] TITLE=HD45?"1080P45 ":HD1080?"1080P30 ":"720P60  ";
    reg cpu_clk=0,pixel_clk=0;
    always #19.841 cpu_clk=~cpu_clk;
    always #(HD45?4.748:6.734) pixel_clk=~pixel_clk;
    reg cpu_resetn=0,pixel_resetn=0,we=0,request=0;
    reg [10:0] address=0;
    reg [15:0] data=0;
    wire pending,front,valid,ready,sof,enc_valid;
    wire [23:0] pixels,enc_pixels;
    wire [3:0] user;
    hd_tile_stream #(.HD1080(HD1080),.HD45(HD45)) dut(cpu_clk,cpu_resetn,pixel_clk,pixel_resetn,
        we,request,address,data,pending,front,valid,ready,pixels,sof);
    hd_svo_enc #(.HD1080(HD1080),.HD45(HD45)) enc(pixel_clk,pixel_resetn,
        valid,ready,pixels,sof,enc_valid,1'b1,enc_pixels,user);
    reg [15:0] cells[0:1199],font[0:4095];
    initial $readmemh("assets/font.hex",font);
    function [23:0] palette;
        input [3:0] index;
        begin case(index)
            0:palette=24'h080f1d;1:palette=24'hf8eddf;2:palette=24'h22d3ee;3:palette=24'hfb7185;
            4:palette=24'ha78bfa;5:palette=24'h4ade80;6:palette=24'hfbbf24;7:palette=24'hf8fafc;
            8:palette=24'h334155;9:palette=24'h1e293b;10:palette=24'he11d48;11:palette=24'h94a3b8;
            12:palette=24'h2563eb;13:palette=24'h0f766e;14:palette=24'h171024;15:palette=24'h513244;
        endcase end
    endfunction
    function [23:0] expected;
        input integer px,py;
        integer lx,ly,ch;
        reg [15:0] cell_value,bits;
        begin
            expected=HD1080?24'h1d0b20:24'h081b2a;
            if(px>=WIDTH-96&&py<96)expected=((px^py)&1)?24'hffffff:24'h000000;
            else if(py<8||py>=HEIGHT-8)expected=(px&16)?24'h334155:24'h94a3b8;
            if(px>=LEFT&&px<LEFT+(640<<SHIFT)&&py>=TOP&&py<TOP+(480<<SHIFT))begin
                lx=(px-LEFT)>>SHIFT;ly=(py-TOP)>>SHIFT;
                cell_value=cells[(ly/16)*40+lx/16];
                bits=font[(cell_value&255)*16+(ly%16)];
                expected=palette(bits[15-lx%16]?cell_value[11:8]:cell_value[15:12]);
            end
            if(px>=16&&px<144&&py>=16&&py<32)begin
                ch=(TITLE>>((7-(px-16)/16)*8))&255;
                bits=font[ch*16+py%16];
                expected=palette(bits[15-px%16]?7:0);
            end
            if(px==0||px==WIDTH-1||py==0||py==HEIGHT-1)expected=24'hffffff;
        end
    endfunction
    integer stalls=0,writes_during_stall=0,flips=0;
    reg stalled,last_input,old_front_pixel;
    reg [24:0] held;
    always @(posedge pixel_clk)begin
        stalled=pixel_resetn&&valid&&!ready;
        held={sof,pixels};
        last_input=dut.last_pixel;old_front_pixel=dut.front_pixel;
        if(stalled)stalls=stalls+1;
        #1;
        if(stalled&&{sof,pixels}!==held)$fatal(1,"HD pixel/marker changed under backpressure");
        if(pixel_resetn&&dut.front_pixel!=old_front_pixel)begin
            if(!last_input)$fatal(1,"Page ownership changed outside frame boundary");
            flips=flips+1;
        end
    end
    always @(posedge cpu_clk)if(we&&!ready)writes_during_stall=writes_during_stall+1;
    integer g,i,n,active,hs,vs,px,py;
    reg old_front;
    reg [23:0] want,actual;
    initial begin
        repeat(8)@(negedge cpu_clk);cpu_resetn=1;
        repeat(4)@(negedge pixel_clk);pixel_resetn=1;
        for(g=0;g<2;g=g+1)begin
            if(g==0)$readmemh("build/cpu-game3.cells",cells);
            else $readmemh("build/cpu-game4.cells",cells);
            old_front=front;
            for(i=0;i<1200;i=i+1)begin
                @(negedge cpu_clk);we=1;address=i;data=cells[i];
                if(front!=old_front)$fatal(1,"Front changed during back-page upload");
            end
            @(negedge cpu_clk);we=0;request=1;
            @(negedge cpu_clk);request=0;
            wait(front!=old_front);@(negedge cpu_clk);
            if(pending)$fatal(1,"Swap acknowledgement missing");
            @(negedge pixel_clk);
            while(!(enc_valid&&user[0]))@(negedge pixel_clk);
            active=0;hs=0;vs=0;
            for(n=0;n<HTOTAL*VTOTAL;n=n+1)begin
                if(!enc_valid)$fatal(1,"HD scan underflow");
                if(!user[3])begin
                    px=active%WIDTH;py=active/WIDTH;
                    want=expected(px,py);
                    actual={enc_pixels[7:0],enc_pixels[15:8],enc_pixels[23:16]};
                    if(actual!==want)$fatal(1,"HD pixel mismatch mode=%0d page=%0d x=%0d y=%0d actual=%06x expected=%06x",HD1080,g,px,py,actual,want);
                    active=active+1;
                end else if(enc_pixels!=0)$fatal(1,"Blanking not black");
                if(user[1])hs=hs+1;if(user[2])vs=vs+1;
                @(negedge pixel_clk);
            end
            if(!(enc_valid&&user[0]))$fatal(1,"HD total frame period mismatch");
            if(active!=WIDTH*HEIGHT||hs!=HSYNC*VTOTAL||vs!=(HD45?VTOTAL-5:5)*HTOTAL)$fatal(1,"HD sync geometry mismatch");
            $display("HD frame PASS mode=%0d page=%0d pixels=%0d",HD1080,g,active);
        end
        if(stalls==0||writes_during_stall==0||flips!=2)$fatal(1,"CDC/backpressure coverage missing");
        $display("TEST PASS: HD full-pixel reference, Chinese/ASCII glyphs, independent CPU/video clocks, page handshake, no tearing, native edges/checkerboard, backpressure");$finish;
    end
    initial begin #300000000;$fatal(1,"HD simulation timeout");end
endmodule
