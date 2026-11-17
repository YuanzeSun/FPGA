`timescale 1ns/1ps
module render_tb;
    reg clk=0;always #5 clk=~clk;
    reg resetn=0,de=1,paused=0,autoplay=1;
    reg [1:0] mode=0,state=0,lives=3;
    reg [7:0] score=0;
    reg [9:0] x=0,y=0,px=320,ox=300,oy=200;
    reg danger=0,serving=0;
    reg [23:0] bricks=24'hffffff;
    reg [14:0] aliens=15'h7fff;
    reg shot=0,enemy=0;
    reg [6:0] shield=0;
    wire [23:0] rgb;
    arcade_render dut(.clk(clk),.resetn(resetn),.x(x),.y(y),.de(de),.paused(paused),.autoplay(autoplay),.mode(mode),.state(state),.lives(lives),.score(score),.player_x(px),.object_x(ox),.object_y(oy),.danger(danger),.serving(serving),.bricks(bricks),.aliens(aliens),.formation_x(10'd144),.formation_y(10'd88),.shot_x(10'd200),.shot_y(10'd300),.enemy_x(10'd400),.enemy_y(10'd300),.shot_active(shot),.enemy_active(enemy),.shield(shield),.rgb(rgb));
    task pixel(input integer xx,yy,input [23:0] expected);
        begin x=xx;y=yy;#2;if(rgb!==expected)$fatal(1,"pixel (%0d,%0d) expected %h got %h",xx,yy,expected,rgb);end
    endtask
    integer n;
    initial begin
        repeat(3)@(negedge clk);resetn=1;
        for(n=0;n<100;n=n+1) begin
            score=n;repeat(3)@(negedge clk);
            if(dut.tens_digit!==n/10||dut.ones_digit!==n%10)$fatal(1,"decimal score %d",n);
        end
        score=0;repeat(3)@(negedge clk);
        pixel(0,0,24'h101e30);pixel(0,100,24'h25364c);
        pixel(320,438,24'h22d3ee);pixel(300,200,24'h67e8f9);
        danger=1;pixel(303,203,24'hfb7185);
        pixel(400,16,24'hf8fafc); // score 00, top bar of first digit
        mode=1;pixel(130,100,24'hfb7185);
        bricks=0;pixel(130,100,24'h080f1d);
        mode=2;pixel(147,91,24'hfb7185);
        aliens=0;pixel(147,91,24'h080f1d);
        shot=1;pixel(200,305,24'hf8fafc);
        enemy=1;pixel(400,305,24'hfb7185);
        pixel(320,440,24'h22d3ee);shield=4;pixel(320,440,24'h080f1d);
        paused=1;pixel(232,234,24'hf8fafc);
        paused=0;state=1;pixel(234,234,24'hfb7185);
        de=0;pixel(234,234,0);
        $display("TEST PASS: all 100 score conversions, shared glyphs, game sprites, shields, overlays, blanking");$finish;
    end
endmodule
