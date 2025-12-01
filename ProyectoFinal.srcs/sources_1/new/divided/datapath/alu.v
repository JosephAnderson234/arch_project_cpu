module alu(input  [31:0] a, b,
               input  [2:0]  alucontrol,
               output [31:0] result,
               output zero);

    wire [31:0] condinvb, sum;
    wire        v; // overflow
    wire        isAddSub;

    reg [31:0] result_reg;
    assign result = result_reg;

    assign condinvb = alucontrol[0] ? ~b : b;
    assign sum = a + condinvb + alucontrol[0];
    assign isAddSub = ~alucontrol[2] & ~alucontrol[1] |
           ~alucontrol[1] & alucontrol[0];

    // 🛑 ESTA LÍNEA FALTABA O ESTABA INCOMPLETA:
    assign v = ~(alucontrol[0] ^ a[31] ^ b[31]) & (a[31] ^ sum[31]) & isAddSub;

    always @* case (alucontrol)
        3'b000:
            result_reg = sum;          // add
        3'b001:
            result_reg = sum;          // subtract
        3'b010:
            result_reg = a & b;        // and
        3'b011:
            result_reg = a | b;        // or
        3'b100:
            result_reg = a ^ b;        // xor
        3'b101:
            result_reg = {31'b0, sum[31] ^ v}; // slt (Set Less Than)
        3'b110:
            result_reg = a << b[4:0];  // sll
        3'b111:
            result_reg = a >> b[4:0];  // srl
        default:
            result_reg = 32'bx;
    endcase

    assign zero = (result == 32'b0);
endmodule
