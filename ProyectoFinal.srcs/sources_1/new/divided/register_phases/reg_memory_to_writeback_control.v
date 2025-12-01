module reg_memory_to_writeback_control(
        input             clk,
        input             reset,

        // --------- CONTROL desde etapa M ---------
        input             RegWriteM,
        input      [1:0]  ResultSrcM,
        input FPRegWriteM,  // NUEVO

        // --------- CONTROL hacia etapa W --------
        output reg        RegWriteW,
        output reg [1:0]  ResultSrcW,
        output reg FPRegWriteW,  // NUEVO


        input FPMiniRegWriteM,
        output reg FPMiniRegWriteW  // NUEVO

    );

    always @ (posedge clk or posedge reset) begin
        if (reset) begin
            // CONTROL
            RegWriteW  <= 1'b0;
            ResultSrcW <= 2'b0;
            FPRegWriteW <= 0;
            FPMiniRegWriteW <= 0;
        end
        else begin
            // CONTROL
            RegWriteW  <= RegWriteM;
            ResultSrcW <= ResultSrcM;
            FPRegWriteW <= FPRegWriteM;
            FPMiniRegWriteW <= FPMiniRegWriteM;
        end
    end

endmodule