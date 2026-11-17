`timescale 1ns/1ps
module stock_tb;
    reg clk=0;always #5 clk=~clk;
    reg resetn=0;
    wire valid,ready,sof,enc_valid;
    wire [23:0] data,enc_data;
    wire [3:0] user;
    wire ser_tx;
    wire [5:0] led;
    integer i,active,hs,vs,starting_frames;
    reg was_stalled;
    reg [25:0] held_pixel;
    pong_stream #(.SVO_MODE("640x480V")) card(clk,resetn,1'b1,ser_tx,led,valid,ready,data,sof);
    svo_enc #(.SVO_MODE("640x480V")) enc(clk,resetn,valid,ready,data,sof,enc_valid,1'b1,enc_data,user);
    initial begin
        repeat(5)@(negedge clk);resetn=1;
        @(posedge clk);#1;
        // The vendor marks raster start in blanking, before the visible image.
        while(!(enc_valid&&user[0]))begin @(posedge clk);#1;end
        active=0;hs=0;vs=0;starting_frames=card.game.frame_count;
        for(i=0;i<800*525;i=i+1)begin
            if(!enc_valid)$fatal(1,"Video stream stalled after synchronization");
            if(!user[3])begin
                if(active==0&&enc_data!==24'h554133)$fatal(1,"First Pong border pixel mismatch");
                if(active==350*640+250&&enc_data!==24'h20120b)$fatal(1,"Pong background coordinate/byte order mismatch");
                active=active+1;
            end
            if(user[1])hs=hs+1;
            if(user[2])vs=vs+1;
            @(posedge clk);#1;
        end
        if(!(enc_valid&&user[0]))$fatal(1,"Frame period mismatch");
        if(active!=640*480||hs!=96*525||vs!=2*800)
            $fatal(1,"Geometry mismatch active=%0d hs=%0d vs=%0d",active,hs,vs);
        if(card.game.frame_count!=starting_frames+1)$fatal(1,"Game did not update exactly once per displayed frame");
        $display("TEST PASS: Pong stream, backpressure, color byte order, full 800x525 raster and one game update per frame");
        $finish;
    end
    initial begin #10000000;$fatal(1,"Vendor video did not synchronize");end
    always @(posedge clk)begin
        was_stalled=resetn&&valid&&!ready;
        held_pixel={valid,sof,data};
        #1;
        if(was_stalled&&{valid,sof,data}!==held_pixel)$fatal(1,"Pong pixel changed under backpressure");
    end
endmodule
