

module reg_floating(
    input clk,
    input [1:0] a5,
    input [31:0] wd5,
    input we5,
    output reg [31:0] rd1,
    output reg [31:0] rd2,
    output reg [31:0] rd3,
    output reg [31:0] rd4
);

    // 4 registros de 32 bits: índices 0..3
    reg [31:0] register_file [0:3];

    // Escritura síncrona en flanco de subida
    always @(posedge clk) begin
        if (we5) begin
            register_file[a5] <= wd5;
        end
    end

    // Salidas fijas: cada salida refleja uno de los 4 registros (0..3)
    always @(*) begin
        rd1 = register_file[0];
        rd2 = register_file[1];
        rd3 = register_file[2];
        rd4 = register_file[3];
    end

endmodule