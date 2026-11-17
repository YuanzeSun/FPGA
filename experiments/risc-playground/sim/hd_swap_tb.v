`timescale 1ns/1ps
module hd_swap_tb;
    reg cpu_clk=0,pixel_clk=0;
    always #17 cpu_clk=~cpu_clk;
    always #5 pixel_clk=~pixel_clk;
    reg cpu_resetn=0,pixel_resetn=0,we=0,request=0,ready=1;
    wire pending,front,valid,sof;
    wire [23:0] data;
    hd_tile_stream #(.WIDTH(8),.HEIGHT(4)) dut(cpu_clk,cpu_resetn,pixel_clk,pixel_resetn,
        we,request,11'b0,16'h0720,pending,front,valid,ready,data,sof);
    integer i;
    reg old_front;
    initial begin
        repeat(5)@(negedge cpu_clk);cpu_resetn=1;pixel_resetn=1;
        repeat(10)@(negedge cpu_clk);
        for(i=0;i<3;i=i+1)begin
            old_front=front;
            @(negedge cpu_clk);we=1;
            @(negedge cpu_clk);we=0;request=1;
            @(negedge cpu_clk);request=0;
            wait(dut.last_pixel&&dut.request_sync[2]!=dut.ack_toggle);
            @(posedge pixel_clk);#1;ready=0;
            if(!valid)$fatal(1,"Boundary hold did not stall a valid pixel");
            repeat(12)@(negedge cpu_clk);
            if(!pending||front!=old_front)$fatal(1,"CPU reclaimed the old page before final RAM read");
            @(negedge pixel_clk);ready=1;
            wait(!pending);@(negedge cpu_clk);
            if(front==old_front)$fatal(1,"Page acknowledgement lost");
        end
        $display("TEST PASS: page ack waits for final RAM read during prolonged backpressure, three asynchronous swaps");$finish;
    end
    initial begin #100000;$fatal(1,"Swap handshake timeout");end
endmodule
