module hazard_unit(
        // Registros ENTEROS
        input [4:0] Rs1E, Rs2E, Rs1D, Rs2D, RdM, RdW, RdE,
        input RegWriteM, RegWriteW,
        
        // Registros FP (agregar estas señales al datapath)
        input [4:0] Rs1E_FP, Rs2E_FP, RdM_FP, RdW_FP, RdE_FP,
        input FPRegWriteM, FPRegWriteW, FPRegWriteE,
        
        input ResultSrcE_bit0, PCSrcE,

        output reg [1:0] ForwardAE, ForwardBE,
        output reg [1:0] ForwardAE_FP, ForwardBE_FP,
        output wire StallF, StallD, FlushE, FlushD
    );

    // ========== Forwarding ENTERO (con prioridad a Memory) ==========
    always @(*) begin
        // Prioridad: Memory > Writeback > None
        if ((Rs1E == RdM) && RegWriteM && (Rs1E != 0))
            ForwardAE = 2'b10;  // Desde Memory
        else if ((Rs1E == RdW) && RegWriteW && (Rs1E != 0))
            ForwardAE = 2'b01;  // Desde Writeback
        else
            ForwardAE = 2'b00;  // Sin forwarding

        if ((Rs2E == RdM) && RegWriteM && (Rs2E != 0))
            ForwardBE = 2'b10;
        else if ((Rs2E == RdW) && RegWriteW && (Rs2E != 0))
            ForwardBE = 2'b01;
        else
            ForwardBE = 2'b00;
    end

    // ========== Forwarding FP (con registros FP separados) ==========
    always @(*) begin
        // Prioridad: Memory > Writeback > None
        if ((Rs1E_FP == RdM_FP) && FPRegWriteM && (Rs1E_FP != 0))
            ForwardAE_FP = 2'b10;
        else if ((Rs1E_FP == RdW_FP) && FPRegWriteW && (Rs1E_FP != 0))
            ForwardAE_FP = 2'b01;
        else
            ForwardAE_FP = 2'b00;

        if ((Rs2E_FP == RdM_FP) && FPRegWriteM && (Rs2E_FP != 0))
            ForwardBE_FP = 2'b10;
        else if ((Rs2E_FP == RdW_FP) && FPRegWriteW && (Rs2E_FP != 0))
            ForwardBE_FP = 2'b01;
        else
            ForwardBE_FP = 2'b00;
    end

    // ========== Detección de Stalls ==========
    // Stall por Load-Use hazard (lw seguido de uso inmediato)
    wire lwStall = (ResultSrcE_bit0 == 1'b1) && 
                   ((Rs1D == RdE) || (Rs2D == RdE)) &&
                   (RdE != 0);

    // Stall por instrucción FP (si tiene latencia > 1, agregar lógica aquí)
    // wire fpStall = FPRegWriteE && ((Rs1D_FP == RdE_FP) || (Rs2D_FP == RdE_FP));

    assign StallF = lwStall;  // | fpStall si FPU tiene latencia
    assign StallD = lwStall;  // | fpStall
    assign FlushE = lwStall | PCSrcE;
    assign FlushD = PCSrcE;

endmodule