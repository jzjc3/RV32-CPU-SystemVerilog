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
    input  logic [MEM_ADDR_BIT-1:0] pc_from_alu,
    output logic [MEM_ADDR_BIT-1:0] pc
);
    
    // sequential logic
    always_ff @(posedge clk) begin
        if (rst) begin
            pc <= '0;
        end 
        
        else if (pc_en) begin
            pc <= pc_from_alu; 
        end
    end 

    // output generation TODO
    always_comb begin
        // output is just the pc value, so no need for a separate comb logic for output computation
    end

endmodule