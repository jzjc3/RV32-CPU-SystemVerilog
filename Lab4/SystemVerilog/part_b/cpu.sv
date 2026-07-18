// instr_reg
// alu_calc_reg
// eff_addr_calc_reg
// pc_calc_reg
// mem_data_reg
// store_data_reg

// Q: how do we know if a signal need to be latched
// A: 1) If a value is produced in one FSM state but used in a later FSM state, latch it.
//    2) If the producer is synchronous memory/BRAM, expect to latch or wait for its output.
//      (because we cannot use it right away if it's not latched, cuz it's synchronous access)

import cpu_pkg::*;

module cpu_top #(
    // INIT_FILE = the program this CPU runs (the .mem you flash). $readmemb resolves
    // this path against Vivado's RUN directory, not the source tree -- read the synth
    // log to confirm it was picked up; if not, use an absolute path. (A path Vivado
    // can't find loads memory as all-zero, so the CPU just runs nothing.)
    parameter INIT_FILE = "mems/test0.mem"
)(
    input  logic       clk,
    input  logic       rst,
    input  logic       rx_empty,
    input  logic [7:0] rx_data,
    output logic       rx_pop,
    input  logic       tx_full,
    output logic [7:0] tx_data,
    output logic       tx_push
);  
    /** ###########################
        #### logic declaration ####
        ########################### */

    // FSM / Controller
    state_t state;

    logic pc_en;
    logic mem_fetch_en;
    logic mem1_ren;
    logic mem2_wen;
    logic reg_wen;
    logic ecall_en;
    logic ebreak_en;
    logic block_signal;
    logic halt_signal;

    // PC
    logic [MEM_ADDR_BIT-1:0] pc;
    logic [MEM_ADDR_BIT-1:0] pc_calc;
    logic [MEM_ADDR_BIT-1:0] pc_calc_reg;

    // Instruction
    logic [31:0] instr_fetch;

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

    logic signed [31:0] s_rs1_data;
    logic signed [31:0] s_rs2_data;
    logic [4:0] rs1_data_5bit;
    logic [4:0] rs2_data_5bit;

    // ALU outputs
    logic [31:0] alu_calc;
    logic [31:0] alu_calc_reg;

    logic [MEM_ADDR_BIT-1:0] eff_addr_calc;
    logic [MEM_ADDR_BIT-1:0] eff_addr_calc_reg;

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
    assign bram_mode = (opcode == OP_STORE);
    assign ecall_sel = (reg_data1 == 32'd1); // based on register x17, determine it's putchar or getchar
    assign s_imm_I = $signed(imm_I);

    /** #################################
        #### submodule instantiation ####
        ################################# */
    controller u_controller (
        .clk(clk),
        .rst(rst),
        .instr(instr_fetch),
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

    register_formatting u_rs1_formatting (
        .reg_data(reg_data1),
        .signed_reg_data(s_rs1_data),
        .reg_data_5bit(rs1_data_5bit)
    );

    register_formatting u_rs2_formatting (
        .reg_data(reg_data2),
        .signed_reg_data(s_rs2_data),
        .reg_data_5bit(rs2_data_5bit)
    );

    alu u_alu (
        .opcode(opcode),
        .rd(rd),
        .func3(func3),
        .rs1_data(reg_data1),
        .rs2_data(reg_data2),
        .s_rs1_data(s_rs1_data),
        .s_rs2_data(s_rs2_data),
        .rs1_data_5bit(rs1_data_5bit),
        .rs2_data_5bit(rs2_data_5bit),
        .func7(func7),

        .s_imm_I(s_imm_I),
        .imm_I(imm_I),
        .imm_S(imm_S),
        .imm_B(imm_B),
        .imm_U(imm_U),
        .imm_J(imm_J),

        .pc(pc),

        .pc_calc(pc_calc),
        .alu_calc(alu_calc),
        .eff_addr_calc(eff_addr_calc)
    );

    PC u_pc (
        .clk(clk),
        .rst(rst),
        .pc_en(pc_en),
        .pc_from_alu(pc_calc_reg),
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
        .eff_addr(eff_addr_calc_reg),
        .mem2_data_in(formatted_mem_out),
        .mem1_data(mem1_data),
        .instr_fetch(instr_fetch)
    );

    bram_formatting u_bram_formatting (
        .mode(bram_mode),
        .func3(func3),
        .addr_offset(eff_addr_calc_reg[1:0]),
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

        .reg10_in(reg_data2),
        .tx_full(tx_full),
        .tx_data(tx_data),
        .tx_push(tx_push),

        .halt_signal(halt_signal),
        .block_signal(block_signal)
    );

    writeback_mux u_writeback_mux (
        .opcode(opcode),
        .rd(rd),
        .alu_calc_reg(alu_calc_reg),
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
            alu_calc_reg      <= '0;
            eff_addr_calc_reg <= '0;
            pc_calc_reg       <= '0;
            store_data_reg    <= '0;
        end

        else begin
            // note: instr_fetch and mem1_data both retrieve from bram at the clock edge, so the new data is only available at the next cycle
            if (state == EXECUTE) begin
                alu_calc_reg      <= alu_calc;
                eff_addr_calc_reg <= eff_addr_calc;
                pc_calc_reg       <= pc_calc;
            end
            if (state == DECODE) store_data_reg <= reg_data2;
        end 
    end

endmodule