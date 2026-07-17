module bram_formatting(
    input  logic mode, // 0: load, 1: store
    input  logic [3:0] load_sel,
    input  logic [3:0] store_sel,
    input  logic [31:0] mem_in, // for STORE case
    input  logic [31:0] reg_in,

    output logic [31:0] mem_writeback_data, // STORE case
    // LOAD case: formatted read BRAM data
    output logic [31:0] mem_out // LOAD case
);

    // LOAD internal logic
    logic [31:0] l_s8_mem;
    logic [31:0] l_s16_mem;
    logic [31:0] l_s32_mem;
    logic [31:0] l_z8_mem;
    logic [31:0] l_z16_mem;
    // STORE internal logic
    logic [31:0] s_mem8;
    logic [31:0] s_mem16;
    logic [31:0] s_mem32;


    // logic assignment
    assign l_s8_mem  = {{24{mem_in[7]}}, mem_in[7:0]};
    assign l_s16_mem = {{16{mem_in[15]}}, mem_in[15:0]};
    assign l_s32_mem = mem_in;
    assign l_z8_mem  = {{24{1'b0}}, mem_in[7:0]};
    assign l_z16_mem = {{16{1'b0}}, mem_in[15:0]};

    assign s_mem8 = {mem_in[31:8], reg_in[7:0]};
    assign s_mem16 = {mem_in[31:16], reg_in[15:0]};
    assign s_mem32 = reg_in;

    // 2 cases: instruction is LOAD or STORE
    always_comb begin
        mem_out = '0;
        mem_writeback_data = '0;
        case (mode)
            1'b0: begin // load
                case (load_sel)
                    3'b000: mem_out = l_s8_mem;
                    3'b001: mem_out = l_s16_mem;
                    3'b010: mem_out = l_s32_mem;
                    3'b100: mem_out = l_z8_mem;
                    3'b101: mem_out = l_z16_mem;
                    default: mem_out = '0;
                endcase
            end
            1'b1: begin // store
                case(store_sel)
                    3'b000: mem_writeback_data = s_mem8;
                    3'b001: mem_writeback_data = s_mem16;
                    3'b010: mem_writeback_data = s_mem32;
                    default: mem_writeback_data = '0;
                endcase 
            end
            default: begin
                mem_out = '0;
                mem_writeback_data = '0;
            end
        endcase
    end

endmodule