// Decode RV32I only. M/C, CSR and privileged instructions are illegal here.
module rv32_decode (
    input wire [31:0] instr,
    output wire [4:0] rs1, rs2, rd,
    output wire [2:0] funct3,
    output reg [31:0] imm,
    output reg [3:0] alu_op,
    output reg use_imm, reg_write, load, store, branch, jal, jalr,
    output reg lui, auipc, ecall, ebreak, illegal
);
    assign rs1 = instr[19:15];
    assign rs2 = instr[24:20];
    assign rd = instr[11:7];
    assign funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];
    always @* begin
        imm = {{20{instr[31]}}, instr[31:20]};
        alu_op = 0;
        use_imm = 0; reg_write = 0; load = 0; store = 0;
        branch = 0; jal = 0; jalr = 0; lui = 0; auipc = 0;
        ecall = 0; ebreak = 0; illegal = 0;
        case (instr[6:0])
            7'b0110111: begin // LUI
                lui = 1; use_imm = 1; reg_write = 1;
                imm = {instr[31:12], 12'b0};
            end
            7'b0010111: begin // AUIPC
                auipc = 1; use_imm = 1; reg_write = 1;
                imm = {instr[31:12], 12'b0};
            end
            7'b1101111: begin // JAL
                jal = 1; reg_write = 1;
                imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            end
            7'b1100111: begin
                jalr = 1; reg_write = 1;
                if (funct3 != 0) illegal = 1;
            end
            7'b1100011: begin
                branch = 1;
                imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
                if (!(funct3 == 0 || funct3 == 1 || funct3 >= 4)) illegal = 1;
            end
            7'b0000011: begin
                load = 1; reg_write = 1; use_imm = 1;
                if (!(funct3 == 0 || funct3 == 1 || funct3 == 2 || funct3 == 4 || funct3 == 5)) illegal = 1;
            end
            7'b0100011: begin
                store = 1; use_imm = 1;
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
                if (funct3 > 2) illegal = 1;
            end
            7'b0010011: begin
                use_imm = 1; reg_write = 1;
                case (funct3)
                    0: alu_op = 0;
                    2: alu_op = 3;
                    3: alu_op = 4;
                    4: alu_op = 5;
                    6: alu_op = 8;
                    7: alu_op = 9;
                    1: begin alu_op = 2; if (funct7 != 0) illegal = 1; end
                    5: begin
                        alu_op = funct7 == 7'h20 ? 7 : 6;
                        if (!(funct7 == 0 || funct7 == 7'h20)) illegal = 1;
                    end
                endcase
            end
            7'b0110011: begin
                reg_write = 1;
                if (!(funct7 == 0 || (funct7 == 7'h20 && (funct3 == 0 || funct3 == 5)))) illegal = 1;
                case (funct3)
                    0: alu_op = funct7 == 7'h20 ? 1 : 0;
                    1: alu_op = 2;
                    2: alu_op = 3;
                    3: alu_op = 4;
                    4: alu_op = 5;
                    5: alu_op = funct7 == 7'h20 ? 7 : 6;
                    6: alu_op = 8;
                    7: alu_op = 9;
                endcase
            end
            7'b0001111: begin // FENCE: all transfers already complete in order.
                if (funct3 != 0) illegal = 1;
            end
            7'b1110011: begin
                if (instr == 32'h00000073) ecall = 1;
                else if (instr == 32'h00100073) ebreak = 1;
                else illegal = 1;
            end
            default: illegal = 1;
        endcase
    end
endmodule
