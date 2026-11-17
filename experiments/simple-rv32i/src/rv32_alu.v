// Original teaching ALU. Operation numbers are shared with rv32_decode.v.
module rv32_alu (
    input wire [31:0] a, b,
    input wire [3:0] op,
    output reg [31:0] result
);
    always @* begin
        case (op)
            0: result = a + b;
            1: result = a - b;
            2: result = a << b[4:0];
            3: result = {31'b0, $signed(a) < $signed(b)};
            4: result = {31'b0, a < b};
            5: result = a ^ b;
            6: result = a >> b[4:0];
            7: result = $signed(a) >>> b[4:0];
            8: result = a | b;
            9: result = a & b;
            default: result = 0;
        endcase
    end
endmodule
