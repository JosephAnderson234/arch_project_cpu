module reg_execute_to_memory(
        input             clk,
        input             reset,

        // --------- DATOS desde etapa E ----------
        input      [31:0] ALUResultE,
        input [31:0] FPResultE, // NUEVO: Resultado de FPU
        input      [31:0] WriteDataE,
        input      [31:0] MulResultE, // NUEVO: Resultado de multiplicación vectorial
        input      [4:0]  RdE,
        input      [31:0] PCPlus4E,

        // --------- DATOS hacia etapa M ----------
        output reg [31:0] ALUResultM,
        output reg [31:0] FPResultM,  // NUEVO
        output reg [31:0] WriteDataM_base,
        output reg [31:0] MulResultM, // NUEVO: Resultado de multiplicación vectorial
        output reg [4:0]  RdM,
        output reg [31:0] PCPlus4M
    );

    always @ (posedge clk or posedge reset) begin
        if (reset) begin
            // DATOS
            ALUResultM <= 32'b0;
            FPResultM <= 32'b0; //NUEVO
            WriteDataM_base <= 32'b0;
            MulResultM <= 32'b0; //NUEVO
            RdM        <= 5'b0;
            PCPlus4M   <= 32'b0;
        end
        else begin
            // DATOS
            ALUResultM <= ALUResultE;
            FPResultM <= FPResultE;   // NUEVO
            WriteDataM_base <= WriteDataE;
            MulResultM <= MulResultE; // NUEVO
            RdM        <= RdE;
            PCPlus4M   <= PCPlus4E;
        end
    end

endmodule
