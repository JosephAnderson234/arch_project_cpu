module fpu_dec(
        input [6:0] funct7,
        input [2:0] funct3,
        input [6:0] opcode,
        output reg [2:0] FPUControl  // op_code para fpu_top
    );

    always @(*) begin
        FPUControl = 3'b000;  // Default: ADD

        // Solo decodifica si es instrucción FP
        if (opcode == 7'b1010011) begin
            case(funct7)
                7'b0000000:
                    FPUControl = 3'b000;  // FADD.S
                7'b0000100:
                    FPUControl = 3'b001;  // FSUB.S
                7'b0001000:
                    FPUControl = 3'b010;  // FMUL.S
                7'b0001100:
                    FPUControl = 3'b011;  // FDIV.S

                // FMIN/FMAX se diferencian por funct3

                7'b0010100: begin
                    if (funct3 == 3'b000)
                        FPUControl = 3'b100;      // FMIN.S
                    else if (funct3 == 3'b001)
                        FPUControl = 3'b101;      // FMAX.S
                    else
                        FPUControl = 3'b000;
                end

                default:
                    FPUControl = 3'b000;
            endcase
        end
    end

endmodule