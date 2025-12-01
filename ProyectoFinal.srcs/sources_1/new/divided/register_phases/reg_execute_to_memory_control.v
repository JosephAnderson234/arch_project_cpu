module reg_execute_to_memory_control(
        input             clk,
        input             reset,

        // --------- CONTROL desde etapa E ---------
        input             RegWriteE,
        input      [1:0]  ResultSrcE,
        input             MemWriteE,
        input FPRegWriteE,  // NUEVO

        // --------- CONTROL hacia etapa M --------
        output reg        RegWriteM,
        output reg [1:0]  ResultSrcM,
        output reg        MemWriteM,
        output reg FPRegWriteM,  // NUEVO

        input FPMiniRegWriteE,  // NUEVO
        output reg FPMiniRegWriteM,  // NUEVO
        input WDMuxE,
        output reg WDMuxM

    );

    always @ (posedge clk or posedge reset) begin
        if (reset) begin
            // CONTROL
            RegWriteM  <= 1'b0;
            ResultSrcM <= 2'b0;
            MemWriteM  <= 1'b0;
            FPRegWriteM <= 0;
            FPMiniRegWriteM <= 0;
            WDMuxM <= 0;

        end
        else begin
            // CONTROL
            RegWriteM  <= RegWriteE;
            ResultSrcM <= ResultSrcE;
            MemWriteM  <= MemWriteE;
            FPRegWriteM <= FPRegWriteE;
            FPMiniRegWriteM <= FPMiniRegWriteE;
            WDMuxM <= WDMuxE;
        end
    end

endmodule
