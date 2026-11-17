// Original multi-cycle RV32I core: FETCH -> EXEC -> optional MEMORY.
// Bus requests stay stable until ready. Traps halt until reset; no privileged ISA.
module rv32_core #(
    parameter [31:0] RESET_PC = 0
) (
    input wire clk, reset,
    output wire mem_valid, mem_instr,
    output wire [31:0] mem_addr, mem_wdata,
    output wire [3:0] mem_wstrb,
    input wire mem_ready, mem_error,
    input wire [31:0] mem_rdata,
    output reg trap,
    output reg [31:0] trap_cause, trap_value,
    output wire [31:0] debug_pc,
    output reg [31:0] retired_count,
    output reg retire_valid,
    output reg [31:0] retire_pc, retire_instr, retire_data,
    output reg [4:0] retire_rd
);
    localparam FETCH=0, EXEC=1, MEMORY=2, HALT=3;
    reg [1:0] state;
    reg [31:0] pc, instr;
    reg [31:0] bus_addr, bus_data, effective_addr;
    reg [3:0] bus_mask;
    reg [4:0] load_rd;
    reg [2:0] load_funct;
    reg memory_load;
    wire [4:0] rs1, rs2, rd;
    wire [2:0] funct3;
    wire [31:0] imm, a, b, alu_result;
    wire [3:0] alu_op;
    wire use_imm, reg_write, load, store, branch, jal, jalr;
    wire lui, auipc, ecall, ebreak, illegal;
    rv32_decode decoder(instr, rs1, rs2, rd, funct3, imm, alu_op,
                        use_imm, reg_write, load, store, branch, jal, jalr,
                        lui, auipc, ecall, ebreak, illegal);
    wire [31:0] alu_a = lui ? 32'b0 : auipc ? pc : a;
    wire [31:0] alu_b = use_imm ? imm : b;
    rv32_alu alu(alu_a, alu_b, alu_op, alu_result);

    reg take_branch;
    always @* begin
        case (funct3)
            0: take_branch = a == b;
            1: take_branch = a != b;
            4: take_branch = $signed(a) < $signed(b);
            5: take_branch = $signed(a) >= $signed(b);
            6: take_branch = a < b;
            7: take_branch = a >= b;
            default: take_branch = 0;
        endcase
    end
    wire jump = jal || jalr || (branch && take_branch);
    wire [31:0] jump_addr = jalr ? ((a + imm) & 32'hfffffffe) : pc + imm;
    wire bad_jump = jump && |jump_addr[1:0];
    wire bad_data = (load || store) &&
                    ((funct3[1:0] == 1 && alu_result[0]) ||
                     (funct3[1:0] == 2 && |alu_result[1:0]));
    wire exec_ok = state == EXEC && !illegal && !ecall && !ebreak && !bad_jump && !bad_data;
    wire exec_done = exec_ok && !load && !store;
    wire memory_done = state == MEMORY && mem_ready && !mem_error;
    wire [31:0] shifted_load = mem_rdata >> {effective_addr[1:0], 3'b000};
    reg [31:0] load_data;
    always @* begin
        case (load_funct)
            0: load_data = {{24{shifted_load[7]}}, shifted_load[7:0]};
            1: load_data = {{16{shifted_load[15]}}, shifted_load[15:0]};
            4: load_data = {24'b0, shifted_load[7:0]};
            5: load_data = {16'b0, shifted_load[15:0]};
            default: load_data = mem_rdata;
        endcase
    end
    wire write_enable = !reset && ((exec_done && reg_write) || (memory_done && memory_load));
    wire [4:0] write_rd = state == MEMORY ? load_rd : rd;
    wire [31:0] write_data = state == MEMORY ? load_data : (jal || jalr) ? pc + 4 : alu_result;
    rv32_regfile registers(clk, reset, write_enable, rs1, rs2, write_rd, write_data, a, b);

    assign mem_valid = !reset && (state == FETCH || state == MEMORY);
    assign mem_instr = state == FETCH;
    assign mem_addr = state == FETCH ? pc : bus_addr;
    assign mem_wdata = state == MEMORY ? bus_data : 32'b0;
    assign mem_wstrb = state == MEMORY ? bus_mask : 4'b0;
    assign debug_pc = pc;

    task stop_trap;
        input [31:0] cause, value;
        begin trap <= 1; trap_cause <= cause; trap_value <= value; state <= HALT; end
    endtask
    always @(posedge clk) begin
        retire_valid <= 0;
        if (reset) begin
            state <= FETCH; pc <= RESET_PC; instr <= 0;
            trap <= 0; trap_cause <= 0; trap_value <= 0; retired_count <= 0;
            retire_pc <= 0; retire_instr <= 0; retire_rd <= 0; retire_data <= 0;
            bus_addr <= 0; bus_data <= 0; bus_mask <= 0; effective_addr <= 0;
            load_rd <= 0; load_funct <= 0; memory_load <= 0;
        end else begin
            if (exec_done || memory_done) begin
                retire_valid <= 1; retired_count <= retired_count + 1;
                retire_pc <= pc; retire_instr <= instr;
                retire_rd <= write_enable ? write_rd : 5'b0;
                retire_data <= write_enable && write_rd != 0 ? write_data : 32'b0;
            end
            case (state)
                FETCH: begin
                    if (|pc[1:0]) stop_trap(0, pc);
                    else if (mem_ready) begin
                        if (mem_error) stop_trap(1, pc);
                        else begin instr <= mem_rdata; state <= EXEC; end
                    end
                end
                EXEC: begin
                    if (illegal) stop_trap(2, instr);
                    else if (ebreak) stop_trap(3, pc);
                    else if (ecall) stop_trap(11, 0);
                    else if (bad_jump) stop_trap(0, jump_addr);
                    else if (bad_data) stop_trap(load ? 4 : 6, alu_result);
                    else if (load || store) begin
                        bus_addr <= {alu_result[31:2], 2'b00};
                        effective_addr <= alu_result;
                        bus_data <= b << {alu_result[1:0], 3'b000};
                        bus_mask <= !store ? 4'b0 : funct3 == 0 ? (4'b0001 << alu_result[1:0]) :
                                    funct3 == 1 ? (4'b0011 << alu_result[1:0]) : 4'b1111;
                        load_rd <= rd; load_funct <= funct3; memory_load <= load;
                        state <= MEMORY;
                    end else begin pc <= jump ? jump_addr : pc + 4; state <= FETCH; end
                end
                MEMORY: if (mem_ready) begin
                    if (mem_error) stop_trap(memory_load ? 5 : 7, effective_addr);
                    else begin pc <= pc + 4; state <= FETCH; end
                end
                HALT: state <= HALT;
            endcase
        end
    end
endmodule
