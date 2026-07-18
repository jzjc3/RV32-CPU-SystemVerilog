import cpu_pkg::*;

module writeback_mux (
    input  logic [6:0]  opcode,
    input  logic [4:0]  rd,
    input  logic [31:0] alu_calc_reg,
    input  logic [31:0] mem_out,
    input  logic        ecall_en,
    input  logic        ecall_sel,      // 0: putchar, 1: getchar
    input  logic        block_signal,
    input  logic [31:0] syscall_out,

    output logic [31:0] normal_writeback_data,
    output logic [31:0] final_reg_wdata,
    output logic [4:0]  final_reg_w_ind
);

    always_comb begin
        normal_writeback_data = 32'b0;

        case (opcode)
            OP_REGISTER,
            OP_IMM,
            OP_LUI,
            OP_AUIPC,
            OP_JAL,
            OP_JALR: begin
                normal_writeback_data = alu_calc_reg;
            end

            OP_LOAD: begin
                normal_writeback_data = mem_out;
            end

            default: begin
                normal_writeback_data = 32'b0;
            end
        endcase
    end

    always_comb begin
        final_reg_w_ind = rd;
        final_reg_wdata = normal_writeback_data;

        if (ecall_en && ecall_sel && !block_signal) begin
            final_reg_w_ind = 5'd10;       // a0
            final_reg_wdata = syscall_out; // getchar result
        end
    end

endmodule
