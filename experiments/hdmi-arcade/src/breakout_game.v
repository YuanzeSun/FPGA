// 24 bricks; one collision per frame. No framebuffer or CPU.
module breakout_game(
    input wire clk, resetn, tick, left, right, fire, autoplay,
    output reg [9:0] player_x, ball_x, ball_y,
    output reg [23:0] bricks,
    output reg [7:0] score,
    output reg [1:0] lives, state,
    output reg serving
);
    reg moving_right,moving_down;
    reg [7:0] timer;
    integer i, hit_index;
    integer nx,ny,bx,by;
    reg [9:0] hit_top;
    wire go_left=autoplay ? player_x>ball_x+4 : left;
    wire go_right=autoplay ? player_x+4<ball_x : right;
    always @* begin
        nx=moving_right ? {22'b0,ball_x}+4 : {22'b0,ball_x}-4;
        ny=moving_down ? {22'b0,ball_y}+5 : {22'b0,ball_y}-5;
        hit_index=-1; bx=0; by=0; hit_top=0;
        for(i=0;i<24;i=i+1) begin
            bx=128+(i%6)*64; by=88+(i/6)*24;
            if(bricks[i] && nx+5>=bx && nx-5<bx+58 && ny+5>=by && ny-5<by+18 && hit_index==-1) begin
                hit_index=i; hit_top=by;
            end
        end
    end
    always @(posedge clk) begin
        if(!resetn) begin
            player_x<=320; ball_x<=320; ball_y<=425; bricks<=24'hFFFFFF;
            score<=0; lives<=3; state<=0; serving<=1;
            moving_right<=1; moving_down<=0; timer<=0;
        end else if(tick) begin
            if(state!=0) begin
                if(autoplay && timer==119) begin
                    player_x<=320; ball_x<=320; ball_y<=425; bricks<=24'hFFFFFF;
                    score<=0; lives<=3; state<=0; serving<=1;
                    moving_right<=1; moving_down<=0; timer<=0;
                end else if(timer<119) timer<=timer+1'b1;
            end else begin
                if(go_left&&!go_right) player_x<=player_x>49 ? player_x-7 : 42;
                if(go_right&&!go_left) player_x<=player_x<591 ? player_x+7 : 598;
                if(serving) begin
                    ball_x<=player_x; ball_y<=425;
                    if(fire || (autoplay&&timer>=44)) begin serving<=0; timer<=0; end
                    else if(timer<44) timer<=timer+1'b1;
                end else begin
                    ball_x<=nx[9:0]; ball_y<=ny[9:0];
                    if(nx<=10) begin ball_x<=10; moving_right<=1; end
                    else if(nx>=630) begin ball_x<=630; moving_right<=0; end
                    if(ny<=60) begin ball_y<=60; moving_down<=1; end
                    if(hit_index!=-1) begin
                        bricks[hit_index]<=0; moving_down<=!moving_down;
                        // Push outside the brick so the next step cannot hit it twice.
                        if(moving_down) ball_y<=hit_top-6;
                        else ball_y<=hit_top+24;
                        score<=score+1'b1;
                        if((bricks & (bricks-1'b1))==0) begin state<=2; timer<=0; end
                    end
                    if(moving_down && ball_y<435 && ny>=435 && nx+5>=player_x-40 && nx-5<player_x+40) begin
                        ball_y<=434; moving_down<=0; moving_right<=nx>=player_x;
                    end
                    if(ny>=478) begin
                        lives<=lives-1'b1; serving<=1; timer<=0;
                        ball_x<=player_x; ball_y<=425; moving_down<=0;
                        if(lives==1) state<=1;
                    end
                end
            end
        end
    end
endmodule
