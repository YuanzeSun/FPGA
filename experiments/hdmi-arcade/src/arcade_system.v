module arcade_system #(parameter EXTERNAL_TIMING=0)(
    input wire clk,resetn,ser_rx,
    output wire ser_tx,
    output wire [23:0] rgb,
    output wire de,hsync,vsync,
    output reg paused,autoplay,
    output reg [1:0] mode,
    output reg [31:0] frame_count,rx_count,
    output wire [7:0] score,
    output wire [1:0] lives,state,
    output wire [9:0] player_x,object_x,object_y,
    input wire video_tick,
    input wire [9:0] video_x,video_y
);
    wire [9:0] x,y;
    wire internal_frame_tick;
    wire frame_tick=EXTERNAL_TIMING?video_tick:internal_frame_tick;
    video_timing timing(.clk(clk),.resetn(resetn),.x(x),.y(y),.de(de),.hsync(hsync),.vsync(vsync),.frame_tick(internal_frame_tick));
    reg restart;
    reg [3:0] hold_frames;
    reg [2:0] buttons;
    wire tick=frame_tick&&!paused;
    wire [9:0] cp,cx,cy,bp,bx,by,ip,ix,iy,shot_x,shot_y,enemy_x,enemy_y;
    wire [7:0] cs,bs,iscore;
    wire [1:0] cl,bl,il,ct,bt,it;
    wire danger,serving,shot_active,enemy_active;
    wire [23:0] bricks;
    wire [14:0] aliens;
    wire [6:0] shield;
    catch_game catch_logic(.clk(clk),.resetn(resetn&&!restart&&mode==0),.tick(tick),.left(buttons[0]),.right(buttons[1]),.autoplay(autoplay),.player_x(cp),.item_x(cx),.item_y(cy),.danger(danger),.score(cs),.lives(cl),.state(ct));
    breakout_game breakout_logic(.clk(clk),.resetn(resetn&&!restart&&mode==1),.tick(tick),.left(buttons[0]),.right(buttons[1]),.fire(buttons[2]),.autoplay(autoplay),.player_x(bp),.ball_x(bx),.ball_y(by),.bricks(bricks),.score(bs),.lives(bl),.state(bt),.serving(serving));
    invaders_game invaders_logic(.clk(clk),.resetn(resetn&&!restart&&mode==2),.tick(tick),.left(buttons[0]),.right(buttons[1]),.fire(buttons[2]),.autoplay(autoplay),.player_x(ip),.formation_x(ix),.formation_y(iy),.aliens(aliens),.shot_active(shot_active),.enemy_active(enemy_active),.shot_x(shot_x),.shot_y(shot_y),.enemy_x(enemy_x),.enemy_y(enemy_y),.score(iscore),.lives(il),.state(it),.shield(shield));
    assign player_x=mode==0?cp:mode==1?bp:ip;
    assign object_x=mode==0?cx:mode==1?bx:ix;
    assign object_y=mode==0?cy:mode==1?by:iy;
    assign score=mode==0?cs:mode==1?bs:iscore;
    assign lives=mode==0?cl:mode==1?bl:il;
    assign state=mode==0?ct:mode==1?bt:it;
    arcade_render renderer(.clk(clk),.resetn(resetn),.x(EXTERNAL_TIMING?video_x:x),.y(EXTERNAL_TIMING?video_y:y),.de(EXTERNAL_TIMING?1'b1:de),.paused(paused),.autoplay(autoplay),.mode(mode),.state(state),.lives(lives),.score(score),.player_x(player_x),.object_x(object_x),.object_y(object_y),.danger(danger),.serving(serving&&mode==1),.bricks(bricks),.aliens(aliens),.formation_x(ix),.formation_y(iy),.shot_x(shot_x),.shot_y(shot_y),.enemy_x(enemy_x),.enemy_y(enemy_y),.shot_active(shot_active),.enemy_active(enemy_active),.shield(shield),.rgb(rgb));
    reg [1:0] rx_sync=2'b11;
    reg configured;
    wire [31:0] uart_rx;
    wire uart_wait;
    wire command_valid=resetn&&configured&&uart_rx!=32'hffffffff;
    wire [7:0] command=uart_rx[7:0];
    reg [7:0] last_command;
    reg report_active,report_pending,request_d;
    reg [6:0] char_index;
    wire [7:0] tx_character;
    simpleuart uart(.clk(clk),.resetn(resetn),.ser_rx(rx_sync[1]),.ser_tx(ser_tx),
        .reg_div_we((resetn&&!configured)?4'hf:4'h0),.reg_div_di(32'd217),.reg_div_do(),
        .reg_dat_re(command_valid),.reg_dat_do(uart_rx),.reg_dat_we(report_active&&configured),.reg_dat_di({24'b0,tx_character}),.reg_dat_wait(uart_wait));
    reg [5:0] heartbeat;
    wire heartbeat_tick=frame_tick&&heartbeat==59;
    always @(posedge clk) begin
        if(!resetn) begin
            rx_sync<=3; configured<=0; paused<=0; autoplay<=1; mode<=0; restart<=0;
            hold_frames<=0; buttons<=0; frame_count<=0; rx_count<=0; last_command<=0; heartbeat<=0;
        end else begin
            rx_sync<={rx_sync[0],ser_rx}; configured<=1; restart<=0;
            if(frame_tick) begin
                frame_count<=frame_count+1'b1;
                heartbeat<=heartbeat==59?0:heartbeat+1'b1;
                if(hold_frames!=0) hold_frames<=hold_frames-1'b1;
                if(hold_frames==1) buttons<=0;
            end
            if(command_valid) begin
                rx_count<=rx_count+1'b1; last_command<=command;
                if(command[7]) begin
                    buttons<=command[2:0]; hold_frames<=12;
                    if(command[2:0]!=0) autoplay<=0;
                end else case(command)
                    "1","2","3":begin mode<=command-8'd49; restart<=1; paused<=0; buttons<=0; hold_frames<=0; end
                    "m":begin autoplay<=0; buttons<=0; hold_frames<=0; end
                    "a":begin autoplay<=!autoplay; buttons<=0; hold_frames<=0; end
                    "p":paused<=!paused;
                    "r":begin restart<=1; paused<=0; buttons<=0; hold_frames<=0; end
                    default:begin end
                endcase
            end
        end
    end
    reg [31:0] snap_frames,snap_rx_count;
    reg [7:0] snap_score,snap_command;
    reg [1:0] snap_mode,snap_lives,snap_state;
    reg [9:0] snap_player_x,snap_object_x,snap_object_y;
    reg snap_autoplay,snap_paused;
    // Wait three cycles after a command so restart has propagated through games.
    reg [2:0] report_delay;
    wire start_report=!report_active&&report_pending&&configured&&report_delay==0;
    always @(posedge clk) begin
        if(!resetn) begin
            report_delay<=0; request_d<=0; report_pending<=0; report_active<=0; char_index<=0;
            snap_frames<=0; snap_rx_count<=0; snap_score<=0; snap_command<=0;
            snap_mode<=0; snap_lives<=0; snap_state<=0; snap_player_x<=0; snap_object_x<=0; snap_object_y<=0;
            snap_autoplay<=0; snap_paused<=0;
        end else begin
            request_d<=command_valid||heartbeat_tick;
            if(command_valid) report_delay<=3;
            else if(report_delay!=0) report_delay<=report_delay-1'b1;
            if(start_report) report_pending<=request_d;
            else if(request_d) report_pending<=1;
            if(start_report) begin
                report_active<=1; char_index<=0;
                snap_frames<=frame_count; snap_rx_count<=rx_count; snap_score<=score; snap_command<=last_command;
                snap_mode<=mode; snap_lives<=lives; snap_state<=state;
                snap_player_x<=player_x; snap_object_x<=object_x; snap_object_y<=object_y;
                snap_autoplay<=autoplay; snap_paused<=paused;
            end else if(report_active&&!uart_wait) begin
                if(char_index==MESSAGE_LENGTH-1) begin report_active<=0; char_index<=0; end
                else char_index<=char_index+1'b1;
            end
        end
    end
    function [7:0] hex_digit;
        input [3:0] value;
        begin hex_digit=value<10?8'd48+value:8'd55+value; end
    endfunction
    `include "telemetry_format.vh"
    assign tx_character=message_char(char_index);
endmodule
