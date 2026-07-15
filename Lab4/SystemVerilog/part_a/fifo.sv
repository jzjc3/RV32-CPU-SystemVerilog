// fifo.sv -- THIS IS THE FILE YOU EDIT. Implement a synchronous FIFO.
// What a FIFO is / why it's here: ../../doc/FIFO_explained.md
// io_bridge instantiates this twice (rx + tx); the port names/widths are fixed.
//
// THE CONTRACT -- what your FIFO must do (the "how" is the lab):
//   * Holds up to DEPTH bytes; returns them in the order they were pushed.
//   * push (1-cycle strobe): wdata enters the FIFO.
//   * pop  (1-cycle strobe): the oldest byte leaves.
//   * rdata: the oldest byte -- the one the next pop removes. It must already be
//     showing whenever empty is low: present BEFORE pop, not the cycle after.
//   * count: bytes currently held, 0..DEPTH (it must reach DEPTH, not wrap).
//     empty == (count == 0);  full == (count == DEPTH).
//   * push and pop may assert in the SAME cycle: do both, count unchanged -- and
//     a push alongside a pop is fine even when full (the pop frees a slot).
//   * overflow: sticky. Set it if a byte is pushed while full with no pop that
//     same cycle (the byte is dropped); it stays set until rst. Never trips in a
//     correct system.
//   * Synchronous to clk. rst is synchronous, active-high: a clock edge with rst
//     high returns the FIFO to empty (count 0) and clears overflow.

// shift buffer vs. pointer buffer
module fifo #(
    parameter int WIDTH = 8,
    parameter int DEPTH = 16
) (
    input  logic             clk,
    input  logic             rst,
    input  logic             push,
    input  logic [WIDTH-1:0] wdata,
    output logic             full,
    input  logic             pop,
    output logic [WIDTH-1:0] rdata,
    output logic             empty,
    output logic [7:0]       count,
    output logic             overflow
);

    logic [DEPTH * WIDTH - 1 : 0] fifo_buffer;

    // TODO: implement the FIFO (the contract is in the header above).

    // signal directly derived from state
    // notice sth.: count only respond to the input pop & push (operation succeeds ro not depend on empty & full)
    assign empty = (count == 0);
    assign full = (count == DEPTH);
    assign rdata = !count ? 'x : fifo_buffer[(count-1'd1)*WIDTH +: WIDTH];


    // flip-flop: count, overflow, fifo_buffer
    always_ff @(posedge clk) begin
        if (rst) begin
            overflow <= '0;
            fifo_buffer <= '0;
            count <= '0;
        end
        else begin
            if (push & pop) begin
                fifo_buffer <= {fifo_buffer[WIDTH*DEPTH-9:0], wdata};
            end
            else if (push) begin
                if (count == DEPTH) begin
                    overflow <= '1;
                end
                else begin
                    count <= count + 1'd1;
                    fifo_buffer <= {fifo_buffer[WIDTH*DEPTH-9:0], wdata};
                end
            end
            else if (pop) begin
                if (count == 0) begin
                    // latch,p program should wait
                end
                else begin
                    count <= count - 1'd1;
                    fifo_buffer[(count-1)*WIDTH +: WIDTH] <= '0;
                end
            end
            // the other case (ie. no push nor pop): everything latch
        end
    end

endmodule : fifo
