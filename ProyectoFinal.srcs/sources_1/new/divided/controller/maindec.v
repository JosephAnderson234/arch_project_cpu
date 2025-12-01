module maindec(
        input  [6:0] op,
        output [1:0] ResultSrc,
        output MemWrite,
        output Branch, 
        output [1:0] ALUSrcD,
        output RegWrite, Jump,
        output [2:0] ImmSrc,
        output [1:0] ALUOp,
        output reg FPOp,
        output reg FPRegWrite,
        output  FPMiniRegWrite,
        output  WDMux
    );

    reg [14:0] controls;
    assign {RegWrite, ImmSrc, ALUSrcD, MemWrite,
            ResultSrc, Branch, ALUOp, Jump, FPMiniRegWrite, WDMux} = controls;

    always @(*) begin
        // DEFAULTS para evitar 'X'
        FPOp = 1'b0;
        FPRegWrite = 1'b0;

        case(op)
            7'b0000011:
                controls = 15'b1_000_01_0_01_0_00_0_0_0; // lw
            7'b0100011:
                controls = 15'b0_001_01_1_00_0_00_0_0_0; // sw
            7'b0110011:
                controls = 15'b1_xxx_00_0_00_0_10_0_0_0; // R-type
            7'b1100011:
                controls = 15'b0_010_00_0_00_1_01_0_0_0; // beq
            7'b0010011:
                controls = 15'b1_000_01_0_00_0_10_0_0_0; // I-type ALU
            7'b1101111:
                controls = 15'b1_011_00_0_10_0_00_1_0_0; // jal
            7'b0110111:
                controls = 15'b1_100_11_0_00_0_00_0_0_0; // lui

            7'b1010011: begin  // INSTRUCCIONES FP
                controls = 15'b0_000_00_0_11_0_11_0_0_0; 
                FPOp = 1'b1;        // activar ruta FPU
                FPRegWrite = 1'b1;  // escribir en banco de registros FP
            end
            7'b0001011: begin  // CUSTOM-0: MINI FP LOAD (LWMM) - I-type
                controls = 15'b0_000_01_0_01_0_00_0_1_0; // FPMiniRegWrite=1; RegWrite=0
            end
            7'b0101011: begin  // CUSTOM-1: MINI FP STORE (SWMM) - S-type
                controls = 15'b0_001_01_1_00_0_00_0_0_1; // MemWrite=1; WDMux=1
            end

            default: begin
                controls = 15'b0_000_00_0_00_0_00_0_0_0; // default NOP
                FPOp = 1'b0;
                FPRegWrite = 1'b0;
            end
        endcase
    end
endmodule