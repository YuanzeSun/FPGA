`timescale 1ns/1ps
module system_tb;
    reg clk=0;always #5 clk=~clk;
    reg resetn=0,rx=1,test_frame=0;
    wire tx,paused,autoplay,de,hs,vs;
    wire [23:0] rgb;
    wire [31:0] frames,received;
    wire [11:0] ly,ry,bx,by;
    wire [6:0] ls,rs;
    pong_system dut(.clk(clk),.resetn(resetn),.ser_rx(rx),.ser_tx(tx),.rgb(rgb),.de(de),.hsync(hs),.vsync(vs),
        .paused(paused),.autoplay(autoplay),.frame_count(frames),.rx_count(received),
        .left_y(ly),.right_y(ry),.ball_x(bx),.ball_y(by),.left_score(ls),.right_score(rs));
    // Video geometry is tested separately; accelerate only the game frame pulse.
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
        if(tx!==1'b1)$fatal(1,"Telemetry UART stop bit failed");
        if(character==10)begin
            $display("UART: %s",line);
            if(line.len()!=68 || line.substr(0,6)!="PONG F=")$fatal(1,"Malformed telemetry len=%d",line.len());
            lines=lines+1;line="";
        end else if(character!=13)line={line,character};
    end
    reg [11:0] before_y,hold_x,hold_y;
    initial begin
        repeat(10)@(negedge clk);resetn=1;
        wait(frames>=2);send("m");
        if(autoplay!==0)$fatal(1,"Manual command failed");
        before_y=ly;send("u");repeat(40000)@(negedge clk);
        if(ly>=before_y)$fatal(1,"UART up command failed");
        send("n");send("p");repeat(100)@(negedge clk);
        if(paused!==1)$fatal(1,"Pause command failed");
        hold_x=bx;hold_y=by;repeat(35000)@(negedge clk);
        if(bx!=hold_x || by!=hold_y)$fatal(1,"Paused game moved");
        send("p");repeat(30000)@(negedge clk);
        if(paused!==0 || (bx==hold_x&&by==hold_y))$fatal(1,"Resume failed");
        send("a");if(autoplay!==1)$fatal(1,"Autoplay failed");
        send("r");
        if(paused || ls!=0 || rs!=0 || received!=7)$fatal(1,"Restart or command count failed");
        repeat(400000)@(negedge clk);
        if(lines<2)$fatal(1,"Telemetry missing");
        $display("TEST PASS: UART control, movement, pause/resume, restart, autoplay and telemetry");
        $finish;
    end
    initial begin repeat(1000000)@(posedge clk);$fatal(1,"System simulation timeout");end
endmodule
