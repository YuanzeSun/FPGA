`timescale 1ns/1ps
module tmds_tb;
    reg clk=0;always #5 clk=~clk;
    reg resetn=0,de=0;
    reg [1:0] ctrl=0;
    reg [7:0] data=0;
    wire [9:0] code;
    svo_tmds dut(.clk(clk),.resetn(resetn),.de(de),.ctrl(ctrl),.din(data),.dout(code));
    reg [7:0] expected_data[0:2];
    reg expected_de[0:2];
    reg [1:0] expected_ctrl[0:2];
    integer fd,i;
    always @(posedge clk) begin
        expected_data[0]<=data;expected_data[1]<=expected_data[0];expected_data[2]<=expected_data[1];
        expected_de[0]<=de;expected_de[1]<=expected_de[0];expected_de[2]<=expected_de[1];
        expected_ctrl[0]<=ctrl;expected_ctrl[1]<=expected_ctrl[0];expected_ctrl[2]<=expected_ctrl[1];
    end
    initial begin
        fd=$fopen("build/tmds.csv","w");
        repeat(6)@(negedge clk);resetn=1;
        for(i=0;i<2052;i=i+1)begin
            de=(i%40)<32;ctrl=i%4;data=(i*73+19)&255;
            @(posedge clk);#1;
            if(i>=3)$fdisplay(fd,"%d,%d,%02x,%03x",expected_de[2],expected_ctrl[2],expected_data[2],code);
            @(negedge clk);
        end
        $fclose(fd);$display("TMDS encoding samples recorded");$finish;
    end
endmodule
