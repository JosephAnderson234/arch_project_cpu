module controller(
        input clk,
        input reset,
        input  [6:0] op,
        input  [2:0] funct3,
        input [6:0] funct7,
        input        ZeroE,
        input        FlushE,
        // señales para el datapath
        output RegWriteW,
        output [1:0] ResultSrcW,
        output MemWriteM,
        output PCSrcE, 
        output [1:0] ALUSrcE,
        output [2:0] ImmSrcD,
        output [2:0] ALUControlE,

        // NUEVAS señales FP
        output FPRegWriteW,
        output [2:0] FPUControlE,

        // para el hazard unit
        output RegWriteM,
        output ResultSrcE_bit0,
        // NUEVO: semejante al register file anterior pero ahora para FP
        output FPRegWriteM,

        output FPMiniRegWriteW,
        output FPMiniRegWriteE,  // Para detectar LWMM
        output  WDMuxM
    );
    //_____________________
    // fase de DEcode
    //________________________

    wire RegWriteD; //c
    wire [1:0] ResultSrcD; //c
    wire MemWriteD; //c
    wire JumpD; //c
    wire BranchD;
    wire [2:0] ALUControlD; //c
    wire[1:0] ALUSrcD; //c
    wire [1:0] ALUOp;
    // NUEVAS señales FP
    wire FPOpD;
    wire FPRegWriteD;
    wire [2:0] FPUControlD;
    wire FPMiniRegWriteD;
    wire WDMuxD;
    wire WDMuxE;

    maindec md(
                .op(op),
                .ResultSrc(ResultSrcD),
                .MemWrite(MemWriteD),
                .Branch(BranchD),
                .ALUSrcD(ALUSrcD),
                .RegWrite(RegWriteD),
                .Jump(JumpD),
                .ImmSrc(ImmSrcD), //c
                .ALUOp(ALUOp),
                // Señales FP
                .FPOp(FPOpD),
                .FPRegWrite(FPRegWriteD),
                .FPMiniRegWrite(FPMiniRegWriteD),
                .WDMux(WDMuxD)
            );


    aludec  ad(
                .opb5(op[5]),
                .funct3(funct3),
                .funct7b5(funct7[5]),

                .ALUOp(ALUOp),
                .ALUControl(ALUControlD)
            );

    // FPU decoder
    fpu_dec fpudec(
                .funct7(funct7),  // Reconstruir funct7
                .funct3(funct3),
                .opcode(op),
                .FPUControl(FPUControlD)
            );
    //_______________________________________________________
    // stage de execute---------------- decode to execute
    //______________________________________________________

    wire RegWriteE; //c
    wire [1:0] ResultSrcE;
    wire JumpE;
    wire MemWriteE; //c
    wire BranchE;
    wire FPRegWriteE;

    // ALUCOntrolE sale como output
    // ALUSrcE sale como output
    // ResultSrcE_bit0 debe ser 0 para opcodes FP (1010011), LWMM (0001011), SWMM (0101011)
    // Esto evita stalls innecesarios porque estas instrucciones no cargan a registros enteros
    assign ResultSrcE_bit0 = ResultSrcE[0] & ~FPRegWriteD & ~FPMiniRegWriteD;

    reg_decode_to_execute_control reg_decode_to_execute_control_instance(
                                      .clk(clk),
                                      .reset(reset),
                                      .clr(FlushE),

                                      // Control desde Decode
                                      .RegWriteD(RegWriteD),
                                      .ResultSrcD(ResultSrcD),
                                      .MemWriteD(MemWriteD),
                                      .JumpD(JumpD),
                                      .BranchD(BranchD),
                                      .ALUControlD(ALUControlD),
                                      .ALUSrcD(ALUSrcD),
                                      .FPRegWriteD(FPRegWriteD),      // NUEVO
                                      .FPUControlD(FPUControlD),      // NUEVO

                                      // Control hacia Execute
                                      .RegWriteE(RegWriteE),
                                      .ResultSrcE(ResultSrcE),
                                      .MemWriteE(MemWriteE),
                                      .JumpE(JumpE),
                                      .BranchE(BranchE),
                                      .ALUControlE(ALUControlE),
                                      .ALUSrcE(ALUSrcE),
                                      .FPRegWriteE(FPRegWriteE),      // NUEVO
                                      .FPUControlE(FPUControlE),       // NUEVO

                                      .FPMiniRegWriteD(FPMiniRegWriteD),      // NUEVO
                                      .FPMiniRegWriteE(FPMiniRegWriteE),      // NUEVO
                                      .WDMuxD(WDMuxD),
                                      .WDMuxE(WDMuxE)
                                  );


    assign PCSrcE = (BranchE & ZeroE) | JumpE;
    //________________ fase de Memoery--- Executo to memeory
    //_______________________________________________________


    wire [1:0] ResultSrcM; //c
    // MemWriteM es un output


    reg_execute_to_memory_control reg_execute_to_memory_control_instance(
                                      .clk(clk),
                                      .reset(reset),

                                      // Control desde Execute
                                      .RegWriteE(RegWriteE),
                                      .ResultSrcE(ResultSrcE),
                                      .MemWriteE(MemWriteE),
                                      .FPRegWriteE(FPRegWriteE),      // NUEVO

                                      // Control hacia Memory
                                      .RegWriteM(RegWriteM),
                                      .ResultSrcM(ResultSrcM),
                                      .MemWriteM(MemWriteM),
                                      .FPRegWriteM(FPRegWriteM),       // NUEVO



                                      .FPMiniRegWriteE(FPMiniRegWriteE),  // NUEVO
                                      .FPMiniRegWriteM(FPMiniRegWriteM),  // NUEVO
                                        .WDMuxE(WDMuxE),
                                        .WDMuxM(WDMuxM)
                                  );


    //_______________________________________________-
    // fase de WriteBack memeory to writebacj
    //_______________________________________
    // REgWriteW y ResultSrcW son outputs

    reg_memory_to_writeback_control reg_memory_to_writeback_control_instance(
                                        .clk(clk),
                                        .reset(reset),

                                        // Control desde Memory
                                        .RegWriteM(RegWriteM),
                                        .ResultSrcM(ResultSrcM),
                                        .FPRegWriteM(FPRegWriteM),      // NUEVO

                                        // Control hacia Writeback
                                        .RegWriteW(RegWriteW),
                                        .ResultSrcW(ResultSrcW),
                                        .FPRegWriteW(FPRegWriteW),       // NUEVO



                                        .FPMiniRegWriteM(FPMiniRegWriteM),
                                        .FPMiniRegWriteW(FPMiniRegWriteW)  // NUEVO
                                    );


endmodule
