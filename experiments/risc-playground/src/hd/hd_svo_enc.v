/*
 *  SVO - Simple Video Out FPGA Core
 *
 *  Copyright (C) 2014  Clifford Wolf <clifford@clifford.at>
 *  
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *  
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

`timescale 1ns / 1ps
// CTA 720p60/1080p30 and custom reduced-blanking 1080p45; stock SVO FIFO.

module hd_svo_fifo #(parameter HD1080=0, parameter HD45=0, parameter SVO_BITS_PER_PIXEL=24) (
	input clk, resetn,

	// input stream
	//   tuser[0] ... start of frame
	input in_axis_tvalid,
	output reg in_axis_tready,
	input [SVO_BITS_PER_PIXEL-1:0] in_axis_tdata,
	input [0:0] in_axis_tuser,

	// output stream
	//   tuser[0] ... start of frame
	//   tuser[1] ... hsync
	//   tuser[2] ... vsync
	//   tuser[3] ... blank
	output reg out_axis_tvalid,
	input out_axis_tready,
	output reg [SVO_BITS_PER_PIXEL-1:0] out_axis_tdata,
	output reg [3:0] out_axis_tuser
);
	localparam SVO_HOR_PIXELS=HD1080?1920:1280;
    localparam SVO_VER_PIXELS=HD1080?1080:720;
    localparam SVO_HOR_FRONT_PORCH=HD45?48:HD1080?88:110;
    localparam SVO_HOR_SYNC=HD45?32:HD1080?44:40;
    localparam SVO_HOR_BACK_PORCH=HD45?80:HD1080?148:220;
    localparam SVO_VER_FRONT_PORCH=HD45?3:HD1080?4:5;
    localparam SVO_VER_SYNC=5;
    localparam SVO_VER_BACK_PORCH=HD45?37:HD1080?36:20;
    localparam SVO_HOR_TOTAL=HD45?2080:HD1080?2200:1650;
    localparam SVO_VER_TOTAL=HD45?1125:HD1080?1125:750;

	reg [14-1:0] hcursor;
	reg [14-1:0] vcursor;

	reg [3:0] ctrl_fifo [0:3];
	reg [1:0] ctrl_fifo_wraddr, ctrl_fifo_rdaddr;

	reg [SVO_BITS_PER_PIXEL:0] pixel_fifo [0:7];
	reg [2:0] pixel_fifo_wraddr, pixel_fifo_rdaddr;

	reg [SVO_BITS_PER_PIXEL+3:0] out_fifo [0:3];
	reg [1:0] out_fifo_wraddr, out_fifo_rdaddr;

	wire [1:0]  ctrl_fifo_fill =  ctrl_fifo_wraddr -  ctrl_fifo_rdaddr;
	wire [2:0] pixel_fifo_fill = pixel_fifo_wraddr - pixel_fifo_rdaddr;
	wire [1:0]   out_fifo_fill =   out_fifo_wraddr -   out_fifo_rdaddr;

	reg is_hsync, is_vsync, is_blank;

	always @(posedge clk) begin
		if (!resetn) begin
			ctrl_fifo_wraddr <= 0;
			hcursor = 0;
			vcursor = 0;
		end else if (ctrl_fifo_wraddr + 2'd1 != ctrl_fifo_rdaddr) begin
			is_blank = 0;
			is_hsync = 0;
			is_vsync = 0;

			if (hcursor < SVO_HOR_FRONT_PORCH) begin
				is_blank = 1;
			end else if (hcursor < SVO_HOR_FRONT_PORCH + SVO_HOR_SYNC) begin
				is_blank = 1;
				is_hsync = 1;
			end else if (hcursor < SVO_HOR_FRONT_PORCH + SVO_HOR_SYNC + SVO_HOR_BACK_PORCH) begin
				is_blank = 1;
			end

			if (vcursor < SVO_VER_FRONT_PORCH) begin
				is_blank = 1;
			end else if (vcursor < SVO_VER_FRONT_PORCH + SVO_VER_SYNC) begin
				is_blank = 1;
				is_vsync = 1;
			end else if (vcursor < SVO_VER_FRONT_PORCH + SVO_VER_SYNC + SVO_VER_BACK_PORCH) begin
				is_blank = 1;
			end

			ctrl_fifo[ctrl_fifo_wraddr] <= {is_blank, is_vsync ^ (HD45 != 0), is_hsync, !hcursor && !vcursor};
			ctrl_fifo_wraddr <= ctrl_fifo_wraddr + 1;

			if (hcursor == SVO_HOR_TOTAL-1) begin
				hcursor = 0;
				vcursor = vcursor == SVO_VER_TOTAL-1 ? 0 : vcursor + 1;
			end else begin
				hcursor = hcursor + 1;
			end
		end
	end

	always @(posedge clk) begin
		if (!resetn) begin
			pixel_fifo_wraddr <= 0;
			in_axis_tready <= 0;
		end else begin
			if (in_axis_tvalid && in_axis_tready) begin
				pixel_fifo[pixel_fifo_wraddr] <= {in_axis_tuser, in_axis_tdata};
				pixel_fifo_wraddr <= pixel_fifo_wraddr + 1;
			end
			in_axis_tready <= pixel_fifo_wraddr + 3'd2 != pixel_fifo_rdaddr && pixel_fifo_wraddr + 3'd1 != pixel_fifo_rdaddr;
		end
	end

	always @(posedge clk) begin
		if (!resetn) begin
			ctrl_fifo_rdaddr <= 0;
			pixel_fifo_rdaddr <= 0;
			out_fifo_wraddr <= 0;
		end else begin
			if (ctrl_fifo_rdaddr != ctrl_fifo_wraddr && pixel_fifo_rdaddr != pixel_fifo_wraddr && out_fifo_wraddr + 2'd1 != out_fifo_rdaddr) begin
				if (ctrl_fifo[ctrl_fifo_rdaddr][0] && !pixel_fifo[pixel_fifo_rdaddr][SVO_BITS_PER_PIXEL]) begin
					// drop pixels until frame start is in sync
					pixel_fifo_rdaddr <= pixel_fifo_rdaddr + 1;
				end else
				if (ctrl_fifo[ctrl_fifo_rdaddr][3]) begin
					out_fifo[out_fifo_wraddr] <= {ctrl_fifo[ctrl_fifo_rdaddr], {SVO_BITS_PER_PIXEL{1'b0}}};
					out_fifo_wraddr <= out_fifo_wraddr + 1;
					ctrl_fifo_rdaddr <= ctrl_fifo_rdaddr + 1;
				end else begin
					out_fifo[out_fifo_wraddr] <= {ctrl_fifo[ctrl_fifo_rdaddr], pixel_fifo[pixel_fifo_rdaddr][SVO_BITS_PER_PIXEL-1:0]};
					out_fifo_wraddr <= out_fifo_wraddr + 1;
					ctrl_fifo_rdaddr <= ctrl_fifo_rdaddr + 1;
					pixel_fifo_rdaddr <= pixel_fifo_rdaddr + 1;
				end
			end
		end
	end

	reg [1:0] next_out_fifo_rdaddr;
	reg [1:0] wait_for_fifos;

	always @(posedge clk) begin
		if (!resetn) begin
			wait_for_fifos <= 0;
			out_fifo_rdaddr <= 0;
			out_axis_tvalid <= 0;
			out_axis_tdata <= 0;
			out_axis_tuser <= 0;
		end else if (wait_for_fifos < 3 || out_fifo_fill == 0) begin
			if (ctrl_fifo_fill < 3 || pixel_fifo_fill < 6 || out_fifo_fill < 3)
				wait_for_fifos <= 0;
			else
				wait_for_fifos <= wait_for_fifos + 1;
		end else begin
			next_out_fifo_rdaddr = out_fifo_rdaddr;
			if (out_axis_tvalid && out_axis_tready)
				next_out_fifo_rdaddr = next_out_fifo_rdaddr + 1;

			out_axis_tvalid <= next_out_fifo_rdaddr != out_fifo_wraddr;
			{out_axis_tuser, out_axis_tdata} <= out_fifo[next_out_fifo_rdaddr];

			out_fifo_rdaddr <= next_out_fifo_rdaddr;
		end
	end
endmodule

// The 45 Hz mode has a registered raster with direct ready/valid consumption.
// During blanking the tile stream holds its next active pixel. This removes the
// stock FIFO arbitration/read/write path from the faster video clock domain.
module hd_rb_enc #(parameter BITS=24)(
    input wire clk,resetn,in_valid,
    output wire in_ready,
    input wire [BITS-1:0] in_data,
    input wire in_sof,
    output reg out_valid,
    input wire out_ready,
    output reg [BITS-1:0] out_data,
    output reg [3:0] out_user
);
    reg [11:0] hcursor;
    reg [10:0] vcursor;
    reg hactive,vactive,hsync_active,vsync_level;
    wire advance=!out_valid||out_ready;
    wire blank=!(hactive&&vactive);
    assign in_ready=resetn&&advance&&!blank;
    always @(posedge clk)begin
        if(!resetn)begin
            hcursor<=0;vcursor<=0;out_valid<=0;out_data<=0;out_user<=0;
            hactive<=0;vactive<=0;hsync_active<=0;vsync_level<=1;
        end else if(advance)begin
            out_valid<=1;
            out_data<=blank||!in_valid?{BITS{1'b0}}:in_data;
            out_user<={blank,vsync_level,hsync_active,hcursor==0&&vcursor==0};
            // Register scan-region flags before they drive the tile pipeline's
            // clock enables; no coordinate comparator sits on its ready path.
            if(hcursor==159)hactive<=1;
            else if(hcursor==2079)hactive<=0;
            if(hcursor==47)hsync_active<=1;
            else if(hcursor==79)hsync_active<=0;
            if(hcursor==2079)begin
                hcursor<=0;
                vcursor<=vcursor==1124?0:vcursor+1'b1;
                if(vcursor==44)vactive<=1;
                else if(vcursor==1124)vactive<=0;
                if(vcursor==2)vsync_level<=0;
                else if(vcursor==7)vsync_level<=1;
            end else hcursor<=hcursor+1'b1;
        end
    end
endmodule

module hd_svo_enc #(parameter HD1080=0, parameter HD45=0, parameter SVO_BITS_PER_PIXEL=24)(
    input wire clk,resetn,in_axis_tvalid,
    output wire in_axis_tready,
    input wire [SVO_BITS_PER_PIXEL-1:0] in_axis_tdata,
    input wire [0:0] in_axis_tuser,
    output wire out_axis_tvalid,
    input wire out_axis_tready,
    output wire [SVO_BITS_PER_PIXEL-1:0] out_axis_tdata,
    output wire [3:0] out_axis_tuser
);
    generate if(HD45)begin:reduced_blanking
        hd_rb_enc #(.BITS(SVO_BITS_PER_PIXEL)) scan(clk,resetn,in_axis_tvalid,in_axis_tready,
            in_axis_tdata,in_axis_tuser[0],out_axis_tvalid,out_axis_tready,out_axis_tdata,out_axis_tuser);
    end else begin:stock
        hd_svo_fifo #(.HD1080(HD1080),.SVO_BITS_PER_PIXEL(SVO_BITS_PER_PIXEL)) scan(
            clk,resetn,in_axis_tvalid,in_axis_tready,in_axis_tdata,in_axis_tuser,
            out_axis_tvalid,out_axis_tready,out_axis_tdata,out_axis_tuser);
    end endgenerate
endmodule
