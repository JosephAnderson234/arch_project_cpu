module aludec(input  opb5,
                  input  [2:0] funct3,
                  input  funct7b5,
                  input  [1:0] ALUOp,
                  output [2:0] ALUControl);

    wire  RtypeSub;
    reg [2:0] ALUControl_reg;

    assign RtypeSub = funct7b5 & opb5;  // TRUE for R-type subtract instruction
    assign ALUControl = ALUControl_reg;

    always @* case(ALUOp)
        2'b00:
            ALUControl_reg = 3'b000; // addition
        2'b01:
            ALUControl_reg = 3'b001; // subtraction
        default:
        case(funct3) // R-type or I-type ALU
            3'b000:
                if (RtypeSub)
                    ALUControl_reg = 3'b001; // sub
                else
                    ALUControl_reg = 3'b000; // add, addi
            3'b010:
                ALUControl_reg = 3'b101; // slt, slti
            3'b110:
                ALUControl_reg = 3'b011; // or, ori
            3'b111:
                ALUControl_reg = 3'b010; // and, andi
            default:
                ALUControl_reg = 3'bxxx; // ???
        endcase
    endcase
endmodule