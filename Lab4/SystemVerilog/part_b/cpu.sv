// cpu.sv -- THIS IS THE FILE YOU EDIT. Implement your CPU here.
// New here? What a CPU is and the rules it must follow: ../../doc/CPU_explained.md
// It runs your program (loaded from INIT_FILE) and reaches the outside world
// ONLY through the byte mailbox below (the rx/tx FIFOs from Part A). Everything
// inside -- memory, registers, datapath, how you decode and execute -- is yours.
//
//   clk      : system clock.
//   rst      : on-board button 0 (active-high). Use it however you like.
//
//   input  side (a byte arrived from the Pi  -> your getchar / scanf):
//     rx_empty : 1 = nothing is waiting
//     rx_data  : the oldest waiting byte (valid while rx_empty is 0)
//     rx_pop   : raise for one clock to consume rx_data
//
//   output side (a byte you send back to the Pi -> your putchar / print):
//     tx_full  : 1 = no room to send right now
//     tx_data  : the byte you want to send
//     tx_push  : raise for one clock to send tx_data


/** Instructions
  * how to pull an instruction apart into its fields and decide what it is,
  * how to build the register file, the ALU, and the memory ports,
  * whether each instruction takes one clock cycle or several,
  * Does the CPU need an FSM? What are its states?
  * how to drive the mailbox handshake (rx_pop, tx_push) at the right moments,
  * how ecall to actually stall your processor on empty/full.
  */ 

// testing: fetch/ecall, the ALU, branches, loads/stores, scanf/print, mul, / and %, recursion, arrays, then the comprehensive test9

