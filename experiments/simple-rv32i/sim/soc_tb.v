`timescale 1ns/1ps
module soc_tb;
    localparam DIV=117;
    reg clk=0, reset=1, rx=1;
    always #5 clk=~clk;
    wire tx,trap;
    wire [5:0] gpio;
    wire [31:0] cause,pc,retired;
    simple_soc #(.TIMER_STEP(1000)) soc(clk,reset,rx,tx,gpio,trap,cause,pc,retired);
    integer cycles=0,heartbeats=0,fd;
    reg self_ok=0,challenge_ok=0,pong_ok=0,status_ok=0;
    reg [7:0] ch;
    integer bitnum;
    string line="";
    task send_byte(input [7:0] data);
        integer n;
        begin
            @(negedge clk); rx=0; repeat(DIV) @(negedge clk);
            for(n=0;n<8;n=n+1) begin rx=data[n]; repeat(DIV) @(negedge clk); end
            rx=1; repeat(DIV) @(negedge clk);
        end
    endtask
    initial begin
        fd=$fopen("build/soc-uart.txt","w");
        repeat(8) @(negedge clk); reset=0;
        wait(self_ok && heartbeats>=2);
        send_byte("K"); wait(challenge_ok);
        send_byte("p"); wait(pong_ok);
        send_byte("?"); wait(status_ok && heartbeats>=4);
        if(soc.serial.rx_overrun) $fatal(1,"RX overrun");
        $display("SOC_TEST_PASS retired=%0d gpio=%02x",retired,gpio);
        $fclose(fd); $finish;
    end
    initial forever begin
        @(negedge tx);
        repeat(DIV+DIV/2) @(negedge clk);
        for(bitnum=0;bitnum<8;bitnum=bitnum+1) begin
            ch[bitnum]=tx; repeat(DIV) @(negedge clk);
        end
        if(!tx) $fatal(1,"UART stop bit");
        $fwrite(fd,"%c",ch);
        if(ch==10) begin
            $display("UART: %s",line);
            if(line=="SELF=PASS") self_ok=1;
            if(line=="RX=0000004B") challenge_ok=1;
            if(line=="PONG") pong_ok=1;
            if(line.len()>=6 && line.substr(0,5)=="COUNT=") heartbeats=heartbeats+1;
            if(line.len()>32 && line.substr(0,31)=="CPU=SimpleRV32I SELF=PASS COUNT=") status_ok=1;
            line="";
        end else if(ch!=13) line={line,ch};
    end
    always @(posedge clk) if(!reset) begin
        cycles<=cycles+1;
        if(trap) $fatal(1,"CPU trapped cause=%x pc=%x",cause,pc);
        if(cycles>3000000) $fatal(1,"SoC timeout status=%b",status_ok);
    end
endmodule
