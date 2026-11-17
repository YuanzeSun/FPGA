`timescale 1ns/1ps
module video_tb;
    reg clk=0;always #5 clk=~clk;
    reg resetn=0,rx=1;
    wire tx,de,hs,vs;
    wire [23:0] rgb;
    arcade_system dut(.clk(clk),.resetn(resetn),.ser_rx(rx),.ser_tx(tx),.rgb(rgb),.de(de),.hsync(hs),.vsync(vs));
    task send(input [7:0] value);
        integer i;
        begin
            @(negedge clk)rx=0;repeat(219)@(negedge clk);
            for(i=0;i<8;i=i+1)begin rx=value[i];repeat(219)@(negedge clk);end
            rx=1;repeat(219)@(negedge clk);
        end
    endtask
    integer g,fd,n,active,hs_count,vs_count,ticks;
    initial begin
        repeat(10)@(negedge clk);resetn=1;
        for(g=0;g<3;g=g+1)begin
            send(8'd49+g);
            // Advance the real game modules for a representative demo frame.
            force dut.frame_tick=1;
            repeat(400)@(negedge clk);
            release dut.frame_tick;
            @(negedge clk);
            while(dut.x!=0||dut.y!=0)@(negedge clk);
            fd=$fopen($sformatf("build/game%0d.hex",g+1),"w");
            active=0;hs_count=0;vs_count=0;ticks=0;
            for(n=0;n<420000;n=n+1)begin
                if(de)begin
                    if(^rgb===1'bx)$fatal(1,"unknown pixel");
                    $fdisplay(fd,"%06x",rgb);active=active+1;
                end else if(rgb!=0)$fatal(1,"blanking must be black");
                if(!hs)hs_count=hs_count+1;
                if(!vs)vs_count=vs_count+1;
                if(dut.frame_tick)ticks=ticks+1;
                @(negedge clk);
            end
            $fclose(fd);
            if(active!=307200||hs_count!=50400||vs_count!=1600||ticks!=1)$fatal(1,"video timing %d %d %d %d",active,hs_count,vs_count,ticks);
        end
        $display("TEST PASS: all 3 RGB frames, 640x480 active, 800x525 totals, sync lengths, blanking");$finish;
    end
    initial begin repeat(3000000)@(posedge clk);$fatal(1,"timeout");end
endmodule
