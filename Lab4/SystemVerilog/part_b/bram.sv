import cpu_pkg::*;

/** bram.sv
  * Synchronous word-addressed BRAM used for instruction fetch and data access.
  */
module bram #(
    parameter INIT_FILE = "mems/test9.mem"
)(
    input  logic rst,                           // synchronous reset for read data output
    input  logic clk,                           // system clock
    input  logic mem_ren,                       // at fetch / mem1 state, can only read
    input  logic mem_wen,                       // at mem2 state: 1) if it's load: won't write back, 2) if it's store: will write back
                                                // note: if the instruction is STORE, for both mem1 and mem2 stage the address into BRAM will be eff_addr
    input  logic [MEM_ADDR_BIT-1:0] mem_addr,   // retrieval address is either pc or the calculated effective address from alu
    input  logic [31:0] mem_data_in,            // data to be stored into BRAM at mem2 stage. from bram_formatting.sv
    output logic [31:0] mem_data_out            // data output from bram at fetch or mem1 stage
);

    logic [31:0] mem [0:MEM_LINE-1];
    
    logic [MEM_ADDR_BIT-3:0] mem_addr_aligned;
    assign mem_addr_aligned = mem_addr[MEM_ADDR_BIT-1:2];
    
    initial $readmemb(INIT_FILE, mem);
    
    always_ff @(posedge clk) begin
        if (rst) mem_data_out <= '0;

        else if (mem_ren) mem_data_out <= mem[mem_addr_aligned];

        else if (mem_wen) mem[mem_addr_aligned] <= mem_data_in;
    end
endmodule
