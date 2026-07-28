// instr_reg
// alu_out_reg
// mem_data_reg
// store_data_reg

// Q: how do we know if a signal need to be latched
// A: 1) If a value is produced in one FSM state but used in a later FSM state, latch it.
//    2) If the producer is synchronous memory/BRAM, expect to latch or wait for its output.
//      (because we cannot use it right away if it's not latched, cuz it's synchronous access)

import cpu_pkg::*;

module cpu #(
    // INIT_FILE = the program this CPU runs (the .mem you flash). $readmemb resolves
    // this path against Vivado's RUN directory, not the source tree -- read the synth
    // log to confirm it was picked up; if not, use an absolute path. (A path Vivado
    // can't find loads memory as all-zero, so the CPU just runs nothing.)
    parameter INIT_FILE = "mems/test0.mem"
)(
    input  logic       clk,         // system clock
    input  logic       rst,         // reset button (btn 0 on Boolean Board)     
    input  logic       rx_empty,    // peripheral I/O fifo empty or not
    input  logic [7:0] rx_data,     // next peripheral I/O read data
    output logic       rx_pop,      // trigger line for reading from peripheral I/O
    input  logic       tx_full,     // peripheral I/O fifo full or not
    output logic [7:0] tx_data,     // data to be written to peripheral I/O fifo
    output logic       tx_push      // trigger line for writing to peripheral I/O
);  
    /** ###########################
        #### logic declaration ####
        ########################### */

    // FSM / Controller
    state_t state;                  // FSM state 

    logic pc_en;                    // update PC register enable ctrl line
    logic mem_fetch_en;             // memory read instr enable ctrl lin
    logic mem1_ren;                 // read main RAM enable ctrl line
    logic mem2_wen;                 // write to main RAM enable ctrl line
    logic reg_wen;                  // write register enable ctrl line
    logic ecall_en;                 // peripheral I/O enable line
    logic ebreak_en;                // ebreak system call enable line
    logic block_signal;             // blocking instruction signal fed back to cpu from system (invalid read or write to I/O peripheral)
    logic halt_signal;              // halting cpu signal

    // PC
    logic [MEM_ADDR_BIT-1:0] pc;

    // Instruction
    logic [31:0] instr_fetch;       // fetched instruction
    logic [31:0] instr_reg;         // register that stores fetched instruction

    // Decode
    logic [6:0] opcode;
    logic [4:0] rd;
    logic [2:0] func3;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [6:0] func7;

    // Immediates
    logic [31:0]  imm_I, imm_S, imm_B, imm_U, imm_J;
    
    // Register
    logic [31:0] reg_data1;
    logic [31:0] reg_data2;

    // Decode pipeline registers
    logic [6:0]  opcode_reg;
    logic [4:0]  rd_reg;
    logic [2:0]  func3_reg;
    logic [6:0]  func7_reg;
    logic [4:0]  rs1_reg;
    logic [4:0]  rs2_reg;

    logic [31:0] imm_I_reg;
    logic [31:0] imm_S_reg;
    logic [31:0] imm_B_reg;
    logic [31:0] imm_U_reg;
    logic [31:0] imm_J_reg;

    logic [31:0] reg_data1_reg;
    logic [31:0] reg_data2_reg;

    // ALU 
    // *** decode stage ***
    alu_op_t     alu_op_sel;
    alu_op_t     alu_op_sel_reg;
    // *** alu input data selection mux ***
    logic [31:0] alu_src_a;
    logic [31:0] alu_src_b;
    // *** ALU ***
    logic [31:0] alu_out;
    logic [31:0] alu_out_reg;

    // BRAM
    logic [31:0] mem1_data;

    // BRAM formatting
    logic        bram_mode;
    logic [31:0] formatted_mem_out;

    // Store source data
    // value read from reg2, for sb sx sh 
    // store instructions: store value from reg2 to memory
    logic [31:0] store_data_reg; 

    // System call
    logic        ecall_sel;        // 0 tx, 1 rx
    logic [31:0] syscall_out;     // reg10_out

    // Writeback mux (register write from ecall ro normal register writeback from alu)
    logic [31:0] final_reg_wdata;
    logic [4:0]  final_reg_w_ind;

    /** #################################
        ######## logic assignment #######
        ################################# */
    assign bram_mode = (opcode_reg == OP_STORE);
    assign ecall_sel = (reg_data1_reg == 32'd1); // based on register x17, determine it's putchar or getchar

    /** #################################
        #### submodule instantiation ####
        ################################# */
    controller u_controller (
        .clk(clk),
        .rst(rst),
        .instr(instr_reg),
        .halt_signal(halt_signal),
        .block_signal(block_signal),
        .ecall_sel(ecall_sel),

        .state(state),

        .opcode(opcode),
        .rd(rd),
        .func3(func3),
        .rs1(rs1),
        .rs2(rs2),
        .func7(func7),

        .imm_I(imm_I),
        .imm_S(imm_S),
        .imm_B(imm_B),
        .imm_U(imm_U),
        .imm_J(imm_J),

        .alu_op_sel(alu_op_sel),

        .pc_en(pc_en),
        .reg_wen(reg_wen),
        .mem1_ren(mem1_ren),
        .mem2_wen(mem2_wen),
        .fetch_en(mem_fetch_en),
        .ecall_en(ecall_en),
        .ebreak_en(ebreak_en)
    );

    register u_register (
        .clk(clk),
        .rst(rst),
        .reg_wen(reg_wen),
        .reg_r_ind1(rs1),
        .reg_r_ind2(rs2),
        .reg_w_ind(final_reg_w_ind),
        .reg_wdata(final_reg_wdata),
        .reg_data1(reg_data1),
        .reg_data2(reg_data2)
    );

    alu_data_src_mux u_alu_data_src_mux (
    .opcode(opcode_reg),
    .func3(func3_reg),
    .imm_I(imm_I_reg),
    .imm_S(imm_S_reg),
    .imm_U(imm_U_reg),
    .rs1_data(reg_data1_reg),
    .rs2_data(reg_data2_reg),
    .pc(pc),

    .alu_src_a(alu_src_a),
    .alu_src_b(alu_src_b)
);

    alu u_alu (
        .alu_op_sel(alu_op_sel_reg),
        .alu_src_a(alu_src_a),
        .alu_src_b(alu_src_b),

        .alu_out(alu_out)
    );

    PC u_pc (
        .clk(clk),
        .rst(rst),
        .pc_en(pc_en),
        .opcode(opcode_reg),
        .alu_out(alu_out_reg),
        .imm_I(imm_I_reg),
        .imm_B(imm_B_reg),
        .imm_J(imm_J_reg),
        .rs1_data(reg_data1_reg),
        .pc(pc)
    );

    bram #(
        .INIT_FILE(INIT_FILE)
    ) u_bram (
        .rst(rst),
        .clk(clk),
        .mem1_ren(mem1_ren),
        .mem2_wen(mem2_wen),
        .mem_fetch_en(mem_fetch_en),
        .pc(pc),
        .eff_addr(alu_out_reg[MEM_ADDR_BIT-1:0]),
        .mem2_data_in(formatted_mem_out),
        .mem1_data(mem1_data),
        .instr_fetch(instr_fetch)
    );

    bram_formatting u_bram_formatting (
        .mode(bram_mode),
        .func3(func3_reg),
        .addr_offset(alu_out_reg[1:0]),
        .mem_in(mem1_data),
        .reg_in(store_data_reg),
        .formatted_mem_out(formatted_mem_out)
    );

    system_call u_system_call (
        .rst(rst),
        .clk(clk),
        .ecall_en(ecall_en),
        .ebreak_en(ebreak_en),
        .ecall_sel(ecall_sel),

        .rx_empty(rx_empty),
        .rx_data(rx_data),
        .rx_pop(rx_pop),
        .reg10_out(syscall_out),

        .reg10_in(reg_data2_reg),
        .tx_full(tx_full),
        .tx_data(tx_data),
        .tx_push(tx_push),

        .halt_signal(halt_signal),
        .block_signal(block_signal)
    );

    writeback_mux u_writeback_mux (
        .opcode(opcode_reg),
        .rd(rd_reg),
        .alu_out_reg(alu_out_reg),
        .mem_out(formatted_mem_out),
        .ecall_en(ecall_en),
        .ecall_sel(ecall_sel),
        .block_signal(block_signal),
        .syscall_out(syscall_out),

        .final_reg_wdata(final_reg_wdata),
        .final_reg_w_ind(final_reg_w_ind)
    );

    // intermediate flip flops for latches over states
    always_ff @(posedge clk) begin
        if (rst) begin
            alu_op_sel_reg    <= '0;
            alu_out_reg       <= '0;
            store_data_reg    <= '0;
            opcode_reg        <= '0;
            rd_reg            <= '0;
            func3_reg         <= '0;
            func7_reg         <= '0;
            rs1_reg           <= '0;
            rs2_reg           <= '0;
            imm_I_reg         <= '0;
            imm_S_reg         <= '0;
            imm_B_reg         <= '0;
            imm_U_reg         <= '0;
            imm_J_reg         <= '0;
            reg_data1_reg     <= '0;
            reg_data2_reg     <= '0;
        end

        else begin
            // note: instr_fetch and mem1_data both retrieve from bram at the clock edge, so the new data is only available at the next cycle
            if (state == IR)      instr_reg   <= instr_fetch;
            if (state == EXECUTE) alu_out_reg <= alu_out;
            if (state == DECODE) begin
                alu_op_sel_reg    <= alu_op_sel;
                store_data_reg    <= reg_data2;
                opcode_reg        <= opcode;
                rd_reg            <= rd;
                func3_reg         <= func3;
                func7_reg         <= func7;
                rs1_reg           <= rs1;
                rs2_reg           <= rs2;
                imm_I_reg         <= imm_I;
                imm_S_reg         <= imm_S;
                imm_B_reg         <= imm_B;
                imm_U_reg         <= imm_U;
                imm_J_reg         <= imm_J;
                reg_data1_reg     <= reg_data1;
                reg_data2_reg     <= reg_data2;
            end
        end 
    end

endmodule