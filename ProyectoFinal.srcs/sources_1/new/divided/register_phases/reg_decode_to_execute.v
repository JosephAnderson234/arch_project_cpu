module reg_decode_to_execute (
        input             clk,
        input             reset,
        input             clr,

        // --------- DATOS (desde etapa D) ----------
        input      [31:0] RD1D, RD2D, PCD, ImmExtD, PCPlus4D,
        input [31:0] FRD1D,      // NUEVO: Dato FP rs1
        input [31:0] FRD2D,      // NUEVO: Dato FP rs2
        input      [4:0]  RdD,

        // --------- DATOS (hacia etapa E) ----------
        output reg [31:0] RD1E, RD2E, PCE, ImmExtE, PCPlus4E,
        output reg [31:0] FRD1E,  // NUEVO
        output reg [31:0] FRD2E,  // NUEVO
        output reg [4:0]  RdE,

        // hazard
        input [4:0] Rs1D, Rs2D,
        output reg [4:0] Rs1E, Rs2E
    );

    always @ (posedge clk or posedge reset) begin
        if (reset || clr) begin
            RD1E <= 0;
            RD2E <= 0;
            PCE <= 0;
            RdE <= 0;
            ImmExtE <= 0;
            PCPlus4E <= 0;
            Rs1E <= 0;
            Rs2E <= 0;
            FRD1E <= 32'b0;    // NUEVO
            FRD2E <= 32'b0;     //NUEVO
        end
        else begin
            // ✅ ESTE 'ELSE' FALTABA EN TU CÓDIGO
            // SI NO HAY FLUSH, CARGAMOS DATOS NORMALMENTE
            RD1E <= RD1D;
            RD2E <= RD2D;
            PCE <= PCD;
            RdE <= RdD;
            ImmExtE <= ImmExtD;
            PCPlus4E <= PCPlus4D;
            Rs1E <= Rs1D;
            Rs2E <= Rs2D;
            FRD1E <= FRD1D;    // NUEVO
            FRD2E <= FRD2D;    // NUEVO
        end
    end
endmodule
