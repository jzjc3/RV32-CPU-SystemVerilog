module register_formatting (
    input  logic [31:0] reg_data,
    output logic signed [31:0] signed_reg_data,
    output logic [4:0] reg_data_5bit;
);
    assign signed_reg_data = $signed(reg_data);
    assign reg_data_5bit = reg_data[4:0];

endmodule