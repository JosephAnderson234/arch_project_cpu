module reg_fetch_to_decode(
        input             clk,
        input             reset,
        input             en,   // Enable (Active High): Si es 0, congela el registro (Stall)
        input             clr,  // Clear (Active High): Si es 1, limpia el registro (Flush/Burbuja)

        // --------- ENTRADAS DESDE FETCH (F) ---------
        input      [31:0] InstrF,      // instrucción leída de la memoria
        input      [31:0] PCF,         // PC actual en F
        input      [31:0] PCPlus4F,    // PC+4 en F

        // --------- SALIDAS HACIA DECODE (D) ---------
        output reg [31:0] InstrD,      // instrucción latcheada para D
        output reg [31:0] PCD,         // PC en D
        output reg [31:0] PCPlus4D     // PC+4 en D
    );

    always @ (posedge clk or posedge reset) begin
        // 1. Reset Asíncrono (Prioridad Máxima: Arranque)
        if (reset) begin
            InstrD    <= 32'b0;
            PCD       <= 32'b0;
            PCPlus4D  <= 32'b0;
        end
        // 2. Flush Síncrono (Prioridad Media: Branch Taken)
        // Inserta una burbuja (NOP) descartando la instrucción actual
        else if (clr) begin
            InstrD    <= 32'b0;
            PCD       <= 32'b0;
            PCPlus4D  <= 32'b0;
        end
        // 3. Enable (Prioridad Baja: Operación Normal vs Stall)
        // Si en=1, cargamos datos. Si en=0, mantenemos el valor anterior (Stall).
        else if (en) begin
            InstrD    <= InstrF;
            PCD       <= PCF;
            PCPlus4D  <= PCPlus4F;
        end
    end

endmodule
