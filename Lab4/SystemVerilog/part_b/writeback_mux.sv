import cpu_pkg::*;

/** writeback_mux.sv
  * Selects register writeback data/address from normal execution or getchar.
  */
module writeback_mux (
    input  logic [6:0]  opcode,        // latched instruction opcode
    input  logic [4:0]  rd,            // latched destination register address
    input  logic [31:0] alu_out_reg,   // latched ALU result
    input  logic [31:0] mem_out,       // formatted load data
    input  logic        ecall_en,      // active during ecall writeback
    input  logic        ecall_sel,      // 0: putchar, 1: getchar
    input  logic        block_signal,  // stalls writeback when I/O blocks
    input  logic [31:0] syscall_out,   // getchar result

    output logic [31:0] final_reg_wdata, // selected register write data
    output logic [4:0]  final_reg_w_addr // selected register write address
);

    logic [31:0] normal_writeback_data;

    always_comb begin
        normal_writeback_data = 32'b0;

        case (opcode)
            OP_REGISTER,
            OP_IMM,
            OP_LUI,
            OP_AUIPC,
            OP_JAL,
            OP_JALR: begin
                normal_writeback_data = alu_out_reg;
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
        final_reg_w_addr = rd;
        final_reg_wdata = normal_writeback_data;

        if (ecall_en && ecall_sel && !block_signal) begin
            final_reg_w_addr = 5'd10;       // a0
            final_reg_wdata = syscall_out; // getchar result
        end
    end

endmodule