module cpu #(
    parameter int MEM_SIZE_BYTES = 65536,    // byte-addressable memory size (64 KiB)
    // INIT_FILE = the program this CPU runs (the .mem you flash). $readmemb resolves
    // this path against Vivado's RUN directory, not the source tree -- read the synth
    // log to confirm it was picked up; if not, use an absolute path. (A path Vivado
    // can't find loads memory as all-zero, so the CPU just runs nothing.)
    parameter     INIT_FILE      = "mems/test0.mem"
) (
    input  logic       clk,
    input  logic       rst,
    input  logic       rx_empty,
    input  logic [7:0] rx_data,
    output logic       rx_pop,
    input  logic       tx_full,
    output logic [7:0] tx_data,
    output logic       tx_push
);
    localparam MEM_LINE = 65536 / 4;
    localparam PC_LENGTH = $clog2(MEM_SIZE_BYTES);
    
    // for SHIFT and IMMEDIATE instruction
    function automatic logic [31:0] sext12(
        input logic [11:0] value
    );
        sext12 = {{(20){value[11]}}, value};
    endfunction
    
    // for BRANCH instruction
    function automatic logic [31:0] sext13(
            input logic [12:0] value
        );
            sext13 = {{(19){value[12]}}, value};
    endfunction
    
    // for JUMP instruction
    function automatic logic [31:0] sext21(
        input logic [20:0] value
    );
        sext21 = {{(11){value[20]}}, value};
    endfunction

    typedef enum logic [2:0]{
        FETCH,
        DECODE,
        EXECUTE,
        MEMORY,
        WRITEBACK,
        HALT
    } state_t;

    typedef enum logic [6:0]{
        OP_REGISTER = 7'b0110011,
        OP_IMM      = 7'b0010011,
        OP_LOAD     = 7'b0000011,
        OP_STORE    = 7'b0100011,
        OP_BRANCH   = 7'B1100011,
        OP_LUI      = 7'B0110111,
        OP_AUIPC    = 7'b0010111,
        OP_JAL      = 7'b1101111,
        OP_JALR     = 7'b1100111,
        OP_SYSTEM   = 7'b1110011
    } opcode_t;

    // FSM (instead of pipelined CPU)
    state_t state = FETCH;
    state_t next_state;

    // Register
    logic [31:0] regs [31:0];

    // Memory
    logic [PC_LENGTH-1:0] pc = 0;
    logic [PC_LENGTH-1:0] next_pc;
    /** logic declaration of "mem" order matters 
      * this declaration makes mem[0] the first line of instruction
      */
    logic [31:0] mem [0:MEM_LINE-1]; // MEM_LENTGH lines, 32 bits per line

    // Instruction / Fetch
    logic [31:0] instr;

    // Decode
    logic [6:0]  opcode;
    logic [4:0]  rd;
    logic [2:0]  func3;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic [6:0]  func7;

    logic [11:0] imm_I; // 12
    logic [11:0] imm_S; // 12
    logic [12:0] imm_B; // 13   // last bit is always 0 b/c alignment
    logic [31:0] imm_U; // 32   // upper 20 bits
    logic [20:0] imm_J; // 21   // last bit is always 0 b/c alignment

    // Execution
    logic [31:0] alu_result;
    logic [31:0] alu_reg;
    logic [31:0] ea; // effective address
    logic [31:0] ea_reg;

    // Memory
    logic [31:0] mem_reg;

    initial begin
        $readmemb(INIT_FILE, mem);
    end

    always_comb begin : FSM
        next_state = HALT;
        case (state)
            FETCH: next_state = DECODE;
            DECODE: next_state = EXECUTE;
            EXECUTE: next_state = MEMORY;
            MEMORY: next_state = WRITEBACK;
            WRITEBACK: begin
                if (opcode == 7'b1110011 & func3 == '0 & {func7, rs2} == 12'h73) begin // ecall
                    next_state = HALT;
                end 
                else next_state = FETCH;
            end
            HALT: next_state = HALT;
            default: next_state = HALT;
        endcase
    end

    // Fetch stage: restrieving data from RAM is synchronous

    always_comb begin : decode_stage
        opcode = instr[6:0];
        rd     = instr[11:7];
        func3  = instr[14:12];
        rs1    = instr[19:15];
        rs2    = instr[24:20];
        func7  = instr[31:25];

        rs1_data = (rs1 == 5'd0) ? 32'd0 : regs[rs1];
        rs2_data = (rs2 == 5'd0) ? 32'd0 : regs[rs2];

        imm_I = instr[31:20];
        imm_S = {instr[31:25], instr[11:7]};
        imm_B = {instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
        imm_U = {instr[31:12], 12'b0};
        imm_J = {instr[31], instr[30:21], instr[20], instr[19:12], 1'b0};

    end 

    // ALU
    always_comb begin: execute_stage
        alu_result = 32'd0;
        ea         = 32'd0;
        next_pc    = pc + 3'd4;

        case(opcode)
            OP_REGISTER: begin
                case (func3)
                    3'b000: begin
                        case (func7)
                            7'b0000000: alu_result = rs1_data + rs2_data; // add
                            7'b0100000: alu_result = rs1_data - rs2_data; // sub
                            7'b0000001: alu_result = rs1_data * rs2_data; // mul
                            default:    alu_result = 32'd0;
                        endcase
                    end
                    3'b001: alu_result = rs1_data << rs2_data[4:0]; // sll
                    3'b010: alu_result = ($signed(rs1_data) < $signed(rs2_data)) ? 32'd1 : 32'd0; // slt
                    3'b011: alu_result = (rs1_data < rs2_data) ? 32'd1 : 32'd0; // sltu
                    3'b100: alu_result = rs1_data ^ rs2_data; // xor
                    3'b101: begin
                        case (func7)
                            7'b0000000: alu_result = rs1_data >> rs2_data[4:0]; // srl
                            7'b0100000: alu_result = $signed(rs1_data) >>> rs2_data[4:0]; // sra
                            default:    alu_result = 32'd0;
                        endcase
                    end
                    3'b110: alu_result = rs1_data | rs2_data; // or
                    3'b111: alu_result = rs1_data & rs2_data; // and
                    default: alu_result = 32'b0;
                endcase
            end
            OP_IMM: begin
                case (func3)
                    // sign-extended
                    3'b000: alu_result = rs1_data + sext12(imm_I); //addi
                    3'b010: alu_result = ($signed(rs1_data) < $signed(sext12(imm_I))) ? 1:0; // slti
                    3'b011: alu_result = (rs1_data < sext12(imm_I)) ? 1:0; //sltiu
                    3'b100: alu_result = rs1_data ^ sext12(imm_I); //xori
                    3'b110: alu_result = rs1_data | sext12(imm_I); // ori
                    3'b111: alu_result = rs1_data & sext12(imm_I); // andi

                    //shift-immediate
                    3'b001: alu_result = rs1_data << imm_I[4:0];
                    3'b101: 
                        case(func7) 
                            7'b0000000: alu_result = rs1_data >> imm_I[4:0];
                            7'b0100000: alu_result = $signed(rs1_data) >>> imm_I[4:0];
                        endcase
                    default: alu_result = 32'b0;
                endcase
            end
            OP_LOAD: begin
                ea = rs1_data + sext12(imm_I);
            end
            OP_STORE: begin
                ea = rs1_data + sext12(imm_S);   
            end
            OP_BRANCH: begin
                case (func3)
                    3'b000: next_pc = (rs1_data == rs2_data) ? pc + sext13(imm_B) : pc + 3'd4;
                    3'b001: next_pc = (rs1_data != rs2_data) ? pc + sext13(imm_B) : pc + 3'd4;
                    3'b100: next_pc = ($signed(rs1_data) < $signed(rs2_data)) ? pc + sext13(imm_B) : pc + 3'd4;
                    3'b101: next_pc = ($signed(rs1_data) >= $signed(rs2_data)) ? pc + sext13(imm_B) : pc + 3'd4;
                    3'b110: next_pc = (rs1_data < rs2_data) ? pc + sext13(imm_B) : pc + 3'd4;
                    3'b111: next_pc = (rs1_data >= rs2_data) ? pc + sext13(imm_B) : pc + 3'd4;
                    default: next_pc = pc + 3'd4;
                endcase
            end
            OP_LUI: begin
                alu_result = imm_U << 12;
            end
            OP_AUIPC: begin
                alu_result = pc + (imm_U << 12);
            end
            OP_JAL: begin
                alu_result = pc + 3'd4;
                next_pc = pc + sext21(imm_J);
            end
            OP_JALR: begin
                alu_result = pc + 3'd4;
                next_pc = (rs1 + sext12(imm_I)) & (~(32'd1));
            end
            // System instruction isnot handled here. because the goal is to block the next instruction, so stop at teh writeback satge
            // also, ecall is mostly influencing the writeback to register a0
            default: begin // the only case is OP_SYSTEM
                alu_result = 32'd0;
                ea         = 32'd0;
                next_pc    = pc + 3'd4;
            end 
        endcase
    end

    // other registers other than 1) memory access(instr, mem_reg)  2) writeback (registers, state update, pc update)
    // it turns out only Execute stage left
    always_ff @(posedge clk) begin
        if (rst) begin
            alu_reg = '0;
            ea_reg =  '0; // effective address (for accessing RAM), used for OP_LOAD, OP_STORE
        end
        else begin
            if (state == EXECUTE) begin
                alu_reg <= alu_result;
                ea_reg  <= ea;
            end
        end
    end
    
    // RAM access, Fetch and Memory stage
    always_ff @(posedge clk) begin  // less strict, allow us to initilize RAM
        if (rst) begin
            instr <= '0;
        end
        else begin
            case (state)
                FETCH: begin
                    instr <= mem[pc[PC_LENGTH-1:2]]; // index = pc / 4;
                end
                MEMORY: begin
                    case (opcode)
                        // LOAD from memory
                        OP_LOAD: begin
                            case(func3)
                                3'b000 , 3'b100: mem_reg <= mem[ea_reg[31:2]][ea_reg[1:0]*8 +: 8]; // always byte aligned, so no need to case
                                3'b001 , 3'b101: begin
                                    case (ea_reg[1])
                                        1'b0: mem_reg <= mem[ea_reg[31:2]][15:0];
                                        1'b1: mem_reg <= mem[ea_reg[31:2]][31:16];
                                    endcase
                                end
                                3'b010: mem_reg <= mem[ea_reg[31:2]];
                            endcase
                        end
                        // STORE to memory operation
                        OP_STORE: begin
                            case (func3) 
                                // for alignment
                                3'b000: begin // sb
                                    case (ea_reg[1:0])
                                        2'b00: mem[ea_reg[31:2]][7:0]   <= rs2_data[7:0];
                                        2'b01: mem[ea_reg[31:2]][15:8]  <= rs2_data[7:0];
                                        2'b10: mem[ea_reg[31:2]][23:16] <= rs2_data[7:0];
                                        2'b11: mem[ea_reg[31:2]][31:24] <= rs2_data[7:0];
                                    endcase 
                                end 
                                3'b001: begin // sh
                                    case (ea_reg[1]) 
                                        1'b0: mem[ea_reg[31:2]][15:0]  <= rs2_data[15:0];
                                        1'b1: mem[ea_reg[31:2]][31:16] <= rs2_data[15:0];
                                    endcase 
                                end
                                3'b010: mem[ea_reg[31:2]][31:0] <= rs2_data; // sw
                            endcase
                        end 
                    endcase
                end 
            endcase
        end 
    end

    // Writeback stage
    // pc: 1) update next_pc in execute stage  2) update pc to next_pc during writeback satge
    always_ff @(posedge clk) begin
        if (rst) begin
            pc    <= '0;
            state <= FETCH;
            tx_push <= '0;
            rx_pop <= '0;
            for (int i = 0; i < 32; i++) begin
                regs[i] <= '0;
            end
        end
        else begin
            state <= next_state;
            tx_push <= '0;
            rx_pop <= '0;
            if (state == WRITEBACK) begin
                pc <= next_pc;

                // update register, system (ecall, ebreak)
                case (opcode)
                    // standard case, write to rd after finish the entire instruciton duing the Writeback stage
                    OP_REGISTER, OP_IMM, OP_LUI, OP_AUIPC, OP_JAL, OP_JALR: begin
                        if (rd != '0) regs[rd] <= alu_reg; // x0 can never be written to
                    end
                    OP_LOAD: begin
                        case(func3)
                            3'b000: regs[rd] <= {{(24){mem_reg[7]}}, mem_reg[7:0]};
                            3'b001: regs[rd] <= {{(16){mem_reg[15]}}, mem_reg[15:0]};
                            3'b010: regs[rd] <= mem_reg;
                            3'b100: regs[rd] <= {{(24){1'b0}}, mem_reg[7:0]};
                            3'b101: regs[rd] <= {{(16){1'b0}}, mem_reg[15:0]};
                        endcase
                    end

                    // ecall, ebreak
                    OP_SYSTEM: begin
                        case(instr)
                            32'h00000073: begin // ecall
                            /** register x17 (a7), register x10 (a0)
                            * x17 = 1: getchar, read one input byte into a0
                            * x17 = 0: putchar, send the low byte of a0 to the output
                            */
                                if (regs[17] == 1'b0) begin
                                    if (tx_full) state <= WRITEBACK;
                                    else begin
                                        tx_data <= regs[10][7:0];
                                        tx_push <= 1'b1;
                                    end
                                end
                                
                                else begin
                                    if (rx_empty) state <= WRITEBACK;
                                    else begin
                                        regs[10] <= {24'b0, rx_data};
                                        rx_pop <= 1'b1;
                                    end
                                end
                            end
                            32'h00100073: begin // ebreak
                                state <= HALT;
                                pc <= pc;      // if halt, leave the pc as it is, do not update
                            end
                        endcase
                    end

                    //default: OP_STORE,OP_ BRANCHES
                endcase 
            end
        end
    end
endmodule : cpu
