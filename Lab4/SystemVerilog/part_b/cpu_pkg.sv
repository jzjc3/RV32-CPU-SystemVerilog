package cpu_pkg;
    parameter int MEM_SIZE_BYTES = 65536;
    parameter int MEM_LINE = MEM_SIZE_BYTES / 4;
    parameter int MEM_ADDR_BIT = $clog2(MEM_SIZE_BYTES);

    // FSM states
    typedef enum logic [2:0]{
        FETCH,
        IR,  // Istore fetched instruction into nstruction Register
        DECODE,
        EXECUTE,
        MEM1,
        MEM2,
        WRITEBACK,
        HALT
    } state_t;

    // OPCODE
    typedef enum logic [6:0]{
        OP_REGISTER = 7'b0110011, // R-type
        OP_IMM      = 7'b0010011, // I-type
        OP_LOAD     = 7'b0000011, // I-type
        OP_STORE    = 7'b0100011, // S-type
        OP_BRANCH   = 7'B1100011, // B-type
        OP_LUI      = 7'B0110111, // U-type
        OP_AUIPC    = 7'b0010111, // U-type
        OP_JAL      = 7'b1101111, // J-type
        OP_JALR     = 7'b1100111, // I-type
        OP_SYSTEM   = 7'b1110011  // System
    } opcode_t;

    // ALU OPERATIONS
    typedef enum logic [4:0] {
        ALU_ADD,
        ALU_SUB,
        ALU_MUL,
        ALU_SLL,
        ALU_SRA,
        ALU_SRL,
        ALU_SLT,
        ALU_SLTU,
        ALU_XOR,
        ALU_OR,
        ALU_AND,

        ALU_BEQ,
        ALU_BNE,
        ALU_BLT,
        ALU_BGE,
        ALU_BLTU,
        ALU_BGEU
    } alu_op_t;
endpackage

