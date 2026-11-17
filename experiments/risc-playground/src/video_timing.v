module video_timing (
    input wire clk, resetn,
    output reg [9:0] x,
    output reg [9:0] y,
    output wire de, hsync, vsync, frame_tick
);
    // 25.2 MHz / (800 * 525) = 60 Hz, 640x480 active, negative sync.
    always @(posedge clk) begin
        if (!resetn) begin x <= 0; y <= 0; end
        else if (x == 799) begin
            x <= 0;
            if (y == 524) y <= 0; else y <= y + 1'b1;
        end else x <= x + 1'b1;
    end
    assign de = x < 640 && y < 480;
    assign hsync = !(x >= 656 && x < 752);
    assign vsync = !(y >= 490 && y < 492);
    // Update the game at the beginning of vertical blank, before the next image.
    assign frame_tick = x == 0 && y == 480;
endmodule
