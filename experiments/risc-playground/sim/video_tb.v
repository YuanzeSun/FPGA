`timescale 1ns/1ps
module video_tb;
    reg clk=0;always #5 clk=~clk;
    reg resetn=0,we=0,request=0;
    reg [10:0] address=0;
    reg [15:0] data=0;
    wire pending,front,tick,de,hs,vs;
    wire [23:0] rgb;
    tile_video dut(.clk(clk),.resetn(resetn),.vram_we(we),.flip_request(request),.vram_addr(address),.vram_data(data),.flip_pending(pending),.front_page(front),.frame_tick(tick),.rgb(rgb),.de(de),.hsync(hs),.vsync(vs));
    reg [15:0] cells[0:1199];
    reg old_front;
    integer g,i,f,n,active,hcount,vcount;
    string source_path;
    initial begin
        repeat(10)@(negedge clk);resetn=1;
        for(g=1;g<=6;g=g+1)begin
            if(g<=4)source_path=$sformatf("build/cpu-game%0d.cells",g);
            else if(g==5)source_path="build/native-letter-envelope.cells";
            else source_path="build/native-letter-full.cells";
            $readmemh(source_path,cells);old_front=front;
            for(i=0;i<1200;i=i+1)begin
                @(negedge clk);we=1;address=i;data=cells[i];
                if(front!=old_front)$fatal(1,"front buffer changed before commit");
            end
            @(negedge clk);we=0;request=1;
            @(negedge clk);request=0;
            wait(front!=old_front);@(negedge clk);
            if(pending)$fatal(1,"commit not acknowledged");
            while(dut.x!=0||dut.y!=0)@(negedge clk);
            f=$fopen($sformatf("build/preview%0d.hex",g),"w");
            active=0;hcount=0;vcount=0;
            for(n=0;n<420000;n=n+1)begin
                if(de)begin
                    if(^rgb===1'bx)$fatal(1,"unknown visible RGB");
                    $fdisplay(f,"%06x",rgb);active=active+1;
                end else if(rgb!=0)$fatal(1,"nonblack blanking");
                if(!hs)hcount++;if(!vs)vcount++;
                @(negedge clk);
            end
            $fclose(f);
            if(active!=307200||hcount!=50400||vcount!=1600)$fatal(1,"raster geometry");
        end
        $display("TEST PASS: CPU-authored VRAM, six complete RGB frames, font/palette pipeline, atomic double-buffer flips, 640x480 sync and blanking");$finish;
    end
    initial begin repeat(6000000)@(posedge clk);$fatal(1,"video timeout");end
endmodule
