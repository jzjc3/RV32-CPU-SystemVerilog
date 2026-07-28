/** controller.sv
  *     instruction field extraction
  *     instruction type determination
  *     sequential: FSM
  *     control signal output generation
  */

import cpu_pkg::*;

// ecall block_signal, ebreak halt_signal as inputs
module controller(
  input  logic          clk,
  input  logic          rst,
  input  logic [31:0]   instr,         // from bram.sv 
  input  logic          halt_signal,   // from system_call.sv
  input  logic          block_signal,  // from system_call.sv
  input  logic          ecall_sel,

  output state_t        state,

  // fields parsed from instruction
  output logic [6:0]    opcode,
  output logic [4:0]    rd,
  output logic [2:0]    func3,
  output logic [4:0]    rs1,
  output logic [4:0]    rs2,
  output logic [6:0]    func7,

  output logic [31:0]   imm_I,
  output logic [31:0]   imm_S,
  output logic [31:0]   imm_B,
  output logic [31:0]   imm_U,
  output logic [31:0]   imm_J,

  // control logics 
  output alu_op_t       alu_op_sel,    // ALU operation selection
  output logic          pc_en,         // update pc register enable line
  output logic          reg_wen,       // register write enable line
  output logic          mem1_ren,      // retrieve from main memory enable lie
  output logic          mem2_wen,      // write to main memory enable line
  output logic          fetch_en,      // fetch instruction from main memory enable
  output logic          ecall_en,      // I/O from peripheral enable line
  output logic          ebreak_en      // system ebreak enable line
);

  state_t next_state;

  // note: opcode decides instruction type
  //       func3 decides operation family
  //       func7 decides special variants

  always_comb begin : decode_stage
      opcode = instr[6:0];
      rd     = instr[11:7];
      func3  = instr[14:12];
      rs1    = (opcode == OP_SYSTEM) ? 5'd17 : instr[19:15];
      rs2    = (opcode == OP_SYSTEM) ? 5'd10 : instr[24:20];
      func7  = instr[31:25];
  end 

  always_comb begin: immediate_formatting
      imm_I = {{20{instr[31]}}, instr[31:20]};
      imm_S = {{20{instr[31]}}, instr[31:25], instr[11:7]};
      imm_B = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
      imm_U = {instr[31:12], 12'b0};
      imm_J = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
  end

  // OP_BRANCH itselves is a special case because it does comparison instead of arithmetic operation on the two data fed to alu 
  always_comb begin : ALU_operation_selection
    case (opcode)
        OP_REGISTER,
        OP_IMM: begin
            case (func3)
                3'b000: begin
                  if (opcode == OP_REGISTER)
                      case (func7) 
                        7'b0000000: alu_op_sel = ALU_ADD;
                        7'b0100000: alu_op_sel = ALU_SUB;
                        7'b0000001: alu_op_sel = ALU_MUL;
                        default:    alu_op_sel = ALU_ADD;
                      endcase 
                  else alu_op_sel = ALU_ADD;
                end

                3'b001: alu_op_sel = ALU_SLL;

                3'b010: alu_op_sel = ALU_SLT;

                3'b011: alu_op_sel = ALU_SLTU;

                3'b100: alu_op_sel = ALU_XOR;

                3'b101: alu_op_sel = (func7 == 7'b0100000) ? ALU_SRA : ALU_SRL;

                3'b110: alu_op_sel = ALU_OR;

                3'b111: alu_op_sel = ALU_AND;

                default: alu_op_sel = ALU_ADD;
            endcase
        end

        OP_BRANCH: begin
            case (func3)
                3'b000: alu_op_sel  = ALU_BEQ;
                3'b001: alu_op_sel  = ALU_BNE;
                3'b100: alu_op_sel  = ALU_BLT;
                3'b101: alu_op_sel  = ALU_BGE;
                3'b110: alu_op_sel  = ALU_BLTU;
                3'b111: alu_op_sel  = ALU_BGEU;
                default: alu_op_sel = ALU_ADD;
            endcase
        end

        default: begin
            alu_op_sel = ALU_ADD;
        end
    endcase
  end 

  always_comb begin : FSM
      if (halt_signal) next_state = HALT;
      else if (block_signal) next_state = state;
      else begin
        next_state = state; //TODO this line does nothing
        case (state)
          FETCH: next_state = IR;
          IR: next_state = DECODE;
          DECODE: begin 
            next_state = EXECUTE;
          end
          EXECUTE: begin
            case (opcode)
              OP_LOAD, OP_STORE: next_state = MEM1;
              default:           next_state = WRITEBACK;
            endcase
          end
          MEM1: next_state = MEM2;
          MEM2: next_state = WRITEBACK;
          WRITEBACK: next_state = FETCH;
          HALT: next_state = HALT;
          default: next_state = HALT;
        endcase
      end 
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      state <= FETCH;
    end
    else begin
      state <= next_state;
    end 
  end

  // Output SIGNAL / DEVICE CONTROL AND ACTIVATION SIGNAL generation
  assign  pc_en     = (state == WRITEBACK) && !block_signal && !halt_signal;
  assign  reg_wen   = (state == WRITEBACK) &&
                   (
                       opcode == OP_REGISTER ||
                       opcode == OP_IMM      ||
                       opcode == OP_LOAD     ||
                       opcode == OP_LUI      ||
                       opcode == OP_AUIPC    ||
                       opcode == OP_JAL      ||
                       opcode == OP_JALR     ||
                       (ecall_en && ecall_sel && !block_signal)
                   );  // the rest of the states get to WRITEBACK but will only update PC during writeback
  assign  mem1_ren = (state == MEM1) && ((opcode == OP_LOAD) || (opcode == OP_STORE));
  assign  mem2_wen = (state == MEM2) && (opcode == OP_STORE);
  assign  fetch_en  = (state == FETCH);
  assign  ecall_en  = (state == WRITEBACK) & (instr == 32'h00000073);
  assign  ebreak_en = (state == WRITEBACK) & (instr == 32'h00100073);

endmodule
