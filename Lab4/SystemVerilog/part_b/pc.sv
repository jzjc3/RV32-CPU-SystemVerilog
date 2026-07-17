/** pc.sv: 
  * internal comb logic: select next_pc to be from ALU or pc+4
  * Sequential: update PC value
  * pc value output
  */

import cpu_pkg::*;

module PC (
    input  logic clk,
    input  logic rst,
    input  logic pc_en,  // if the PC module/device should be activicated
    input  logic pc_sel, // 0: pc + 4, 1: input from alu
    input  logic [MEM_ADDR_BIT-1:0] pc_from_alu,
    output logic [MEM_ADDR_BIT-1:0] pc
);
    localparam logic [MEM_ADDR_BIT-1:0] next_pc;

    // combinational logic
    always_comb begin
        case (pc_sel)
            1'b0: next_pc = pc + 3'd4;
            1'b1: next_pc = pc_from_alu;
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

    // output generation
    always_comb begin
        // output is just the pc value, so no need for a separate comb logic for output computation
    end

endmodule