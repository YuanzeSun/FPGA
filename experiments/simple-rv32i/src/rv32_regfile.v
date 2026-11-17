module rv32_regfile (
    input wire clk, reset, write_enable,
    input wire [4:0] rs1, rs2, rd,
    input wire [31:0] write_data,
    output wire [31:0] a, b
);
    reg [31:0] regs [1:31];
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            for (i = 1; i < 32; i = i + 1) regs[i] <= 0;
        end else if (write_enable && rd != 0) regs[rd] <= write_data;
    end
    assign a = rs1 == 0 ? 32'b0 : regs[rs1];
    assign b = rs2 == 0 ? 32'b0 : regs[rs2];
endmodule
