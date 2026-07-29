/** register.sv
  * 32-entry integer register file with two read ports and one write port.
  */
module register(
    input  logic clk,                  // system clock
    input  logic rst,                  // synchronous reset
    input  logic reg_wen,               // note: normal writeback & ecall writeback
    input  logic [4:0]  reg_r_addr1,    // register addrex, ie. which register to read from; if is_ecall, addr1 = x17, addr2 = x10
    input  logic [4:0]  reg_r_addr2,    // second read register address
    input  logic [4:0]  reg_w_addr,     // normal instruction;
                                        // address = rd; is_ecall, address = addr_10
    input  logic [31:0] reg_wdata,      // writeback data
    output logic [31:0] reg_data1,      // first read data
    output logic [31:0] reg_data2       // second read data
); 

    logic [31:0] regs [31:1];           // regs[0] will never be used, saving one logic

    // read from register is combinational
    assign reg_data1 = (reg_r_addr1 == 5'd0) ? 32'd0 : regs[reg_r_addr1];
    assign reg_data2 = (reg_r_addr2 == 5'd0) ? 32'd0 : regs[reg_r_addr2];

    // write to register is sequential
    always_ff @(posedge clk) begin
        if (rst)
            for (int i = 1; i < 32; i++) regs[i] <= '0;

        else if (reg_wen & (reg_w_addr != 5'd0))
            regs[reg_w_addr] <= reg_wdata;
    end

endmodule
