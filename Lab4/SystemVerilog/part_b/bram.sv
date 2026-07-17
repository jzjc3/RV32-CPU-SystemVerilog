import cpu_pkg::*;

module bram(
    input  logic rst,
    input  logic clk,
    input  logic mem1_ren, // at mem1 state, can only read
    input  logic mem2_wen, // at mem2 state: 1) if it's load: won't write back, 2) if it's store: will write back
    input  logic mem_fetch_en,
    input  logic [MEM_ADDR_BIT-1:0] pc_aligned;
    // note: if the instruction is STORE, for both mem1 and mem2 stage the address into BRAM will be eff_addr
    input  logic [MEM_ADDR_BIT-1:0] eff_addr_aligned, // we are only using [MEM_ADDR_BIT-1:2] of eff_addr b/c we want to extract the entire 32 bits
    input  logic [31:0] mem2_data_in; // data to be stored into BRAM at mem2 stage
    output logic [31:0] mem1_data, // data output from bram at mem1 stage
    output logic [31:0] instr_fetch  // instruction output from bram at fetch stage
);

    logic [31:0] mem [0:MEM_LINE-1];

    
    initial begin
        $readmemb(INIT_FILE, mem);
    end
    
    always_ff @(posedge_clk) begin
        if (rst) begin
            mem1_data <= '0;
            instr_fetch <= '0;
        end

        else if (mem1_ren) begin
            mem1_data <= mem[eff_addr_aligned];
        end

        else if (mem2_ren) begin
            mem[eff_addr_aligned] <= mem2_data_in;
        end

        else if (mem_fetch_en) begin
            instr_fetch <= mem[pc_aligned];
        end
    end
endmodule