`timescale 1ns/1ps
module games_tb;
    reg clk=0,resetn=0,tick=0,left=0,right=0,fire=0,autoplay=0;
    always #5 clk=~clk;
    wire [9:0] cp,cx,cy,bp,bx,by,ip,ix,iy,sx,sy,ex,ey;
    wire [7:0] cs,bs,isc;
    wire [1:0] cl,bl,il,ct,bt,it;
    wire danger,serving,shot,enemy;
    wire [23:0] bricks;
    wire [14:0] aliens;
    wire [6:0] shield;
    catch_game c(clk,resetn,tick,left,right,autoplay,cp,cx,cy,danger,cs,cl,ct);
    breakout_game b(clk,resetn,tick,left,right,fire,autoplay,bp,bx,by,bricks,bs,bl,bt,serving);
    invaders_game s(clk,resetn,tick,left,right,fire,autoplay,ip,ix,iy,aliens,shot,enemy,sx,sy,ex,ey,isc,il,it,shield);
    task step; begin @(negedge clk);tick=1;@(negedge clk);tick=0;end endtask
    task reset; begin @(negedge clk); resetn=0;repeat(3)@(negedge clk);resetn=1;end endtask
    integer i;
    reg [9:0] held;
    initial begin
        reset();
        if(cp!=320||cl!=3||bricks!=24'hffffff||aliens!=15'h7fff||!serving) $fatal(1,"reset state");
        repeat(20)@(negedge clk);
        if(cy!=64||bx!=320||iy!=88) $fatal(1,"no tick hold");
        left=1;repeat(120)step();left=0;
        if(cp!=40||bp!=42||ip!=24) $fatal(1,"left limits %d %d %d",cp,bp,ip);
        right=1;repeat(180)step();right=0;
        if(cp!=600||bp!=598||ip!=616) $fatal(1,"right limits");
        reset();
        @(negedge clk); c.item_x=320;c.item_y=423;c.danger=0;
        step();if(cs!=1||cl!=3||cy!=64) $fatal(1,"catch star");
        @(negedge clk); c.item_x=320;c.item_y=423;c.danger=1;
        step();if(cs!=1||cl!=2) $fatal(1,"bomb hit");
        @(negedge clk); c.item_x=80;c.item_y=423;c.danger=0;
        step();if(cl!=1) $fatal(1,"miss life");
        @(negedge clk); c.item_x=80;c.item_y=423;c.danger=0;
        step();if(ct!=1||cl!=0) $fatal(1,"catch game over");
        held=cx;repeat(30)step();if(cx!=held||cl!=0) $fatal(1,"terminal state hold");
        reset();@(negedge clk);c.score=98;c.item_x=320;c.item_y=423;
        step();if(cs!=99||ct!=2) $fatal(1,"catch win");
        reset();fire=1;step();fire=0;if(serving) $fatal(1,"launch");
        @(negedge clk);b.ball_x=131;b.ball_y=135;b.moving_down=0;b.moving_right=1;
        step();if(bricks[6]||bs!=1||!b.moving_down) $fatal(1,"brick hit");
        @(negedge clk);b.ball_x=318;b.ball_y=432;b.moving_down=1;
        step();if(b.moving_down||by!=434) $fatal(1,"paddle bounce");
        @(negedge clk);b.ball_x=12;b.ball_y=200;b.moving_right=0;
        step();if(bx!=10||!b.moving_right) $fatal(1,"wall bounce");
        @(negedge clk);b.ball_y=475;b.ball_x=20;b.moving_down=1;
        step();if(bl!=2||!serving) $fatal(1,"ball miss");
        @(negedge clk);b.serving=0;b.lives=1;b.ball_y=475;b.moving_down=1;
        step();if(bt!=1||bl!=0) $fatal(1,"bricks game over");
        reset();@(negedge clk);b.serving=0;b.bricks=1;b.ball_x=131;b.ball_y=111;b.moving_down=0;
        step();if(bt!=2||bricks!=0||bs!=1) $fatal(1,"bricks win");
        reset();fire=1;step();fire=0;
        if(!shot||sx!=320||sy!=424) $fatal(1,"player fire");
        @(negedge clk);s.shot_active=1;s.shot_x=150;s.shot_y=108;
        step();if(aliens[0]||shot||isc!=1) $fatal(1,"alien hit");
        @(negedge clk);s.enemy_active=1;s.enemy_x=320;s.enemy_y=422;
        step();if(il!=2||shield==0||enemy) $fatal(1,"enemy hit");
        @(negedge clk);s.enemy_active=1;s.enemy_x=320;s.enemy_y=422;
        step();if(il!=2) $fatal(1,"invulnerability");
        @(negedge clk);s.shield=0;s.lives=1;s.enemy_active=1;s.enemy_x=320;s.enemy_y=422;
        step();if(il!=0||it!=1) $fatal(1,"invaders game over");
        reset();@(negedge clk);s.aliens=1;s.shot_active=1;s.shot_x=150;s.shot_y=108;
        step();if(it!=2||aliens!=0||isc!=1) $fatal(1,"invaders win");
        reset();@(negedge clk);s.formation_x=414;s.march_timer=5;
        step();if(s.march_right||iy!=104) $fatal(1,"formation edge drop");
        @(negedge clk);s.formation_y=360;
        step();if(it!=1) $fatal(1,"invasion game over");
        reset();autoplay=1;
        for(i=0;i<8000;i=i+1) begin
            step();
            if(^({cp,cx,cy,bp,bx,by,ip,ix,iy,cs,bs,isc,cl,bl,il})===1'bx) $fatal(1,"unknown state");
            if(cp<40||cp>600||cx<40||cx>551||cy>432||bp<42||bp>598||bx>635||by>478||ip<24||ip>616||ix<24||ix>414) $fatal(1,"bounds frame %d",i);
            if(cl>3||bl>3||il>3||cs>99||bs>24||isc>15) $fatal(1,"score/life range");
        end
        $display("TEST PASS: 3 games, collisions, scoring, lives, win/loss, serving, shields, boundaries, 8000 demo frames");
        $finish;
    end
    initial begin #10000000;$fatal(1,"timeout");end
endmodule
