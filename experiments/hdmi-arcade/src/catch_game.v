// Catch cyan stars; avoid pink bombs. All coordinates update in vertical blank.
module catch_game(
    input wire clk, resetn, tick, left, right, autoplay,
    output reg [9:0] player_x, item_x, item_y,
    output reg danger,
    output reg [7:0] score,
    output reg [1:0] lives, state
);
    reg [15:0] random_bits;
    reg [5:0] spawn_count;
    reg [7:0] end_timer;
    wire ai_left = danger ? (item_x>=320 && player_x>80) : player_x>item_x+4;
    wire ai_right = danger ? (item_x<320 && player_x<560) : player_x+4<item_x;
    wire go_left=autoplay ? ai_left : left;
    wire go_right=autoplay ? ai_right : right;
    wire caught = item_x+10>=player_x-36 && item_x<=player_x+46;
    wire [9:0] spawn_x=10'd40+{1'b0,random_bits[8:0]};
    always @(posedge clk) begin
        if(!resetn) begin
            player_x<=320; item_x<=320; item_y<=64; danger<=0;
            score<=0; lives<=3; state<=0;
            random_bits<=16'hACE1; spawn_count<=0; end_timer<=0;
        end else if(tick) begin
            random_bits<={random_bits[14:0],random_bits[15]^random_bits[13]^random_bits[12]^random_bits[10]};
            if(state!=0) begin
                if(autoplay && end_timer==119) begin
                    player_x<=320; item_x<=320; item_y<=64; danger<=0;
                    score<=0; lives<=3; state<=0; end_timer<=0;
                end else if(end_timer<119) end_timer<=end_timer+1'b1;
            end else begin
                if(go_left&&!go_right) player_x<=player_x>45 ? player_x-6 : 40;
                if(go_right&&!go_left) player_x<=player_x<595 ? player_x+6 : 600;
                item_y<=item_y+3+{8'b0,score[5:4]};
                if(item_y>=422) begin
                    item_x<=spawn_x; item_y<=64;
                    danger<=spawn_count[1:0]==2; spawn_count<=spawn_count+1'b1;
                    if((danger&&caught)||(!danger&&!caught)) begin
                        lives<=lives-1'b1;
                        if(lives==1) begin state<=1; end_timer<=0; end
                    end else if(!danger&&caught) begin
                        if(score==98) begin score<=99; state<=2; end_timer<=0; end
                        else score<=score+1'b1;
                    end
                end
            end
        end
    end
endmodule
