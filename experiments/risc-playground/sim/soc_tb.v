`timescale 1ns/1ps
`include "assets/letter_length.vh"
module soc_tb;
    reg clk=0;always #5 clk=~clk;
    reg resetn=0,rx=1,tick=0,pending=0,front=0;
    wire tx,trap,we,flip,overflow;
    wire [10:0] address;
    wire [15:0] data;
    wire [31:0] frames,d0,d1,d2,d3,d4,d5;
    reg [15:0] page0[0:2047],page1[0:2047];
    risc_soc dut(.clk(clk),.resetn(resetn),.ser_rx(rx),.frame_tick(tick),.ser_tx(tx),.trap(trap),.vram_we(we),.flip_request(flip),.vram_addr(address),.vram_data(data),.flip_pending(pending),.front_page(front),.frame_count(frames),.debug0(d0),.debug1(d1),.debug2(d2),.debug3(d3),.debug4(d4),.debug5(d5),.rx_overflow(overflow));
    always @(posedge clk)begin
        if(!resetn)begin pending<=0;front<=0;end
        else begin
            if(flip)pending<=1;
            if(tick&&pending)begin pending<=0;front<=!front;end
            if(we)begin if(front)page0[address]<=data;else page1[address]<=data;end
            if(trap)$fatal(1,"CPU trap PC=%h",dut.cpu.reg_pc);
        end
    end
    initial forever begin repeat(120000)@(negedge clk);tick=1;@(negedge clk)tick=0;end
    task send(input [7:0] b);
        integer j;
        begin
            @(negedge clk);rx=0;repeat(219)@(negedge clk);
            for(j=0;j<8;j=j+1)begin rx=b[j];repeat(219)@(negedge clk);end
            rx=1;repeat(219)@(negedge clk);
        end
    endtask
    task command(input [7:0] b);
        reg [31:0] old_count;
        begin old_count=d4;send(b);wait(d4>old_count&&d5==b);@(negedge clk);end
    endtask
    task dump(input integer game);
        integer f,i;begin
            f=$fopen($sformatf("build/cpu-game%0d.cells",game),"w");
            for(i=0;i<1200;i=i+1)begin
                if(front)$fdisplay(f,"%04x",page1[i]);else $fdisplay(f,"%04x",page0[i]);
            end
            $fclose(f);
        end
    endtask
    integer lines=0,j;
    reg [7:0] ch;
    string line="";
    initial forever begin
        @(negedge tx);repeat(328)@(posedge clk);
        for(j=0;j<8;j=j+1)begin ch[j]=tx;if(j!=7)repeat(219)@(posedge clk);end
        repeat(219)@(posedge clk);if(tx!==1)$fatal(1,"UART stop bit");
        if(ch==10)begin $display("UART: %s",line);lines++;line="";end
        else if(ch!=13)line={line,ch};
    end
    reg [31:0] old_x,old_y;
    integer g;
    initial begin
        repeat(10)@(negedge clk);resetn=1;
        wait(d0[7:0]==1);command("m");command("r");
        if(d1!=0||d2!=5||d3!=0)$fatal(1,"C snake reset");
        command(8'h82);old_x=d2;wait(d2!=old_x);command("p");
        old_x=d2;old_y=d3;repeat(1100000)@(negedge clk);
        if(d2!=old_x||d3!=old_y||!d0[9])$fatal(1,"C pause");dump(1);
        command("2");if(d0[7:0]!=2||d1!=0||d2!=1||d3!=1||d0[9])$fatal(1,"C maze reset");
        old_x=d2;old_y=d3;
        if(front?page1[246][7:0]==4:page0[246][7:0]==4)command(8'h88);else command(8'h82);
        wait(d2!=old_x||d3!=old_y);command("p");dump(2);
        command("3");if(d0[7:0]!=3||d1!=0)$fatal(1,"C blocks reset");
        command(8'h90);repeat(850000)@(negedge clk);command(8'h80);command("p");dump(3);
        command("4");if(d0[7:0]!=4)$fatal(1,"C letter select");
        command(8'h90);wait(d0[16]);command(8'h80);old_y=d3;wait(d3!=old_y);command(8'h90);
        wait(d1==`LETTER_LENGTH);command("p");dump(4);
        if(d0[16]==0||d1<20)$fatal(1,"C letter open/reveal");
        if(overflow||lines<6)$fatal(1,"FIFO overflow or missing UART");
        $display("TEST PASS: actual RV32IMC firmware boot, MMIO VRAM commits, UART commands, C snake movement/pause, maze demo, blocks, Chinese letter reveal; no CPU trap");$finish;
    end
    initial begin repeat(20000000)@(posedge clk);$fatal(1,"SoC timeout game=%h x=%h y=%h cmd=%h PC=%h",d0,d2,d3,d4,dut.cpu.reg_pc);end
endmodule
