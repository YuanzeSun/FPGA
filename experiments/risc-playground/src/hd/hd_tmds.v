// Five-stage TMDS encoder. The running-disparity feedback contains one adder.
module hd_tmds(
    input wire clk,resetn,de,
    input wire [1:0] ctrl,
    input wire [7:0] din,
    output reg [9:0] dout
);
    function [3:0] ones;
        input [7:0] value;
        reg [1:0] p0,p1,p2,p3;
        reg [2:0] a,b;
        begin
            p0={1'b0,value[0]}+{1'b0,value[1]};p1={1'b0,value[2]}+{1'b0,value[3]};
            p2={1'b0,value[4]}+{1'b0,value[5]};p3={1'b0,value[6]}+{1'b0,value[7]};
            a={1'b0,p0}+{1'b0,p1};b={1'b0,p2}+{1'b0,p3};ones={1'b0,a}+{1'b0,b};
        end
    endfunction
    reg [7:0] data0;
    reg [3:0] count0;
    reg de0;
    reg [1:0] ctrl0;
    wire use_xnor=count0>4||(count0==4&&!data0[0]);
    wire [8:0] transition_word;
    genvar bit_index;
    generate for(bit_index=0;bit_index<8;bit_index=bit_index+1)begin:prefix
        assign transition_word[bit_index]=(^data0[bit_index:0])^(use_xnor&&(bit_index%2==1));
    end endgenerate
    assign transition_word[8]=!use_xnor;
    reg [8:0] q1,q2,q3;
    reg de1,de2,de3;
    reg [1:0] ctrl1,ctrl2,ctrl3;
    reg [3:0] count2;
    wire signed [5:0] balance2=$signed({1'b0,count2,1'b0})-6'sd8;
    reg signed [5:0] delta_zero3,delta_same3,delta_other3;
    reg balanced3,positive3;
    reg signed [5:0] disparity;
    wire same_sign=(disparity>0&&positive3)||(disparity<0&&!positive3);
    always @(posedge clk)begin
        if(!resetn)begin
            data0<=0;count0<=0;de0<=0;ctrl0<=0;
            q1<=0;q2<=0;q3<=0;de1<=0;de2<=0;de3<=0;
            ctrl1<=0;ctrl2<=0;ctrl3<=0;count2<=0;
            delta_zero3<=0;delta_same3<=0;delta_other3<=0;
            balanced3<=1;positive3<=0;disparity<=0;dout<=0;
        end else begin
            data0<=din;count0<=ones(din);de0<=de;ctrl0<=ctrl;
            q1<=transition_word;de1<=de0;ctrl1<=ctrl0;
            q2<=q1;count2<=ones(q1[7:0]);de2<=de1;ctrl2<=ctrl1;
            q3<=q2;de3<=de2;ctrl3<=ctrl2;
            balanced3<=count2==4;positive3<=count2>4;
            delta_zero3<=q2[8]?balance2:-balance2;
            delta_same3<=-balance2+(q2[8]?6'sd2:6'sd0);
            delta_other3<=balance2-(q2[8]?6'sd0:6'sd2);
            if(!de3)begin
                disparity<=0;
                case(ctrl3)
                    0:dout<=10'b1101010100;1:dout<=10'b0010101011;
                    2:dout<=10'b0101010100;3:dout<=10'b1010101011;
                endcase
            end else if(disparity==0||balanced3)begin
                dout<={~q3[8],q3[8],q3[8]?q3[7:0]:~q3[7:0]};
                disparity<=disparity+delta_zero3;
            end else if(same_sign)begin
                dout<={1'b1,q3[8],~q3[7:0]};disparity<=disparity+delta_same3;
            end else begin
                dout<={1'b0,q3[8],q3[7:0]};disparity<=disparity+delta_other3;
            end
        end
    end
endmodule
