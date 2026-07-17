module register(
    input  logic reg_wen,    // note: normal writeback & ecall writeback
    input  logic reg_r_ind1, // register index, ie. which register to read from; if is_ecall, ind1 = x17, ind2 = x10
    input  logic reg_r_ind2,
    input  logic reg_w_ind,
    input  logic [31:0] reg_wdata,
    output logic [31:0] reg_data1,
    output logic [31:0] reg_data2

    // this section is for system_call.sv
    // note: system call always interact with a fixed register (register x10)
    input  logic ecall_writeback_signal;
    output logic reg17;
    output logic [31:0] reg10_out_data;
    input  logic [31:0] reg10_in_data;
); 

    logic [31:0] regs [31:0];

    assign reg_17 = regs[17][0];
    assign reg10_out_data = regs[10];

    assign reg_data1 = (reg_r_ind1 == 5'd0) ? 32'd0 : regs[reg_r_ind1];
    assign reg_data2 = (reg_r_ind2 == 5'd0) ? 32'd0 : regs[reg_r_ind2];

    always_ff @(posedge_clk) begin
        if (rst) begin
            for (int i = 0; i < 32; i++) begin
                regs[i] <= '0;
            end
            reg_data1 <= 32'd0;
            reg_data2 <= 32'd0;
        end

        else if (reg_wen) begin
            regs[reg_w_ind] <= (reg_w_ind == 5'd0) ? 32'd0 : reg_wdata;
        end

        else if (ecall_writeback_signal) begin
            regs[10] <= reg10_in_data;
        end
    end

endmodule