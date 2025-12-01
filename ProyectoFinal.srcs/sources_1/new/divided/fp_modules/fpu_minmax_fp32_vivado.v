module fpu_minmax_fp32_vivado (
        input  wire [31:0] a,
        input  wire [31:0] b,
        input  wire        is_max,       // 1 = FMAX.S, 0 = FMIN.S
        output wire [31:0] result,
        output wire [4:0]  flags         // {invalid, div_by_zero, overflow, underflow, inexact}
    );

    // Desempaquetado
    wire sA = a[31];
    wire [7:0] eA = a[30:23];
    wire [22:0] fA = a[22:0];

    wire sB = b[31];
    wire [7:0] eB = b[30:23];
    wire [22:0] fB = b[22:0];

    // Clasificación
    wire A_isZero   = (eA == 8'd0) && (fA == 23'd0);
    wire B_isZero   = (eB == 8'd0) && (fB == 23'd0);

    wire A_isSub    = (eA == 8'd0) && (fA != 23'd0);
    wire B_isSub    = (eB == 8'd0) && (fB != 23'd0);

    wire A_isNormal = (eA != 8'd0) && (eA != 8'hFF);
    wire B_isNormal = (eB != 8'd0) && (eB != 8'hFF);

    wire A_isInf    = (eA == 8'hFF) && (fA == 23'd0);
    wire B_isInf    = (eB == 8'hFF) && (fB == 23'd0);

    wire A_isNaN    = (eA == 8'hFF) && (fA != 23'd0);
    wire B_isNaN    = (eB == 8'hFF) && (fB != 23'd0);

    wire A_isSNaN   = A_isNaN && (fA[22] == 1'b0);
    wire B_isSNaN   = B_isNaN && (fB[22] == 1'b0);
    wire A_isQNaN   = A_isNaN && (fA[22] == 1'b1);
    wire B_isQNaN   = B_isNaN && (fB[22] == 1'b1);

    localparam [31:0] QNAN_CANON = {1'b0, 8'hFF, 1'b1, 22'd0}; // +qNaN canónico

    reg [31:0] final_result;
    reg [4:0]  final_flags;

    // auxiliares para comparación
    reg [31:0] val_a_comp;
    reg [31:0] val_b_comp;

    always @(*) begin
        final_result = 32'd0;
        final_flags  = 5'b0;

        // Si hay SNaN -> setear invalid (según v2.2 la espec indica que se setea la flag,
        // pero no obliga a devolver la qNaN si el otro operando no es NaN).
        if (A_isSNaN || B_isSNaN) begin
            final_flags[4] = 1'b1; // invalid (bit alto según tu convención)
        end

        // Casos NaN / propagación conforme a v2.2:
        if (A_isNaN && B_isNaN) begin
            final_result = QNAN_CANON; // ambos NaN -> qNaN canónico
        end
        else if (A_isNaN) begin
            final_result = b; // propaga el no-NaN
        end
        else if (B_isNaN) begin
            final_result = a;
        end
        // Ambos ceros
        else if (A_isZero && B_isZero) begin
            if (sA == sB) begin
                // mismos signos -> devolver el operando (conservar signo/payload)
                final_result = a;
            end
            else begin
                // signos distintos: -0.0 < +0.0
                final_result = (is_max) ? 32'h00000000 : 32'h80000000;
            end
        end
        else begin
            // Comparación lexicográfica: invertir bits cuando negativo para comparar como enteros
            val_a_comp = sA ? ~a : a;
            val_b_comp = sB ? ~b : b;

            if (sA == sB) begin
                if (!sA) begin
                    // ambos positivos
                    final_result = (is_max) ? ((val_a_comp > val_b_comp) ? a : b)
                                 : ((val_a_comp < val_b_comp) ? a : b);
                end
                else begin
                    // ambos negativos
                    final_result = (is_max) ? ((val_a_comp < val_b_comp) ? a : b)
                                 : ((val_a_comp > val_b_comp) ? a : b);
                end
            end
            else begin
                // signos distintos: positivo > negativo
                final_result = (is_max) ? (sA ? b : a) : (sA ? a : b); //max:min
            end
        end
    end

    assign result = final_result;
    assign flags  = final_flags;

endmodule
