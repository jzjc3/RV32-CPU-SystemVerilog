import cpu_pkg::*;

module alu(
    // all inputs are from decoder/controller. some are formatted
    input  logic [6:0]  opcode,
    input  logic [4:0]  rd,
    input  logic [2:0]  func3,
    input  logic [31:0] rs1_data,
    input  logic [31:0] rs2_data,
    input  logic signed [31:0] s_rs1_data,
    input  logic signed [31:0] s_rs2_data,
    input  logic [4:0]  rs1_data_5bit,
    input  logic [4:0]  rs2_data_5bit,
    input  logic [6:0]  func7,

    input  logic signed [31:0]  s_imm_I,
    // all immediates below are alr normalized to 32 bits (sign-extended)
    input  logic [31:0] imm_I, // 12
    input  logic [31:0] imm_S, // 12
    input  logic [31:0] imm_B, // 13   // last bit is always 0 b/c alignment
    input  logic [31:0] imm_U, // 32   // upper 20 bits
    input  logic [31:0] imm_J, // 21   // last bit is always 0 b/c alignment

    input  logic [MEM_ADDR_BIT-1:0] pc,

    output logic [MEM_ADDR_BIT-1:0] pc_calc,
    output logic [31:0] alu_calc,
    output logic [MEM_ADDR_BIT-1:0] eff_addr_calc
);

    // internal logic declaration
    // R-type candidate results
    logic [31:0] R_add_result;
    logic [31:0] R_sub_result;
    logic [31:0] R_mul_result;
    logic [31:0] R_sll_result;
    logic [31:0] R_slt_result;
    logic [31:0] R_sltu_result;
    logic [31:0] R_xor_result;
    logic [31:0] R_srl_result;
    logic [31:0] R_sra_result;
    logic [31:0] R_or_result;
    logic [31:0] R_and_result;

    // I-type arithmetic / logic candidate results
    logic [31:0] I_addi_result;
    logic [31:0] I_slti_result;
    logic [31:0] I_sltiu_result;
    logic [31:0] I_xori_result;
    logic [31:0] I_ori_result;
    logic [31:0] I_andi_result;

    // I-type shift-immediate candidate results
    logic [31:0] I_slli_result;
    logic [31:0] I_srli_result;
    logic [31:0] I_srai_result;

    // U-type candidate results
    logic [31:0] U_lui_result;
    logic [31:0] U_auipc_result;

    // Load/store effective-address candidate results
    logic [31:0] L_ea_result;
    logic [31:0] S_ea_result;

    // Branch next-PC candidate results
    logic [MEM_ADDR_BIT-1:0] B_beq_next_pc;
    logic [MEM_ADDR_BIT-1:0] B_bne_next_pc;
    logic [MEM_ADDR_BIT-1:0] B_blt_next_pc;
    logic [MEM_ADDR_BIT-1:0] B_bge_next_pc;
    logic [MEM_ADDR_BIT-1:0] B_bltu_next_pc;
    logic [MEM_ADDR_BIT-1:0] B_bgeu_next_pc;

    // Jump candidate results
    logic [31:0] J_jal_writeback_result;
    logic [MEM_ADDR_BIT-1:0] J_jal_next_pc;

    logic [31:0] I_jalr_writeback_result;
    logic [MEM_ADDR_BIT-1:0] I_jalr_next_pc;


    /**************************
     **************************
     ****** ALU_RESULT ********
     **************************
     **************************/
    // all the operations that I can do with the fields of instruction
    // R-type results
    assign R_add_result  = rs1_data + rs2_data;
    assign R_sub_result  = rs1_data - rs2_data;
    assign R_mul_result  = rs1_data * rs2_data;
    assign R_sll_result  = rs1_data << rs2_data_5bit;
    assign R_slt_result  = (s_rs1_data < s_rs2_data) ? 32'd1 : 32'd0;
    assign R_sltu_result = (rs1_data < rs2_data) ? 32'd1 : 32'd0;
    assign R_xor_result  = rs1_data ^ rs2_data;
    assign R_srl_result  = rs1_data >> rs2_data_5bit;
    assign R_sra_result  = s_rs1_data >>> rs2_data_5bit;
    assign R_or_result   = rs1_data | rs2_data;
    assign R_and_result  = rs1_data & rs2_data;

    // I-type immediate results
    assign I_addi_result  = rs1_data + imm_I;
    assign I_slti_result  = (s_rs1_data < s_imm_I) ? 32'd1 : 32'd0;
    assign I_sltiu_result = (rs1_data < imm_I) ? 32'd1 : 32'd0;
    assign I_xori_result  = rs1_data ^ imm_I;
    assign I_ori_result   = rs1_data | imm_I;
    assign I_andi_result  = rs1_data & imm_I;

    // I-type shift-immediate results
    assign I_slli_result = rs1_data << imm_I[4:0];
    assign I_srli_result = rs1_data >> imm_I[4:0];
    assign I_srai_result = s_rs1_data >>> imm_I[4:0];

    // U-type results
    assign U_lui_result   = imm_U;
    assign U_auipc_result = pc + imm_U;

    /**************************
     **************************
     ****** EA_RESULT ********
     **************************
     **************************/
    // I-type load results
    assign L_ea_result = rs1_data + imm_I;
    // S-type results
    assign S_ea_result = rs1_data + imm_S;

    /**************************
     **************************
     ****** PC_RESULT ********
     **************************
     **************************/
    // B-type results
    assign B_beq_next_pc  = (rs1_data == rs2_data) ? pc + imm_B : pc + 32'd4;
    assign B_bne_next_pc  = (rs1_data != rs2_data) ? pc + imm_B : pc + 32'd4;
    assign B_blt_next_pc  = (s_rs1_data <  s_rs2_data) ? pc + imm_B : pc + 32'd4;
    assign B_bge_next_pc  = (s_rs1_data >= s_rs2_data) ? pc + imm_B : pc + 32'd4;
    assign B_bltu_next_pc = (rs1_data <  rs2_data) ? pc + imm_B : pc + 32'd4;
    assign B_bgeu_next_pc = (rs1_data >= rs2_data) ? pc + imm_B : pc + 32'd4;

    /**************************
     ****** PC_RESULT *********
     ****** ALU_RESULT ********
     **************************/
    // Jump result
        // jal:  J-type
        // jalr: I-type
    assign J_jal_writeback_result  = pc + 32'd4;
    assign J_jal_next_pc           = pc + imm_J;

    assign I_jalr_writeback_result = pc + 32'd4;
    assign I_jalr_next_pc          = (rs1_data + imm_I) & ~32'd1;

    /****************************************
     **** Nothing really need to be done ****
    *****************************************/
    // System_call results

    // end of assignment logic


    // MUX (logic selcetion)
    always_comb begin
        alu_calc      = 32'd0;
        eff_addr_calc = 32'd0;
        pc_calc       = pc + 32'd4;

        case (opcode)
            OP_REGISTER: begin
                case (func3)
                    3'b000: begin
                        case (func7)
                            7'b0000000: alu_calc = R_add_result;
                            7'b0100000: alu_calc = R_sub_result;
                            7'b0000001: alu_calc = R_mul_result;
                            default:    alu_calc = 32'd0;
                        endcase
                    end
                    3'b001: alu_calc = R_sll_result;
                    3'b010: alu_calc = R_slt_result;
                    3'b011: alu_calc = R_sltu_result;
                    3'b100: alu_calc = R_xor_result;
                    3'b101: begin
                        case (func7)
                            7'b0000000: alu_calc = R_srl_result;
                            7'b0100000: alu_calc = R_sra_result;
                            default:    alu_calc = 32'd0;
                        endcase
                    end
                    3'b110: alu_calc  = R_or_result;
                    3'b111: alu_calc  = R_and_result;
                    default: alu_calc = 32'd0;
                endcase
            end

            OP_IMM: begin
                case (func3)
                    3'b000: alu_calc = I_addi_result;
                    3'b010: alu_calc = I_slti_result;
                    3'b011: alu_calc = I_sltiu_result;
                    3'b100: alu_calc = I_xori_result;
                    3'b110: alu_calc = I_ori_result;
                    3'b111: alu_calc = I_andi_result;
                    3'b001: alu_calc = I_slli_result;
                    3'b101: begin
                        case (func7)
                            7'b0000000: alu_calc = I_srli_result;
                            7'b0100000: alu_calc = I_srai_result;
                            default:    alu_calc = 32'd0;
                        endcase
                    end
                    default: alu_calc = 32'd0;
                endcase
            end

            OP_LOAD: begin
                eff_addr_calc = L_ea_result;
            end

            OP_STORE: begin
                eff_addr_calc = S_ea_result;
            end

            OP_BRANCH: begin
                case (func3)
                    3'b000: pc_calc  = B_beq_next_pc;
                    3'b001: pc_calc  = B_bne_next_pc;
                    3'b100: pc_calc  = B_blt_next_pc;
                    3'b101: pc_calc  = B_bge_next_pc;
                    3'b110: pc_calc  = B_bltu_next_pc;
                    3'b111: pc_calc  = B_bgeu_next_pc;
                    default: pc_calc = pc + 32'd4;
                endcase
            end

            OP_LUI: begin
                alu_calc = U_lui_result;
            end

            OP_AUIPC: begin
                alu_calc = U_auipc_result;
            end

            OP_JAL: begin
                alu_calc = J_jal_writeback_result;
                pc_calc  = J_jal_next_pc;
            end

            OP_JALR: begin
                alu_calc = I_jalr_writeback_result;
                pc_calc  = I_jalr_next_pc;
            end

            default: begin
                alu_calc      = 32'd0;
                eff_addr_calc = 32'd0;
                pc_calc       = pc + 32'd4;
            end
        endcase
    end
endmodule