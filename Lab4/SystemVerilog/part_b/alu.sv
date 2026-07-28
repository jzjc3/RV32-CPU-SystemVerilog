import cpu_pkg::*;

// brief: 1) alu calculation output -> rd register
//        2) pc calculation -> pc register
//        3) ea: effective address for main RAM access calculation -> main memory

module alu(
    // all inputs are from decoder/controller. some are formatted
    input  logic [3:0]  alu_op_sel,    // selected operation
    input  logic [31:0] alu_src_a,     // alu calculation data source A
    input  logic [31:0] alu_src_b,     // alu calculation data source B

    output logic [31:0] alu_calc,
);
    always_comb begin : alu_operation_AND_mux // do operaion and select output based on alu_op_sel line
        case (alu_op_sel)
            ALU_ADD:  alu_result = alu_src_a + alu_src_b;
            ALU_SUB:  alu_result = alu_src_a - alu_src_b;
            ALU_MUL:  alu_result = alu_src_a * alu_src_b;
            ALU_SLL:  alu_result = alu_src_a << alu_src_b[4:0];
            ALU_SRA:  alu_result = $signed(alu_src_a) >>> alu_src_b[4:0];
            ALU_SRL:  alu_result = alu_src_a >> alu_src_b[4:0];
            ALU_SLT:  alu_result = ($signed(alu_src_a) < $signed(alu_src_b)) ? 32'd1 : 32'd0;
            ALU_SLTU: alu_result = (alu_src_a < alu_src_b) ? 32'd1 : 32'd0;
            ALU_XOR:  alu_result = alu_src_a ^ alu_src_b;
            ALU_OR:   alu_result = alu_src_a | alu_src_b;
            ALU_AND:  alu_result = alu_src_a & alu_src_b;
            default:  alu_result = 32'd0;
        endcase
    end
 
endmodule