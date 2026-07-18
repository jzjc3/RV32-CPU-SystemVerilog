module imm_formatting #(
    parameter int WIDTH = 12  // number of bits we already have. used for signed extension
)(
    input  logic [31:0] imm,
    output logic signed [31:0] sext_imm,
);
    assign sext_imm = {{(32-WIDTH){imm[WIDTH-1]}}, imm[WIDTH-1:0]};

endmodule