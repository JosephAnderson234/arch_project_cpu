module regfile(input  clk,
                   input  we3,
                   input  [4:0] a1, a2, a3,
                   input  [31:0] wd3,
                   output [31:0] rd1, rd2);

    reg [31:0] rf[31:0];

    // ESTO ES LO QUE TE FALTA: INICIALIZAR A CERO
    initial begin :hola
        integer i;
        for (i=0; i<32; i=i+1) begin
            rf[i] = 32'b0;
        end
    end

    // Escritura en flanco de bajada (Mantenemos tu lógica)
    always @(negedge clk) begin
        if (we3)
            rf[a3] <= wd3;
    end

    // Lectura con Bypass para evitar lecturas viejas
    // Si intentas leer lo que estás escribiendo en el mismo ciclo, te da el dato nuevo
    assign rd1 = (a1 == 0) ? 0 :
           ((a1 == a3) && we3) ? wd3 : rf[a1];

    assign rd2 = (a2 == 0) ? 0 :
           ((a2 == a3) && we3) ? wd3 : rf[a2];

endmodule