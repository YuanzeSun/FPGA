`timescale 1ns/1ps
module game_logic_tb;
    reg clk=0; always #5 clk=~clk;
    reg resetn=0,enable=0;
    reg [3:0] buttons=0;
    wire [3:0] auto_btn;
    wire [11:0] left_y,right_y,bx,by;
    wire [6:0] ls,rs;
    svo_pong_control #(.SVO_MODE("640x480")) dut(
        .clk(clk),.resetn(resetn),.enable(enable),.btn(buttons),.auto_btn(auto_btn),.flash(),
        .p1_pos(left_y),.p2_pos(right_y),.puck_x(bx),.puck_y(by),.p1_points(ls),.p2_points(rs));
    task step;
        begin
            wait(dut.state==7);
            @(negedge clk) enable=1;
            @(negedge clk) enable=0;
            repeat(10) @(negedge clk);
        end
    endtask
    integer i;
    reg [11:0] old_x,old_y;
    initial begin
        repeat(5) @(negedge clk);
        resetn=1;
        wait(dut.state==7);@(negedge clk);
        old_x=bx;old_y=by;step();
        if(bx!=old_x+3 || by!=old_y+4) $fatal(1,"Initial motion incorrect %d,%d",bx,by);
        old_x=bx;old_y=by;
        repeat(100) @(negedge clk);
        if(bx!=old_x || by!=old_y) $fatal(1,"Game moved without frame enable");
        buttons=4'b0100;
        repeat(8) step();
        if(left_y>=190) $fatal(1,"Up input did not move left paddle");
        buttons=4'b1000;
        repeat(30) step();
        if(left_y>378 || left_y<100) $fatal(1,"Down input/clamp incorrect");
        wait(dut.state==7);@(negedge clk);
        dut.px=24;dut.py=240;dut.pvx=-3;dut.pvy=0;dut.p1y=190;dut.p1vy=0;
        buttons=0;step();
        if(dut.pvx<=0) $fatal(1,"Left paddle collision failed");
        wait(dut.state==7);@(negedge clk);
        dut.px=320;dut.py=6;dut.pvx=3;dut.pvy=-4;
        step();
        if(dut.pvy<=0 || by<5) $fatal(1,"Wall bounce failed");
        wait(dut.state==7);@(negedge clk);
        dut.px=2;dut.py=400;dut.pvx=-3;dut.p1y=0;dut.p2y=0;
        step();
        if(rs!=1) $fatal(1,"Missed ball did not increment right score: %d",rs);
        for(i=0;i<300;i=i+1) begin
            buttons=auto_btn;
            step();
            if(left_y>378 || right_y>378 || by>=480 || bx>=640) $fatal(1,"Game bounds violated");
        end
        $display("TEST PASS: Pong movement, controls, pause, paddle/wall collisions, scoring and bounds");
        $finish;
    end
    initial begin repeat(100000) @(posedge clk);$fatal(1,"Game test timeout");end
endmodule
