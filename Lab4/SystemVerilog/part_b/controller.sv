/** controller.sv
  *     instruction field extraction
  *     instruction type determination
  *     sequential: FSM
  *     control signal output generation
  */

import cpu_pkg::*;

// ecall block_signal, ebreak halt_signal as inputs
module controller(
  input  logic         clk,
  input  logic         rst,
  input  logic [31:0]  instr,  // from bram.sv 
  input  logic         halt_signal,  // from system_call.sv
  input  logic         block_signal, // from system_call.sv

  output logic [6:0]   opcode,
  output logic [4:0]   rd,
  output logic [2:0]   func3,
  output logic [4:0]   rs1,
  output logic [4:0]   rs2,
  output logic [6:0]   func7,

  output logic [31:0]  imm_I,
  output logic [31:0]  imm_S,
  output logic [31:0]  imm_B,
  output logic [31:0]  imm_U,
  output logic [31:0]  imm_J,

  // control logics
  output logic pc_en,
  output logic reg_wen,
  output logic mem1_ren,
  output logic mem2_wen,
  output logic fetch_en // bram fetch instruction enable
  output logic ecall_en,
  output logic ebreak_en
);

  typedef enum logic [2:0]{
      FETCH,
      DECODE,
      EXECUTE,
      MEM1,
      MEM2, 
      WRITEBACK,
      HALT
  } state_t;

  state_t state = FETCH;
  state_t next_state;

  always_comb begin : decode_stage
      opcode = instr[6:0];
      rd     = instr[11:7];
      func3  = instr[14:12];
      rs1    = (opcode == OP_SYSTEM) ? 31'd17 : instr[19:15];
      rs2    = (opcode == OP_SYSTEM) ? 31'd10 : instr[24:20];
      func7  = instr[31:25];
  end 

  always_comb begin: immediate_extraction
      imm_I = instr[31:20];
      imm_S = {instr[31:25], instr[11:7]};
      imm_B = {instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
      imm_U = {instr[31:12], 12'b0};
      imm_J = {instr[31], instr[30:21], instr[20], instr[19:12], 1'b0};
  end

  always_comb begin : FSM
      if (halt_signal) next_state = HALT;
      else if (block_signal) next_state = state;
      else begin
        next_state = state;
        case (state)
          FETCH: next_state = DECODE;
          DECODE: begin 
            case (opcode)
              OP_SYSTEM: next_state = WRITEBACK;
              default:   next_state = EXECUTE;
            endcase 
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
  assign  pc_en     = (state == WRITEBACK);
  assign  reg_wen   = (state == WRITEBACK);
  assign  mem1_ren  = (state == MEM1);
  assign  mem2_wen  = (state == MEM2);
  assign  fetch_en  = (state == FETCH);
  assign  ecall_en  = (state == WRITEBACK) & (instr == 32'h00000073);
  assign  ebreak_en = (state == WRITEBACK) & (instr == 32'h00100073);

endmodule
