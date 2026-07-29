/** bram_formatting.sv
  * Formats BRAM read/write data for byte, halfword, and word load/store ops.
  */
module bram_formatting(
    input  logic        mode,         // 0: load, 1: store
    input  logic [2:0]  func3,        // load/store size and signedness field
    input  logic [1:0]  addr_offset,  // eff_addr[1:0]
    input  logic [31:0] mem_in,       // for STORE case
    input  logic [31:0] reg_in,       // store source register data

    output logic [31:0] formatted_mem_out // formatted load data or merged store word
);

    // MUX for which byte/halfword to select (byte_aligned purpose)
    logic [7:0]  selected_byte;
    logic [15:0] selected_halfword;

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

    always_comb begin
        case (addr_offset)
            2'b00: selected_byte = mem_in[7:0];
            2'b01: selected_byte = mem_in[15:8];
            2'b10: selected_byte = mem_in[23:16];
            2'b11: selected_byte = mem_in[31:24];
        endcase

        selected_halfword = addr_offset[1] ? mem_in[31:16] : mem_in[15:0];
    end

    // logic assignment
    // 1) LOAD case
    assign l_s8_mem  = {{24{selected_byte[7]}}, selected_byte};
    assign l_s16_mem = {{16{selected_halfword[15]}}, selected_halfword};
    assign l_s32_mem = mem_in;
    assign l_z8_mem  = {{24{1'b0}}, selected_byte};
    assign l_z16_mem = {{16{1'b0}}, selected_halfword};

    // 2) STORE case
    always_comb begin
        s_mem8 = mem_in;
        case (addr_offset)
            2'b00: s_mem8[7:0]   = reg_in[7:0];
            2'b01: s_mem8[15:8]  = reg_in[7:0];
            2'b10: s_mem8[23:16] = reg_in[7:0];
            2'b11: s_mem8[31:24] = reg_in[7:0];
        endcase
    end

    always_comb begin
        s_mem16 = mem_in;
        if (addr_offset[1] == 1'b0) s_mem16[15:0]  = reg_in[15:0];
        else                        s_mem16[31:16] = reg_in[15:0];
    end

    assign s_mem32 = reg_in;

    // 2 cases: case by instruction is LOAD or STORE
    always_comb begin
        case (mode)
            1'b0: begin // load
                case (func3)
                    3'b000:  formatted_mem_out= l_s8_mem;
                    3'b001:  formatted_mem_out= l_s16_mem;
                    3'b010:  formatted_mem_out= l_s32_mem;
                    3'b100:  formatted_mem_out= l_z8_mem;
                    3'b101:  formatted_mem_out= l_z16_mem;
                    default: formatted_mem_out= '0;
                endcase
            end
            1'b1: begin // store
                case(func3)
                    3'b000:  formatted_mem_out = s_mem8;
                    3'b001:  formatted_mem_out = s_mem16;
                    3'b010:  formatted_mem_out = s_mem32;
                    default: formatted_mem_out = '0;
                endcase 
            end
            default:         formatted_mem_out= '0;
        endcase
    end

endmodule
