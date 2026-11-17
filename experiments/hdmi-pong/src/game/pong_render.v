module pong_render (
    input wire [9:0] x, y,
    input wire de, paused, autoplay,
    input wire [11:0] left_y, right_y, ball_x, ball_y,
    input wire [6:0] left_score, right_score,
    output reg [23:0] rgb
);
    function [6:0] segments;
        input [3:0] digit;
        begin
            case (digit)
                0: segments=7'b1111110; 1: segments=7'b0110000;
                2: segments=7'b1101101; 3: segments=7'b1111001;
                4: segments=7'b0110011; 5: segments=7'b1011011;
                6: segments=7'b1011111; 7: segments=7'b1110000;
                8: segments=7'b1111111; 9: segments=7'b1111011;
                default: segments=0;
            endcase
        end
    endfunction
    function digit_pixel;
        input integer dx, dy;
        input [3:0] number;
        reg [6:0] s;
        begin
            s=segments(number);
            digit_pixel=0;
            if (dx>=0 && dx<20 && dy>=0 && dy<36) begin
                if (s[6] && dx>=3 && dx<17 && dy<3) digit_pixel=1;
                if (s[5] && dx>=17 && dy>=3 && dy<17) digit_pixel=1;
                if (s[4] && dx>=17 && dy>=19 && dy<33) digit_pixel=1;
                if (s[3] && dx>=3 && dx<17 && dy>=33) digit_pixel=1;
                if (s[2] && dx<3 && dy>=19 && dy<33) digit_pixel=1;
                if (s[1] && dx<3 && dy>=3 && dy<17) digit_pixel=1;
                if (s[0] && dx>=3 && dx<17 && dy>=17 && dy<20) digit_pixel=1;
            end
        end
    endfunction
    wire left_digit = digit_pixel($signed({1'b0,x})-80, $signed({1'b0,y})-24, left_score/10) ||
                      digit_pixel($signed({1'b0,x})-108,$signed({1'b0,y})-24, left_score%10);
    wire right_digit = digit_pixel($signed({1'b0,x})-512,$signed({1'b0,y})-24,right_score/10) ||
                       digit_pixel($signed({1'b0,x})-540,$signed({1'b0,y})-24,right_score%10);
    always @* begin
        rgb=24'h0b1220;
        if (x<2 || x>=638 || y<2 || y>=478) rgb=24'h334155;
        if (x>=319 && x<321 && !y[4]) rgb=24'h334155;
        if (left_digit) rgb=24'h22d3ee;
        if (right_digit) rgb=24'hfb7185;
        if (x>=314 && x<326 && y>=26 && y<38)
            rgb=autoplay ? 24'h22c55e : 24'hf59e0b;
        if (x>=10 && x<20 && y>=left_y && y<left_y+100) rgb=24'h22d3ee;
        if (x>=620 && x<630 && y>=right_y && y<right_y+100) rgb=24'hfb7185;
        if (x+5>=ball_x && x<ball_x+5 && y+5>=ball_y && y<ball_y+5) rgb=24'hf8fafc;
        if (paused && x>=280 && x<360 && y>=210 && y<270) begin
            rgb=24'h334155;
            if (((x>=301 && x<312) || (x>=328 && x<339)) && y>=222 && y<258) rgb=24'hf8fafc;
        end
        if (!de) rgb=0;
    end
endmodule
