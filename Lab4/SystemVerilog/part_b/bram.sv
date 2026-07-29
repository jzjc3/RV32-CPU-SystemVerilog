import cpu_pkg::*;

module bram #(
    parameter INIT_FILE = "mems/test0.mem"
)(
    input  logic rst,
    input  logic clk,
    input  logic mem_ren, // at mem1 state, can only read
    input  logic mem_wen, // at mem2 state: 1) if it's load: won't write back, 2) if it's store: will write back
    // note: if the instruction is STORE, for both mem1 and mem2 stage the address into BRAM will be eff_addr
    input  logic [MEM_ADDR_BIT-1:0] mem_addr,  // retrieved address is either pc or the calculated effected address from alu
    input  logic [31:0] mem_data_in,  // data to be stored into BRAM at mem2 stage. from bram_formatting.sv
    output logic [31:0] mem_data_out // data output from bram at fetch or mem1 stage
);

    logic [31:0] mem [0:MEM_LINE-1];
    
    logic [MEM_ADDR_BIT-3:0] mem_addr_aligned;
    assign mem_addr_aligned = mem_addr[MEM_ADDR_BIT-1:2];
    
    initial begin
        $readmemb(INIT_FILE, mem);
    end
    
    always_ff @(posedge clk) begin
        if (rst) begin // TODO clear mem not these
            mem_data_out <= '0;
        end

        else if (mem_ren) begin
            mem_data_out <= mem[mem_addr_aligned];
        end

        else if (mem_wen) begin
            mem[mem_addr_aligned] <= mem_data_in;
        end
    end
endmodule