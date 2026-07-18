module system_call #(
    parameter int WIDTH = 8
) (
    input rst,
    input clk,

    input  logic ecall_en; // during writeback stage as well
    input  logic ebreak_en; // during writeback stage
    input  logic ecall_sel; // from register x17, 0: tx, 1: rx

    input  logic rx_empty,
    input  logic [WIDTH-1:0] rx_data,
    output logic rx_pop,
    output logic [31:0] reg10_out, // feed to register x10

    input  logic reg10_in, // from register x10
    input  logic tx_full,
    output logic [31:0] tx_data,
    output logic tx_push,

    output logic halt_signal,
    output logic block_signal
    
    );

    always_comb begin
        // default:
        rx_pop       = 1'b0;
        reg10_out    = 32'b0;
        tx_data      = 32'b0;
        tx_push      = 1'b0;
        halt_signal  = 1'b0;
        block_signal = 1'b0;

        if (ecall_en) begin
            if (ecall_sel) begin // rx
                if (rx_empty) block_signal = 1'b1;
                else begin
                    rx_pop = 1'b1;  // the oldest value, ie. rdata, will be deleted from fifo only at the next cylce (b/c of the ff logic of fifo.sv)
                    block_signal = 1'b0;
                    reg10_out = {24'b0, rx_data};
                end
            end

            else begin // tx
                if (tx_full) block_signal = 1'b1;
                else begin
                    tx_push = 1'b1;
                    block_signal = 1'b0;
                    tx_data = reg10_in[7:0];
                end
            end
        end

        else if (ebreak_en) begin
            halt_signal = 1'b1;
        end
    end 

endmodule