`timescale 1ns/1ps
module hd_tmds_tb;
    reg clk=0;always #5 clk=~clk;
    reg resetn=0,de=0;
    reg [1:0] ctrl=0;
    reg [7:0] data=0;
    wire [9:0] actual,reference;
    reg [9:0] delayed,delayed2;
    hd_tmds dut(clk,resetn,de,ctrl,data,actual);
    svo_tmds original(clk,resetn,de,ctrl,data,reference);
    integer i,age=0;
    always @(posedge clk)begin
        delayed<=reference;
        delayed2<=delayed;
        if(!resetn)age=0;else age=age+1;
        #1;
        if(age>12&&actual!==delayed2)$fatal(1,"TMDS mismatch actual=%03x expected=%03x",actual,delayed2);
    end
    initial begin
        repeat(8)@(negedge clk);resetn=1;
        for(i=0;i<20000;i=i+1)begin
            @(negedge clk);data=i<256?i:$random;
            ctrl=i;de=i%137<125;
            if(i==1234)resetn=0;if(i==1242)resetn=1;
        end
        repeat(10)@(negedge clk);
        $display("TEST PASS: pipelined TMDS matches original SVO for 20000 data/control symbols including reset");$finish;
    end
endmodule
