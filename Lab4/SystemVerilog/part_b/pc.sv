/** pc.sv: 
  * internal comb logic: select next_pc to be from ALU or pc+4
  * Sequential: update PC value
  * pc value output
  */

import cpu_pkg::*;

module PC (
    input  logic        clk,           // system clock
    input  logic        rst,           // synchronous reset
    input  logic        pc_en,          // if the PC module/device should be activicated
    input  logic [6:0]  opcode,        // latched instruction opcode
    input  logic [31:0] alu_out,        // for BRANCH: T/F signal for go to branch or no
    input  logic [31:0] imm_B,          // branching address depends on value of imm_B
    input  logic [31:0] imm_J,         // JAL immediate offset
    input  logic [31:0] imm_I,         // JALR immediate offset
    input  logic [31:0] rs1_data,       // JALR jump address depends on value stored in register 1
    output logic [MEM_ADDR_BIT-1:0] pc // current program counter
);
    logic [MEM_ADDR_BIT-1:0] next_pc;

    // special cases are: jump (unconditional) AND branch (conditional: alu_ctrl)
    always_comb begin: next_pc_calculation
        case (opcode)
            OP_JAL:    next_pc = pc + imm_J;
            OP_JALR:   next_pc = (rs1_data + imm_I) & ~32'd1;
            OP_BRANCH: next_pc = (alu_out == 32'b0) ? pc + 32'd4 :  pc + imm_B;
            default:   next_pc = pc + 32'd4;
        endcase
    end

    // sequential logic
    always_ff @(posedge clk) begin
        if (rst) begin
            pc <= '0;
        end 
        
        else if (pc_en) begin
            pc <= next_pc; 
        end
    end 

endmodule
