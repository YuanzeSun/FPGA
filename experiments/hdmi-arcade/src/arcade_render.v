module arcade_render(
    input wire clk,resetn,
    input wire [9:0] x,y,
    input wire de, paused, autoplay,
    input wire [1:0] mode, state, lives,
    input wire [7:0] score,
    input wire [9:0] player_x, object_x, object_y,
    input wire danger, serving,
    input wire [23:0] bricks,
    input wire [14:0] aliens,
    input wire [9:0] formation_x, formation_y, shot_x, shot_y, enemy_x, enemy_y,
    input wire shot_active, enemy_active,
    input wire [6:0] shield,
    output reg [23:0] rgb
);
    // Seven rows, five bits per row, MSB first. Original small bitmap font.
    function [34:0] glyph;
        input [7:0] ch;
        begin
            case(ch)
                "A":glyph=35'b01110_10001_10001_11111_10001_10001_10001;
                "B":glyph=35'b11110_10001_10001_11110_10001_10001_11110;
                "C":glyph=35'b01111_10000_10000_10000_10000_10000_01111;
                "D":glyph=35'b11110_10001_10001_10001_10001_10001_11110;
                "E":glyph=35'b11111_10000_10000_11110_10000_10000_11111;
                "F":glyph=35'b11111_10000_10000_11110_10000_10000_10000;
                "G":glyph=35'b01111_10000_10000_10111_10001_10001_01111;
                "H":glyph=35'b10001_10001_10001_11111_10001_10001_10001;
                "I":glyph=35'b11111_00100_00100_00100_00100_00100_11111;
                "J":glyph=35'b00111_00010_00010_00010_10010_10010_01100;
                "K":glyph=35'b10001_10010_10100_11000_10100_10010_10001;
                "L":glyph=35'b10000_10000_10000_10000_10000_10000_11111;
                "M":glyph=35'b10001_11011_10101_10101_10001_10001_10001;
                "N":glyph=35'b10001_11001_11001_10101_10011_10011_10001;
                "O":glyph=35'b01110_10001_10001_10001_10001_10001_01110;
                "P":glyph=35'b11110_10001_10001_11110_10000_10000_10000;
                "R":glyph=35'b11110_10001_10001_11110_10100_10010_10001;
                "S":glyph=35'b01111_10000_10000_01110_00001_00001_11110;
                "T":glyph=35'b11111_00100_00100_00100_00100_00100_00100;
                "U":glyph=35'b10001_10001_10001_10001_10001_10001_01110;
                "V":glyph=35'b10001_10001_10001_10001_10001_01010_00100;
                "W":glyph=35'b10001_10001_10001_10101_10101_10101_01010;
                "Y":glyph=35'b10001_10001_01010_00100_00100_00100_00100;
                "0":glyph=35'b01110_10001_10011_10101_11001_10001_01110;
                "1":glyph=35'b00100_01100_00100_00100_00100_00100_01110;
                "2":glyph=35'b01110_10001_00001_00010_00100_01000_11111;
                "3":glyph=35'b11110_00001_00001_01110_00001_00001_11110;
                "4":glyph=35'b00010_00110_01010_10010_11111_00010_00010;
                "5":glyph=35'b11111_10000_10000_11110_00001_00001_11110;
                "6":glyph=35'b01110_10000_10000_11110_10001_10001_01110;
                "7":glyph=35'b11111_00001_00010_00100_01000_01000_01000;
                "8":glyph=35'b01110_10001_10001_01110_10001_10001_01110;
                "9":glyph=35'b01110_10001_10001_01111_00001_00001_01110;
                "/":glyph=35'b00001_00001_00010_00100_01000_10000_10000;
                default:glyph=0;
            endcase
        end
    endfunction
    wire signed [10:0] sx={1'b0,x},sy={1'b0,y};
    reg [95:0] title,status_text;
    // Score changes during blanking. Convert its bounded 0..99 value separately
    // from the pixel path, without a wide generic divide/modulo circuit.
    reg [7:0] score_latched;
    reg [3:0] tens_digit,ones_digit;
    wire [3:0] decimal_tens=score_latched>=90?9:score_latched>=80?8:
        score_latched>=70?7:score_latched>=60?6:score_latched>=50?5:
        score_latched>=40?4:score_latched>=30?3:score_latched>=20?2:
        score_latched>=10?1:0;
    wire [7:0] tens_times_ten={1'b0,decimal_tens,3'b0}+{3'b0,decimal_tens,1'b0};
    always @(posedge clk) begin
        if(!resetn) begin score_latched<=0;tens_digit<=0;ones_digit<=0;end
        else begin
            score_latched<=score; tens_digit<=decimal_tens;
            ones_digit<=score_latched-tens_times_ten;
        end
    end
    wire [7:0] tens=8'd48+{4'b0,tens_digit}, ones=8'd48+{4'b0,ones_digit};
    wire [10:0] alien_dx={1'b0,x}-{1'b0,formation_x};
    wire [10:0] alien_dy={1'b0,y}-{1'b0,formation_y};
    // Share one character ROM across all HUD/overlay regions. Coordinates and
    // character indices have explicit small widths; no replicated wide shifts.
    wire [7:0] title_dx=x-10'd18, score_dx=x-10'd300;
    wire [7:0] overlay_dx=x-10'd232;
    reg [95:0] overlay_word;
    reg [7:0] letter;
    reg [3:0] letter_x;
    reg [2:0] letter_y;
    reg letter_enabled;
    reg [23:0] letter_color;
    wire [34:0] letter_bits=glyph(letter);
    wire [5:0] font_bit=6'd34-({3'b0,letter_y}<<2)-{3'b0,letter_y}-{3'b0,letter_x[3:1]};
    wire letter_pixel=letter_enabled&&letter_x<10&&letter_bits[font_bit];
    always @* begin
        letter=0;letter_x=0;letter_y=0;letter_enabled=0;letter_color=24'h94a3b8;
        overlay_word=0;
        if(y>=16&&y<30) begin
            letter_enabled=1;letter_y=(y-10'd16)>>1;
            if(x>=18&&x<210) begin
                letter=title[95-title_dx[7:4]*8-:8];letter_x=title_dx[3:0];letter_color=24'h67e8f9;
            end else if(x>=240&&x<250) begin
                letter=8'd49+{6'b0,mode};letter_x=x-10'd240;letter_color=24'ha78bfa;
            end else if(x>=300&&x<380) begin
                case(score_dx[6:4])
                    0:letter="S";1:letter="C";2:letter="O";3:letter="R";4:letter="E";default:letter=0;
                endcase
                letter_x=score_dx[3:0];
            end else if(x>=396&&x<406) begin
                letter=tens;letter_x=x-10'd396;letter_color=24'hf8fafc;
            end else if(x>=412&&x<422) begin
                letter=ones;letter_x=x-10'd412;letter_color=24'hf8fafc;
            end else if(x>=484&&x<494) begin letter="L";letter_x=x-10'd484;end
            else letter_enabled=0;
        end
        if((paused||state!=0||serving)&&x>=232&&x<424) begin
            if(y>=234&&y<248) begin
                overlay_word=status_text;letter_enabled=1;letter_y=(y-10'd234)>>1;
                letter_color=state==1?24'hfb7185:24'hf8fafc;
            end else if(y>=258&&y<272) begin
                overlay_word="R RESTART   ";letter_enabled=1;letter_y=(y-10'd258)>>1;
            end
            if(overlay_word!=0) begin letter=overlay_word[95-overlay_dx[7:4]*8-:8];letter_x=overlay_dx[3:0];end
        end
    end
    integer i;
    reg [23:0] brick_color;
    always @* begin
        case(mode)
            0:title="CATCH       ";
            1:title="BRICKS      ";
            default:title="INVADERS    ";
        endcase
        if(paused) status_text="PAUSED      ";
        else if(state==2) status_text="YOU WIN     ";
        else if(state==1) status_text="GAME OVER   ";
        else status_text="READY F/J   ";
        rgb=24'h080f1d; brick_color=0;
        if(mode==2 && x[5:0]==y[5:0] && x[2:0]==3 && y[4:0]==19) rgb=24'h475569;
        if(x<3 || x>=637 || y>=477 || (y>=46&&y<49)) rgb=24'h25364c;
        if(mode==0) begin
            if(y>=450&&y<452) rgb=24'h1e3a5f;
            if(x+36>=player_x&&x<player_x+36&&y>=434&&y<446) rgb=24'h22d3ee;
            if((x+36>=player_x&&x+29<player_x || x>=player_x+29&&x<player_x+36)&&y>=425&&y<440) rgb=24'h22d3ee;
            if(x+9>=object_x&&x<object_x+9&&y+9>=object_y&&y<object_y+9) begin
                if(danger) begin
                    rgb=24'hfb7185;
                    if((x==object_x||y==object_y)) rgb=24'hf8fafc;
                end else if((x+3>=object_x&&x<object_x+3)||(y+3>=object_y&&y<object_y+3)) rgb=24'h67e8f9;
            end
        end else if(mode==1) begin
            for(i=0;i<24;i=i+1) begin
                case(i/6)
                    0:brick_color=24'hfb7185;
                    1:brick_color=24'hfbbf24;
                    2:brick_color=24'ha78bfa;
                    3:brick_color=24'h22d3ee;
                endcase
                if(bricks[i]&&x>=128+(i%6)*64&&x<186+(i%6)*64&&y>=88+(i/6)*24&&y<106+(i/6)*24)
                    rgb=brick_color;
            end
            if(x+40>=player_x&&x<player_x+40&&y>=440&&y<451) rgb=24'h22d3ee;
            if(x+5>=object_x&&x<object_x+5&&y+5>=object_y&&y<object_y+5) rgb=24'hf8fafc;
        end else begin
            for(i=0;i<15;i=i+1) begin
                if(aliens[i] && alien_dx>=(i%5)*44 && alien_dx<(i%5)*44+28 && alien_dy>=(i/5)*32 && alien_dy<(i/5)*32+24) begin
                    rgb=(i<5)?24'hfb7185:(i<10)?24'ha78bfa:24'h4ade80;
                    if((alien_dx==(i%5)*44+7 || alien_dx==(i%5)*44+20)&&alien_dy>=(i/5)*32+7&&alien_dy<(i/5)*32+13) rgb=24'h080f1d;
                    if(alien_dy>=(i/5)*32+19&&alien_dx>=(i%5)*44+7&&alien_dx<(i%5)*44+21) rgb=24'h080f1d;
                end
            end
            if(!shield[2] && y>=426&&y<449&&x+16>=player_x&&x<player_x+16) begin
                if(y>=437||(x+5>=player_x&&x<player_x+5)) rgb=24'h22d3ee;
            end
            if(shot_active&&x+2>=shot_x&&x<shot_x+2&&y>=shot_y&&y<shot_y+10) rgb=24'hf8fafc;
            if(enemy_active&&x+3>=enemy_x&&x<enemy_x+3&&y>=enemy_y&&y<enemy_y+12) rgb=24'hfb7185;
        end
        if(y<46) begin
            rgb=24'h101e30;
            for(i=0;i<3;i=i+1)
                if(i<lives && x>=516+i*23&&x<530+i*23&&y>=17&&y<29) rgb=24'hfb7185;
            if(x>=610&&x<622&&y>=17&&y<29) rgb=autoplay?24'h4ade80:24'hfbbf24;
        end
        if(paused||state!=0||serving) begin
            if(x>=208&&x<432&&y>=218&&y<280) begin
                rgb=24'h1e293b;
            end
        end
        if(letter_pixel) rgb=letter_color;
        if(!de) rgb=0;
    end
endmodule
