// instr_reg
// alu_calc_reg
// eff_addr_calc_reg
// pc_calc_reg
// mem_data_reg
// reg1_data_reg
// reg2_data_reg

// Q: how do we know if a signal need to be latched
// A: 1) If a value is produced in one FSM state but used in a later FSM state, latch it.
//    2) If the producer is synchronous memory/BRAM, expect to latch or wait for its output.
//      (because we cannot use it right away if it's not latched, cuz it's synchronous access)