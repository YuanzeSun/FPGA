`timescale 1ns/1ps
module system_tb;
    reg clk=0;always #5 clk=~clk;
    reg resetn=0,rx=1,test_frame=0;
    wire tx,paused,autoplay,de,hs,vs;
    wire [23:0] rgb;
    wire [31:0] frames,received;
    wire [1:0] mode,lives,state;
    wire [7:0] score;
    wire [9:0] px,ox,oy;
    arcade_system dut(clk,resetn,rx,tx,rgb,de,hs,vs,paused,autoplay,mode,frames,received,score,lives,state,px,ox,oy,1'b0,10'b0,10'b0);
    initial begin
        force dut.frame_tick=test_frame;
        forever begin repeat(10000)@(negedge clk);test_frame=1;@(negedge clk)test_frame=0;end
    end
    task send(input [7:0] value);
        integer i;
        begin
            @(negedge clk)rx=0;repeat(219)@(negedge clk);
            for(i=0;i<8;i=i+1)begin rx=value[i];repeat(219)@(negedge clk);end
            rx=1;repeat(219)@(negedge clk);
            repeat(8)@(negedge clk);
        end
    endtask
    integer lines=0,bit_index;
    reg [7:0] character;
    string line="";
    initial forever begin
        @(negedge tx);repeat(219+109)@(posedge clk);
        for(bit_index=0;bit_index<8;bit_index=bit_index+1)begin
            character[bit_index]=tx;
            if(bit_index!=7)repeat(219)@(posedge clk);
        end
        repeat(219)@(posedge clk);
        if(tx!==1'b1)$fatal(1,"UART stop bit");
        if(character==10)begin
            $display("UART: %s",line);
            if(line.len()!=77||line.substr(0,8)!="ARCADE G=")$fatal(1,"telemetry format len=%d",line.len());
            lines=lines+1;line="";
        end else if(character!=13)line={line,character};
    end
    reg [9:0] before_x,hold_x,hold_y;
    integer game_index;
    initial begin
        repeat(10)@(negedge clk);resetn=1;
        wait(frames>=2);send("m");
        for(game_index=0;game_index<3;game_index=game_index+1)begin
            send(8'd49+game_index);
            if(mode!=game_index||lives!=3||score!=0||state!=0||px!=320) $fatal(1,"switch/reset game %d",game_index);
            before_x=px;send(8'h81);repeat(35000)@(negedge clk);
            if(px>=before_x||autoplay) $fatal(1,"move left game %d",game_index);
            before_x=px;send(8'h86);repeat(25000)@(negedge clk);
            if(px<=before_x) $fatal(1,"simultaneous right/fire game %d",game_index);
            if(game_index==1&&dut.serving) $fatal(1,"fire launch");
            if(game_index==2&&!dut.shot_active) $fatal(1,"fire projectile");
            send(8'h80);send("p");hold_x=ox;hold_y=oy;before_x=px;
            repeat(40000)@(negedge clk);
            if(!paused||ox!=hold_x||oy!=hold_y||px!=before_x) $fatal(1,"pause game %d",game_index);
            send("r");if(paused||score!=0||lives!=3||px!=320) $fatal(1,"restart game %d",game_index);
            send(8'h81);repeat(150000)@(negedge clk);before_x=px;
            repeat(40000)@(negedge clk);if(px!=before_x||dut.buttons!=0) $fatal(1,"input watchdog");
        end
        send("a");if(!autoplay) $fatal(1,"autoplay");
        send("p");send("1");if(paused||mode!=0||!autoplay) $fatal(1,"switch clears pause, keeps auto");
        repeat(400000)@(negedge clk);
        if(lines<3)$fatal(1,"telemetry missing");
        $display("TEST PASS: real UART bits, three game modes, movement/fire, pause, restart, timeout and telemetry");$finish;
    end
    initial begin repeat(2000000)@(posedge clk);$fatal(1,"timeout");end
endmodule
