`timescale 1ns/1ps
module stock_tb;
    reg clk=0;always #5 clk=~clk;
    reg resetn=0,we=0,request=0;
    reg [10:0] address=0;
    reg [15:0] data=0;
    wire pending,front,tick,valid,ready,sof,enc_valid;
    wire [23:0] pixels,enc_pixels;
    wire [3:0] user;
    tile_stream dut(clk,resetn,we,request,address,data,pending,front,tick,valid,ready,pixels,sof);
    svo_enc #(.SVO_MODE("640x480V")) enc(clk,resetn,valid,ready,pixels,sof,enc_valid,1'b1,enc_pixels,user);
    reg [15:0] cells[0:1199];
    reg old_front,stalled;
    reg [25:0] held;
    integer g,i,f,n,active,hcount,vcount,ticks,frame_ticks=0,initial_ticks;
    string source_path;
    always @(posedge clk)if(tick)frame_ticks=frame_ticks+1;
    always @(posedge clk)begin
        stalled=resetn&&valid&&!ready;held={valid,sof,pixels};
        #1;
        if(stalled&&{valid,sof,pixels}!==held)$fatal(1,"RAM/font pixel pipeline changed under backpressure");
    end
    initial begin
        repeat(10)@(negedge clk);resetn=1;
        for(g=1;g<=6;g=g+1)begin
            if(g<=4)source_path=$sformatf("build/cpu-game%0d.cells",g);
            else if(g==5)source_path="build/native-letter-envelope.cells";
            else source_path="build/native-letter-full.cells";
            $readmemh(source_path,cells);old_front=front;
            for(i=0;i<1200;i=i+1)begin
                @(negedge clk);we=1;address=i;data=cells[i];
                if(front!=old_front)$fatal(1,"Front buffer changed before commit");
            end
            @(negedge clk);we=0;request=1;
            @(negedge clk);request=0;
            wait(front!=old_front);@(negedge clk);
            if(pending)$fatal(1,"Commit not acknowledged");
            // Allow any already queued pixels from the previous page to drain.
            repeat(800*525)@(negedge clk);
            while(!(enc_valid&&user[0]))@(negedge clk);
            f=$fopen($sformatf("build/preview%0d.hex",g),"w");
            active=0;hcount=0;vcount=0;initial_ticks=frame_ticks;
            for(n=0;n<800*525;n=n+1)begin
                if(!enc_valid)$fatal(1,"Encoded raster stalled");
                if(!user[3])begin
                    if(^enc_pixels===1'bx)$fatal(1,"Unknown visible pixel");
                    $fdisplay(f,"%06x",{enc_pixels[7:0],enc_pixels[15:8],enc_pixels[23:16]});active=active+1;
                end
                if(user[1])hcount=hcount+1;if(user[2])vcount=vcount+1;
                if(front!=!old_front)$fatal(1,"Unexpected page flip during visible frame");
                @(negedge clk);
            end
            $fclose(f);
            if(active!=307200||hcount!=50400||vcount!=1600||frame_ticks!=initial_ticks+1)$fatal(1,"Raster geometry or frame tick");
        end
        $display("TEST PASS: six CPU/C-authored full rasters, atomic double buffers, active writes during scan, RAM/font pipeline backpressure, frame tick and stock sync");$finish;
    end
    initial begin repeat(12000000)@(posedge clk);$fatal(1,"Video timeout");end
endmodule
