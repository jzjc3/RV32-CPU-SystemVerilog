module alu(
    // all inputs are from decoder/controller. some are formatted
    input  logic [6:0]  opcode,

    // Immediates: all immediates below are alr normalized to 32 bits (sign-extended)
    input  logic [31:0] imm_I, // 12
    input  logic [31:0] imm_S, // 12
    input  logic [31:0] imm_B, // 13   // last bit is always 0 b/c alignment
    input  logic [31:0] imm_U, // 32   // upper 20 bits
    input  logic [31:0] imm_J, // 21   // last bit is always 0 b/c alignment

    // Register data
    input  logic [31:0] rs1_data,
    input  logic [31:0] rs2_data,

    // PC data
    input  logic [MEM_ADDR_BIT-1:0] pc,

    output logic [31:0] alu_src_a,
    output logic [31:0] alu_src_b
);
    // data 1: rs1_data, pc
    // data 2: rs2_data, imm_I, imm_I[4:0], imm_U, imm_S, imm_J, 32'd4
    // branching selection: pc + imm_B ,  pc + 32'd4

    // only two cases for alu source A: pc, '0 (OP_LUI only), or rs1_data (for most cases it's rs1_data)
    always_comb begin: alu_src_a_selection
        case (opcode) 
            OP_AUIPC,
            OP_JAL,
            OP_JALR: alu_src_a = pc;

            OP_LUI:  alu_src_a = 32'b0;

            default: alu_src_a = rs1_data;
        edncase 
    end
    
    // for alu source B, can be from rs2_data, immediates, or constants
    // MUX output selection is based on OPCode
    always_comb begin: alu_src_b_selection
        alu_src_b = rs2_data; // default for R-type / branch compare

        case (opcode)
            OP_REGISTER: begin
                alu_src_b = rs2_data;
            end

            OP_IMM: begin
                case (func3)
                    3'b001,
                    3'b101: alu_src_b = {27'd0, imm_I[4:0]}; // SLLI, SRLI, SRAI shamt: only taking the 5 LSB 
                    default: alu_src_b = imm_I;
                endcase
            end

            OP_LOAD: begin
                alu_src_b = imm_I;
            end

            OP_STORE: begin
                alu_src_b = imm_S;
            end

            OP_BRANCH: begin
                alu_src_b = rs2_data;
            end

            OP_LUI,
            OP_AUIPC: begin
                alu_src_b = imm_U;
            end

            OP_JAL,
            OP_JALR: begin
                alu_src_b = 32'd4;
            end

            default: begin
                alu_src_b = 32'd0;
            end
        endcase
    end

endmodule