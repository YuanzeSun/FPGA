`timescale 1ns/1ps
module soc_tb;
    localparam DIV=117;
    reg clk=0, reset=1, rx=1;
    always #5 clk=~clk;
    wire tx,trap;
    wire [5:0] gpio;
    wire [31:0] cause,pc,retired;
    simple_soc soc(clk,reset,rx,tx,gpio,trap,cause,pc,retired);
    integer cycles=0,ready_count=0,fd;
    reg [7:0] ch;
    integer bitnum;
    string line="";
    task send_byte(input [7:0] data);
        integer n;
        begin
            @(negedge clk); rx=0; repeat(DIV) @(negedge clk);
            for(n=0;n<8;n=n+1) begin rx=data[n]; repeat(DIV) @(negedge clk); end
            rx=1; repeat(DIV*3) @(negedge clk);
        end
    endtask
    task send_text(input string data);
        integer i;
        begin for(i=0;i<data.len();i=i+1) send_byte(data[i]); end
    endtask
    initial begin
        fd=$fopen("build/soc-uart.txt","w");
        repeat(8) @(negedge clk); reset=0;
        wait(ready_count==1); send_text("info\n");
        wait(ready_count==2); send_text("sort 9 -2 5 1\n");
        wait(ready_count==3); send_text("find 5 1 3 5 7\n");
        wait(ready_count==4); send_text("maxsub -2 1 -3 4 -1 2 1 -5 4\n");
        wait(ready_count==5); send_text("gcd 48 18\n");
        wait(ready_count==6); send_text("find 3 9 1\n");
        wait(ready_count==7);
        if(soc.serial.rx_overrun) $fatal(1,"RX overrun");
        $display("SOC_TEST_PASS retired=%0d",retired);
        $fclose(fd);$finish;
    end
    initial forever begin
        @(negedge tx);repeat(DIV+DIV/2) @(negedge clk);
        for(bitnum=0;bitnum<8;bitnum=bitnum+1) begin ch[bitnum]=tx;repeat(DIV) @(negedge clk);end
        if(!tx) $fatal(1,"UART stop bit");
        $fwrite(fd,"%c",ch);
        if(ch==10) begin
            $display("UART: %s",line);
            if(line=="READY") ready_count=ready_count+1;
            line="";
        end else if(ch!=13) line={line,ch};
    end
    always @(posedge clk) if(!reset) begin
        cycles<=cycles+1;
        if(trap) $fatal(1,"CPU trapped cause=%x pc=%x",cause,pc);
        if(cycles>8000000) $fatal(1,"SoC timeout ready=%d",ready_count);
    end
endmodule
