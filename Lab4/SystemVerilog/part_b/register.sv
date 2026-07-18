module register(
    input logic clk,
    input logic rst,
    input  logic reg_wen,    // note: normal writeback & ecall writeback
    input  logic [4:0]  reg_r_ind1, // register index, ie. which register to read from; if is_ecall, ind1 = x17, ind2 = x10
    input  logic [4:0]  reg_r_ind2,
    input  logic [4:0]  reg_w_ind,  // normal instruction, ind = rd; is_ecall, ind_10
    input  logic [31:0] reg_wdata,
    output logic [31:0] reg_data1,
    output logic [31:0] reg_data2
); 

    logic [31:0] regs [31:0];

    assign reg_data1 = (reg_r_ind1 == 5'd0) ? 32'd0 : regs[reg_r_ind1];
    assign reg_data2 = (reg_r_ind2 == 5'd0) ? 32'd0 : regs[reg_r_ind2];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 32; i++) begin
                regs[i] <= '0;
            end
        end

        else if (reg_wen) begin
            regs[reg_w_ind] <= (reg_w_ind == 5'd0) ? 32'd0 : reg_wdata;
        end

    end

endmodule