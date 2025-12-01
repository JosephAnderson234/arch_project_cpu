module reg_decode_to_execute_control (
        input             clk,
        input             reset,
        input             clr, // <--- NUEVO INPUT

        // --------- CONTROL (desde etapa D) ---------
        input             RegWriteD,
        input      [1:0]  ResultSrcD,
        input             MemWriteD,
        input             JumpD,
        input             BranchD,
        input      [2:0]  ALUControlD,
        input [1:0]             ALUSrcD,
        input FPRegWriteD,      // NUEVO
        input [2:0] FPUControlD, // NUEVO

        // --------- CONTROL (hacia etapa E) --------
        output reg        RegWriteE,
        output reg [1:0]  ResultSrcE,
        output reg        MemWriteE,
        output reg        JumpE,
        output reg        BranchE,
        output reg [2:0]  ALUControlE,
        output reg [1:0]       ALUSrcE,
        output reg FPRegWriteE,      // NUEVO
        output reg [2:0] FPUControlE, // NUEVO



        input FPMiniRegWriteD,      // NUEVO
        output reg FPMiniRegWriteE,      // NUEVO

        input WDMuxD,      // NUEVO
        output reg WDMuxE      // NUEVO
    );

    always @(posedge clk or posedge reset) begin
        if (reset || clr) begin
            // Reset/Flush: NOP
            RegWriteE <= 0;
            ResultSrcE <= 2'b00;
            MemWriteE <= 0;
            JumpE <= 0;
            BranchE <= 0;
            ALUControlE <= 3'b000;
            ALUSrcE <= 2'b00;
            FPRegWriteE <= 0;      // NUEVO
            FPUControlE <= 3'b000; // NUEVO
            FPMiniRegWriteE <= 0;  // NUEVO
            WDMuxE <= 0;           // NUEVO
        end
        else begin
            // Propagar señales
            RegWriteE <= RegWriteD;
            ResultSrcE <= ResultSrcD;
            MemWriteE <= MemWriteD;
            JumpE <= JumpD;
            BranchE <= BranchD;
            ALUControlE <= ALUControlD;
            ALUSrcE <= ALUSrcD;
            FPRegWriteE <= FPRegWriteD;      // NUEVO
            FPUControlE <= FPUControlD;      // NUEVO
            FPMiniRegWriteE <= FPMiniRegWriteD;  // NUEVO
            WDMuxE <= WDMuxD;           // NUEVO
        end
    end
endmodule
