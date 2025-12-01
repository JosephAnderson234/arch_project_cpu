module datapath(input  clk, reset,
                    //________________ inputs del controller
                    input  [1:0]  ResultSrcW,
                    input  PCSrcE, 
                    input  [1:0]  ALUSrcE,
                    input  RegWriteW,
                    input  [2:0]  ImmSrcD,
                    input  [2:0]  ALUControlE,
                    input FPRegWriteM, // NUEVO
                    input FPRegWriteW,   // NUEVO
                    input [2:0] FPUControlE, // NUEVO
                    //inputs de la memoria
                    input  [31:0] ReadDataM,
                    input  [31:0] InstrF,
                    // outputs
                    output ZeroE,
                    output [31:0] PCF,
                    output [31:0] InstrD,
                    output [31:0] ALUResultM,
                    output [31:0] WriteDataM,

                    // outputs para el hazard unit
                    output [4:0] Rs1E, Rs2E, RdM, RdW, Rs1D, Rs2D, RdE,
                    // inputs del hazard unit
                    input [1:0] ForwardAE, ForwardBE,
                    input [1:0] ForwardAE_FP, ForwardBE_FP,
                    input StallF,StallD,FlushE,FlushD,


					//--------------------------------------------------------------------------------------
					//-----------------NEW FORMATS FOR THE CUSTOM OPERATION --------------------------------
					//--------------------------------------------------------------------------------------

                    input FPMiniRegWriteW,
                    input WDMuxM
                   );

    localparam WIDTH = 32;

    // Wires globales del pipeline (usados en múltiples etapas)
    wire [31:0] ResultW;          // Resultado final de writeback (entero)
    wire [31:0] FPResultW;        // Resultado final de writeback (FP)
    wire [31:0] FPResultM;        // Resultado FP en etapa Memory

    //_________________ fase de fetch
    wire [31:0] PCNextF, PCPlus4F;
    wire [31:0] PCD, PCPlus4D;
    // next PC logic
    flopr #(WIDTH) pcreg(
              .en(~StallF),
              .clk(clk),
              .reset(reset),
              .d(PCNextF),
              .q(PCF)
          );

    adder pcadd4(
              .a(PCF),
              .b(32'd4),
              .y(PCPlus4F)
          );

    reg_fetch_to_decode reg_fetch_to_decode_instance(
                            .clk(clk),
                            .reset(reset),
                            .en(~StallD),
                            .clr(FlushD),
                            .InstrF(InstrF),
                            .PCF(PCF),
                            .PCPlus4F(PCPlus4F),
                            .InstrD(InstrD),  // ✅ Conecta con el output del módulo
                            .PCD(PCD),
                            .PCPlus4D(PCPlus4D)
                        );

    //_____________________________________
    // fase del decode
    //_________________________________________

    wire [31:0] ImmExtD;
    wire [31:0] RD1D, RD2D;
    wire [31:0] FRD1D, FRD2D;     // NUEVO: Datos de regfile FP
    // variables para execute
    wire [31:0] RD1E, RD2E, FRD1E, FRD2E, PCE, ImmExtE, PCPlus4E;


    assign Rs1D = InstrD[19:15];
    assign Rs2D = InstrD[24:20];
    // Register file
    regfile rf(
                .clk(clk),  // ✅ Clock normal, sin invertir
                .we3(RegWriteW),
                .a1(InstrD[19:15]),
                .a2(InstrD[24:20]),
                .a3(RdW),  // ✅ RdW es [4:0]
                .wd3(ResultW),
                .rd1(RD1D),
                .rd2(RD2D)
            );

    // NUEVO: Register file FLOTANTE
    fp_regfile fprf(
                   .clk(clk),
                   .we3(FPRegWriteW),
                   .a1(InstrD[19:15]),
                   .a2(InstrD[24:20]),
                   .a3(RdW),
                   .wd3(FPResultW),
                   .rd1(FRD1D),
                   .rd2(FRD2D)
               );
	


	//example to my custom op 
	//load word for matrix mul
	//lwmm rd, offset(rs)
	//how my reg can keep 4 values for matrix mul, in this case it will ve done vector by vector
	//so rd is the value where will be settet, 0, 1,2,3
	//rs is the value in the offcial regsiter that means 
	//and the offset will be target as tha classic lw format
	//so in this case the format will be
	//opcode: 7 bits -> 0111111
	// rd: 2 bits
	//rs: 5bits
	//funct3: 3 bits -> 000
	//immsrc: 12 bits
	//the 3 bits that we are not using, it will be as a don't care

	//soo the final format, as an example can be:
	// [12 bits of offset][XX00][000][00110]0111111
	//----------------------rs with dont care bits -- 


	//my custom op format, called JTOperation, soooo here is the instructure
	//
	//[]


    wire [31:0] rd1D, rd2D, rd3D, rd4D;
    wire [31:0] rd1E, rd2E, rd3E, rd4E;
    wire [31:0] mulResultE;  // Resultado de multiplicación en etapa Execute
    wire [31:0] mulResultM;  // Resultado de multiplicación en etapa Memory

	reg_floating regFloatingInstance(
		.clk(clk),
        .we5(FPMiniRegWriteW),
        .a5(RdW[1:0]),  // only 2 bits for selecting one of the 4 registers
		.wd5(ResultW),          // the data to be written
        .rd1(rd1D),
        .rd2(rd2D),
        .rd3(rd3D),
        .rd4(rd4D)
	);

    reg_decode_to_execute_fp reg_decode_to_execute_fp_instance(
        .clk(clk),
        .reset(reset),
        .clr(FlushE),
        .rd1D(rd1D),
        .rd2D(rd2D),
        .rd3D(rd3D),
        .rd4D(rd4D),
        .rd1E(rd1E),
        .rd2E(rd2E),
        .rd3E(rd3E),
        .rd4E(rd4E)
    );

    mul2_vector_mul mulVectorsInstance (
        .a_value(rd1E),
        .b_value(rd2E),
        .c_value(rd3E),
        .d_value(rd4E),
        .result_value(mulResultE)
    );

    // WriteDataM será seleccionado correctamente en la etapa Memory


    extend ext(
               .instr(InstrD[31:7]),
               .immsrc(ImmSrcD),
               .immext(ImmExtD)
           );

    reg_decode_to_execute reg_decode_to_execute_instance(
                              .clk(clk),
                              .reset(reset),
                              .clr(FlushE),
                              .RD1D(RD1D),
                              .RD2D(RD2D),
                              .FRD1D(FRD1D), .FRD2D(FRD2D),  // NUEVO
                              .PCD(PCD),
                              .RdD(InstrD[11:7]),  // ✅ 5 bits
                              .ImmExtD(ImmExtD),
                              .PCPlus4D(PCPlus4D),
                              .RD1E(RD1E),
                              .RD2E(RD2E),
                              .FRD1E(FRD1E), .FRD2E(FRD2E),  // NUEVO
                              .PCE(PCE),
                              .RdE(RdE),  // ✅ 5 bits
                              .ImmExtE(ImmExtE),
                              .PCPlus4E(PCPlus4E),

                              // para el hazard unit
                              .Rs1D(Rs1D),
                              .Rs2D(Rs2D),
                              .Rs1E(Rs1E),
                              .Rs2E(Rs2E)

                          );

    //_____________________________________________
    // fase de Execution
    //_____________________________

    wire [31:0] SrcAE, SrcBE, WriteDataE, ALUResultE;
    wire [31:0] FPSrcAE, FPSrcBE, FPResultE;  // NUEVO
    wire [31:0] PCTargetE;

    // === OPERANDO A ===
    // Paso 1: Forwarding (obtener dato más reciente de RD1E)
    wire [31:0] SrcAE_forwarded;
    mux3 #(WIDTH) SrcAmux(
             .d0(RD1E),        // 00: Viene del registro (valor original)
             .d1(ResultW),     // 01: Forwarding desde Writeback
             .d2(ALUResultM),  // 10: Forwarding desde Memory
             .s(ForwardAE),    // Selector desde Hazard Unit
             .y(SrcAE_forwarded)  // Salida: dato "fresco"
         );

    // Paso 2: Decidir si usar el dato forwarded o forzar A=0 (para LUI)
    mux2 #(WIDTH) AluSrcAE_mux(
             .d0(SrcAE_forwarded),  // Dato normal (forwarded)
             .d1(32'b0),            // Forzar A=0 para LUI
             .s(ALUSrcE[1]),        // ALUSrcE=10 (LUI) -> s=1 -> A=0
             .y(SrcAE)              // Salida final hacia ALU
         );

    // === OPERANDO B ===
    // Paso 1: Forwarding (obtener dato más reciente de RD2E)
    mux3 #(WIDTH) SrcBmux(
             .d0(RD2E),        // 00: Viene del registro (valor original)
             .d1(ResultW),     // 01: Forwarding desde Writeback
             .d2(ALUResultM),  // 10: Forwarding desde Memory
             .s(ForwardBE),    // Selector desde Hazard Unit
             .y(WriteDataE)    // Salida: Dato 'fresco' para Store o para operar
         );

    // Paso 2: Decidir si usar dato forwarded o inmediato
    wire useImmB = (ALUSrcE[0] | ALUSrcE[1]);  // 01, 10, 11 -> usa inmediato
    mux2 #(WIDTH) AluSrcBE_mux(
             .d0(WriteDataE),   // Dato del registro (forwarded)
             .d1(ImmExtE),      // Inmediato extendido
             .s(useImmB),       // ALUSrcE != 00 -> usa inmediato
             .y(SrcBE)          // Salida final hacia ALU
         );

    alu alu(
            .a(SrcAE),
            .b(SrcBE),
            .alucontrol(ALUControlE),
            .result(ALUResultE),
            .zero(ZeroE)
        );

    // ========== FPU ==========
    wire [31:0] ForwardDataM = FPRegWriteM ? FPResultM : ALUResultM;
    wire [31:0] ForwardDataW = FPRegWriteW ? FPResultW : ResultW;

    // Forwarding FP separado
    mux3 #(WIDTH) FPSrcAmux(
             .d0(FRD1E),
             .d1(FPResultW),
             .d2(FPResultM),
             .s(ForwardAE_FP),  // ✅ Señal independiente
             .y(FPSrcAE)
         );

    mux3 #(WIDTH) FPSrcBmux(
             .d0(FRD2E),
             .d1(FPResultW),
             .d2(FPResultM),
             .s(ForwardBE_FP),  // ✅ Señal independiente
             .y(FPSrcBE)
         );

    // NUEVO: Instancia de la FPU
    fpu_top fpu(
                .op_a(FPSrcAE),
                .op_b(FPSrcBE),
                .op_code(FPUControlE),
                .round_mode(1'b0),  // RNE
                .result(FPResultE),
                .flags()  // Flags no usados por ahora
            );


    adder pcaddbranch(
              .a(PCE),
              .b(ImmExtE),
              .y(PCTargetE)
          );

    //_____________________
    // fase de Memory
    //_______________________________________

    wire [31:0] WriteDataM_base;  // WriteData antes del mux

    reg_execute_to_memory reg_execute_to_memory_instance(
                              .clk(clk),
                              .reset(reset),
                              .ALUResultE(ALUResultE),
                              .FPResultE(FPResultE),      // NUEVO
                              .WriteDataE(WriteDataE),
                              .MulResultE(mulResultE),    // NUEVO: Resultado de multiplicación vectorial
                              .RdE(RdE),  // ✅ 5 bits
                              .PCPlus4E(PCPlus4E),
                              .ALUResultM(ALUResultM),
                              .FPResultM(FPResultM),      // NUEVO
                              .WriteDataM_base(WriteDataM_base),
                              .MulResultM(mulResultM),    // NUEVO
                              .RdM(RdM),  // ✅ 5 bits
                              .PCPlus4M(PCPlus4M)
                          );

    // Mux para seleccionar entre WriteData normal o resultado de multiplicación vectorial
    mux2 #(WIDTH) muxToWriteData(
             .d0(WriteDataM_base),
             .d1(mulResultM),
             .s(WDMuxM),
             .y(WriteDataM)
         );

    //_____________________
    // fase de Write Back
    //_______________________________________

    wire [31:0] ReadDataW, PCPlus4W, ALUResultW;

    reg_memory_to_writeback reg_memory_to_writeback_instance(
                                .clk(clk),
                                .reset(reset),
                                .ReadDataM(ReadDataM),
                                .ALUResultM(ALUResultM),
                                .FPResultM(FPResultM),      // NUEVO
                                .PCPlus4M(PCPlus4M),
                                .RdM(RdM),  // ✅ 5 bits
                                .ReadDataW(ReadDataW),
                                .ALUResultW(ALUResultW),
                                .FPResultW(FPResultW),      // NUEVO
                                .PCPlus4W(PCPlus4W),
                                .RdW(RdW)  // ✅ 5 bits
                            );

    // Mux para resultado ENTERO

    mux3 #(WIDTH) resultmux(
             .d0(ALUResultW),
             .d1(ReadDataW),
             .d2(PCPlus4W),
             .s(ResultSrcW),
             .y(ResultW)
         );
    /* NOTA: FPResultW se escribe directamente en fprf
    ya que utiliza un registro independiente de la ALU entera */
    mux2 #(WIDTH) pcmux(
             .d0(PCPlus4F),
             .d1(PCTargetE),
             .s(PCSrcE),
             .y(PCNextF)
         );

endmodule
