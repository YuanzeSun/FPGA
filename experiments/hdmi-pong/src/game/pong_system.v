module pong_system #(parameter EXTERNAL_TIMING=0) (
    input wire clk, resetn, ser_rx,video_tick,
    output wire ser_tx,
    output wire [23:0] rgb,
    output wire de, hsync, vsync,
    output reg paused, autoplay,
    output reg [31:0] frame_count, rx_count,
    output wire [11:0] left_y, right_y, ball_x, ball_y,
    output wire [6:0] left_score, right_score
);
    wire [9:0] x,y;
    wire internal_frame_tick;
    wire frame_tick=EXTERNAL_TIMING?video_tick:internal_frame_tick;
    video_timing timing(.clk(clk),.resetn(resetn),.x(x),.y(y),.de(de),.hsync(hsync),.vsync(vsync),.frame_tick(internal_frame_tick));
    reg restart;
    reg [3:0] hold_frames;
    reg move_up, move_down;
    reg [7:0] last_command;
    wire [3:0] auto_buttons;
    reg auto_ready;
    wire [3:0] safe_auto_buttons=auto_ready ? auto_buttons : 4'b0000;
    wire [1:0] left_buttons=autoplay ? safe_auto_buttons[3:2] : {move_down,move_up};
    svo_pong_control #(.SVO_MODE("640x480")) game_logic (
        .clk(clk),.resetn(resetn&&!restart),.enable(frame_tick&&!paused),
        .btn({left_buttons,safe_auto_buttons[1:0]}),.auto_btn(auto_buttons),
        .flash(),.p1_pos(left_y),.p2_pos(right_y),
        .p1_points(left_score),.p2_points(right_score),.puck_x(ball_x),.puck_y(ball_y)
    );
    pong_render renderer(.x(x),.y(y),.de(de),.paused(paused),.autoplay(autoplay),
        .left_y(left_y),.right_y(right_y),.ball_x(ball_x),.ball_y(ball_y),
        .left_score(left_score),.right_score(right_score),.rgb(rgb));

    reg [1:0] rx_sync=2'b11;
    reg configured;
    wire [31:0] uart_rx, uart_div;
    wire uart_wait;
    wire command_valid=resetn && configured && uart_rx!=32'hffffffff;
    wire [7:0] command=uart_rx[7:0];
    reg report_active, report_pending, request_d;
    reg [6:0] char_index;
    wire [7:0] tx_character;
    simpleuart uart(
        .clk(clk),.resetn(resetn),.ser_rx(rx_sync[1]),.ser_tx(ser_tx),
        .reg_div_we((resetn&&!configured)?4'hf:4'h0),.reg_div_di(32'd217),.reg_div_do(uart_div),
        .reg_dat_re(command_valid),.reg_dat_do(uart_rx),
        .reg_dat_we(report_active&&configured),.reg_dat_di({24'b0,tx_character}),.reg_dat_wait(uart_wait)
    );
    reg [5:0] heartbeat;
    wire heartbeat_tick=frame_tick && heartbeat==59;
    always @(posedge clk) begin
        if (!resetn) begin
            rx_sync<=2'b11; configured<=0;
            paused<=0; autoplay<=1; restart<=0; auto_ready<=0;
            hold_frames<=0; move_up<=0; move_down<=0;
            frame_count<=0; rx_count<=0; last_command<=0; heartbeat<=0;
        end else begin
            rx_sync<={rx_sync[0],ser_rx}; configured<=1; restart<=0;
            if (restart) auto_ready<=0;
            else if (frame_tick&&!paused) auto_ready<=1;
            if (frame_tick) begin
                frame_count<=frame_count+1'b1;
                if (heartbeat==59) heartbeat<=0; else heartbeat<=heartbeat+1'b1;
                if (hold_frames!=0) hold_frames<=hold_frames-1'b1;
                if (hold_frames==1) begin move_up<=0; move_down<=0; end
            end
            if (command_valid) begin
                rx_count<=rx_count+1'b1;
                last_command<=command;
                case (command)
                    "u":begin autoplay<=0; move_up<=1; move_down<=0; hold_frames<=12; end
                    "d":begin autoplay<=0; move_up<=0; move_down<=1; hold_frames<=12; end
                    "n":begin move_up<=0; move_down<=0; hold_frames<=0; end
                    "m":begin autoplay<=0; move_up<=0; move_down<=0; hold_frames<=0; end
                    "a":begin autoplay<=!autoplay; move_up<=0; move_down<=0; hold_frames<=0; end
                    "p":paused<=!paused;
                    "r":begin restart<=1; paused<=0; move_up<=0; move_down<=0; hold_frames<=0; end
                    default:begin end
                endcase
            end
        end
    end

    reg [31:0] snap_frames,snap_rx_count;
    reg [7:0] snap_left_score,snap_right_score,snap_command;
    reg [11:0] snap_left_y,snap_ball_x,snap_ball_y;
    reg snap_autoplay,snap_paused;
    wire start_report=!report_active && report_pending && configured;
    // Delay requests so snapshots see command updates from the previous edge.
    always @(posedge clk) begin
        if (!resetn) begin
            request_d<=0; report_pending<=0; report_active<=0; char_index<=0;
            snap_frames<=0; snap_rx_count<=0; snap_left_score<=0; snap_right_score<=0;
            snap_command<=0; snap_left_y<=0; snap_ball_x<=0; snap_ball_y<=0;
            snap_autoplay<=0; snap_paused<=0;
        end else begin
            request_d<=command_valid||heartbeat_tick;
            if (start_report) report_pending<=request_d;
            else if (request_d) report_pending<=1;
            if (start_report) begin
                report_active<=1; char_index<=0;
                snap_frames<=frame_count; snap_rx_count<=rx_count;
                snap_left_score<={1'b0,left_score}; snap_right_score<={1'b0,right_score};
                snap_command<=last_command; snap_left_y<=left_y;
                snap_ball_x<=ball_x; snap_ball_y<=ball_y;
                snap_autoplay<=autoplay; snap_paused<=paused;
            end else if (report_active && !uart_wait) begin
                if (char_index==MESSAGE_LENGTH-1) begin report_active<=0; char_index<=0; end
                else char_index<=char_index+1'b1;
            end
        end
    end
    function [7:0] hex_digit;
        input [3:0] value;
        begin hex_digit=value<10 ? 8'd48+value : 8'd55+value; end
    endfunction
    // Generated fixed-format, hardware-only telemetry formatter.
    `include "game/telemetry_format.vh"
    assign tx_character=message_char(char_index);
endmodule
