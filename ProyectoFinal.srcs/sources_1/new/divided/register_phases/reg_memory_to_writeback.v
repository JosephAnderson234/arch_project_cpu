module reg_memory_to_writeback(
        input             clk,
        input             reset,

        // --------- DATOS desde etapa M ----------
        input      [31:0] ReadDataM,
        input      [31:0] ALUResultM,
        input [31:0] FPResultM, //nuevo
        input      [31:0] PCPlus4M,
        input      [4:0]  RdM,

        // --------- DATOS hacia etapa W ----------
        output reg [31:0] ReadDataW,
        output reg [31:0] ALUResultW,
        output reg [31:0] FPResultW, //nuevo
        output reg [31:0] PCPlus4W,
        output reg [4:0]  RdW
    );

    always @ (posedge clk or posedge reset) begin
        if (reset) begin

            // DATOS
            ReadDataW  <= 32'b0;
            ALUResultW <= 32'b0;
            FPResultW  <= 32'b0; //nuevo
            PCPlus4W   <= 32'b0;
            RdW        <= 5'b0;
        end
        else begin

            // DATOS
            ReadDataW  <= ReadDataM;
            ALUResultW <= ALUResultM;
            FPResultW  <= FPResultM; //nuevo
            PCPlus4W   <= PCPlus4M;
            RdW        <= RdM;
        end
    end

endmodule
