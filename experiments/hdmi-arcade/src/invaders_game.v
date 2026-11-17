// Fifteen aliens, player/enemy projectiles, march/drop and invulnerability.
module invaders_game(
    input wire clk, resetn, tick, left, right, fire, autoplay,
    output reg [9:0] player_x, formation_x, formation_y,
    output reg [14:0] aliens,
    output reg shot_active, enemy_active,
    output reg [9:0] shot_x, shot_y, enemy_x, enemy_y,
    output reg [7:0] score,
    output reg [1:0] lives, state,
    output reg [6:0] shield
);
    reg march_right;
    reg [3:0] march_timer;
    reg [6:0] fire_timer, enemy_timer;
    reg [7:0] end_timer;
    reg [15:0] random_bits;
    integer i,hit_index,target_index,enemy_index;
    integer ax,ay,target_x,chosen_column;
    reg [9:0] enemy_spawn_x,enemy_spawn_y;
    reg reached_bottom;
    always @* begin
        hit_index=-1; target_index=-1; enemy_index=-1; reached_bottom=0;
        chosen_column={29'b0,random_bits[2:0]};
        if(chosen_column>=5) chosen_column=chosen_column-5;
        ax=0; ay=0; target_x=320; enemy_spawn_x=320; enemy_spawn_y=112;
        for(i=0;i<15;i=i+1) begin
            ax={22'b0,formation_x}+(i%5)*44; ay={22'b0,formation_y}+(i/5)*32;
            if(aliens[i]) begin
                if(target_index==-1) begin
                    target_index=i; target_x=ax+14;
                    enemy_spawn_x=ax+14; enemy_spawn_y=ay+26;
                end
                if(i%5==chosen_column) begin
                    enemy_index=i;
                    enemy_spawn_x=ax+14; enemy_spawn_y=ay+26;
                end
                if(ay+24>=424) reached_bottom=1;
                if(shot_active && shot_x+2>=ax && shot_x<ax+28 && shot_y<=ay+29 && shot_y+8>=ay && hit_index==-1)
                    hit_index=i;
            end
        end
        if(enemy_index==-1) enemy_index=target_index;
    end
    wire go_left=autoplay ? {22'b0,player_x}>target_x+3 : left;
    wire go_right=autoplay ? {22'b0,player_x}+3<target_x : right;
    always @(posedge clk) begin
        if(!resetn) begin
            player_x<=320; formation_x<=144; formation_y<=88; aliens<=15'h7FFF;
            shot_active<=0; enemy_active<=0; shot_x<=0; shot_y<=0; enemy_x<=0; enemy_y<=0;
            score<=0; lives<=3; state<=0; shield<=0;
            march_right<=1; march_timer<=0; fire_timer<=0; enemy_timer<=0; end_timer<=0; random_bits<=16'hBEEF;
        end else if(tick) begin
            random_bits<={random_bits[14:0],random_bits[15]^random_bits[13]^random_bits[12]^random_bits[10]};
            if(state!=0) begin
                if(autoplay&&end_timer==119) begin
                    player_x<=320; formation_x<=144; formation_y<=88; aliens<=15'h7FFF;
                    shot_active<=0; enemy_active<=0; score<=0; lives<=3; state<=0; shield<=0;
                    march_right<=1; march_timer<=0; fire_timer<=0; enemy_timer<=0; end_timer<=0;
                end else if(end_timer<119) end_timer<=end_timer+1'b1;
            end else begin
                if(go_left&&!go_right) player_x<=player_x>30 ? player_x-6 : 24;
                if(go_right&&!go_left) player_x<=player_x<610 ? player_x+6 : 616;
                if(shield!=0) shield<=shield-1'b1;
                if(fire_timer!=0) fire_timer<=fire_timer-1'b1;
                if(march_timer==5) begin
                    march_timer<=0;
                    if(march_right) begin
                        if(formation_x>=414) begin march_right<=0; formation_y<=formation_y+16; end
                        else formation_x<=formation_x+6;
                    end else begin
                        if(formation_x<=24) begin march_right<=1; formation_y<=formation_y+16; end
                        else formation_x<=formation_x-6;
                    end
                end else march_timer<=march_timer+1'b1;
                if(!shot_active && (fire||autoplay) && fire_timer==0) begin
                    shot_active<=1; shot_x<=player_x; shot_y<=424; fire_timer<=12;
                end else if(shot_active) begin
                    if(shot_y<=64) shot_active<=0;
                    else shot_y<=shot_y-10;
                    if(hit_index!=-1) begin
                        aliens[hit_index]<=0; shot_active<=0; score<=score+1'b1;
                        if((aliens & (aliens-1'b1))==0) begin state<=2; end_timer<=0; end
                    end
                end
                if(enemy_timer<89) enemy_timer<=enemy_timer+1'b1;
                if(!enemy_active && enemy_timer==89 && enemy_index!=-1) begin
                    enemy_active<=1; enemy_timer<=0;
                    enemy_x<=enemy_spawn_x;
                    enemy_y<=enemy_spawn_y;
                end else if(enemy_active) begin
                    enemy_y<=enemy_y+6;
                    if(enemy_y>=472) enemy_active<=0;
                    if(shield==0 && enemy_y+12>=426 && enemy_y<450 && enemy_x+3>=player_x-16 && enemy_x<player_x+16) begin
                        enemy_active<=0; lives<=lives-1'b1; shield<=90;
                        if(lives==1) begin state<=1; end_timer<=0; end
                    end
                end
                if(reached_bottom) begin state<=1; end_timer<=0; end
            end
        end
    end
endmodule
