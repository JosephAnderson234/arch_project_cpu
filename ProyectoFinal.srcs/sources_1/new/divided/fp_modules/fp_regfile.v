module fp_regfile(
        input clk,
        input we3,
        input [4:0] a1, a2, a3,
        input [31:0] wd3,
        output [31:0] rd1, rd2
    );
    reg [31:0] fp_regs [31:0];
    integer i;

    // INICIALIZACIÓN EXPLÍCITA
    initial begin : init_fp_regs
        for (i = 0; i < 32; i = i + 1) begin
            fp_regs[i] = 32'h00000000;
        end

        // Pre-cargar valores de prueba
        fp_regs[1] = 32'h40200000; // f1 = 2.5
        fp_regs[2] = 32'h40400000; // f2 = 3.0
        fp_regs[3] = 32'h3F800000; // f3 = 1.0
        fp_regs[4] = 32'h40A00000; // f4 = 5.0

        $display("[fp_regfile] Registros FP inicializados:");
        $display("  f1 = 0x%h", fp_regs[1]);
        $display("  f2 = 0x%h", fp_regs[2]);
        $display("  f3 = 0x%h", fp_regs[3]);
        $display("  f4 = 0x%h", fp_regs[4]);
    end

    // Lectura asíncrona (sin protección de x0 para FP)
    assign rd1 = fp_regs[a1];
    assign rd2 = fp_regs[a2];

    // Escritura síncrona
    always @(posedge clk) begin
        if (we3 && a3 != 0) begin
            fp_regs[a3] <= wd3;
            $display("[fp_regfile] Escribiendo f%0d = 0x%h", a3, wd3);
        end
    end
endmodule