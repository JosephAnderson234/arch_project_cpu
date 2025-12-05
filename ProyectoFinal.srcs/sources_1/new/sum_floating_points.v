`timescale 1ns / 1ps

module fp_add(
    input  [31:0] a_value,
    input  [31:0] b_value,
    output [31:0] result_value
);

    // -----------------------------
    // Separar campos IEEE-754
    // -----------------------------
    wire        a_sign = a_value[31];
    wire        b_sign = b_value[31];
    wire [7:0]  a_exp  = a_value[30:23];
    wire [7:0]  b_exp  = b_value[30:23];
    wire [22:0] a_frac = a_value[22:0];
    wire [22:0] b_frac = b_value[22:0];

    // -----------------------------
    // Detectar casos especiales
    // -----------------------------
    wire a_nan   = (a_exp == 8'hFF) && (a_frac != 0);
    wire b_nan   = (b_exp == 8'hFF) && (b_frac != 0);

    wire a_inf   = (a_exp == 8'hFF) && (a_frac == 0);
    wire b_inf   = (b_exp == 8'hFF) && (b_frac == 0);

    wire a_zero  = (a_exp == 8'h00) && (a_frac == 0);
    wire b_zero  = (b_exp == 8'h00) && (b_frac == 0);

    wire a_sub   = (a_exp == 8'h00) && (a_frac != 0);
    wire b_sub   = (b_exp == 8'h00) && (b_frac != 0);

    // -----------------------------
    // Señales internas
    // -----------------------------
    reg  [31:0] result_reg;
    assign result_value = result_reg;

    reg  [24:0] mant_a, mant_b;
    reg  [25:0] A, B;
    reg  [26:0] SUM;
    reg  [7:0]  exp_a_adj, exp_b_adj, exp_out, exp_diff;
    reg         sign_out;

    reg  guard, round_bit, sticky;
    reg  [22:0] frac_out;
    reg  [4:0]  lzc; // leading zeros

    // =============================
    // LÓGICA PRINCIPAL
    // =============================
    always @(*) begin

        // Valor por defecto
        result_reg = 32'h00000000;

        // =============================
        // 1. CASOS ESPECIALES
        // =============================
        
        if (a_nan) begin
            result_reg = {1'b0, 8'hFF, 1'b1, a_frac[21:0]};
        end
        else if (b_nan) begin
            result_reg = {1'b0, 8'hFF, 1'b1, b_frac[21:0]};
        end

        else if (a_inf && b_inf) begin
            if (a_sign == b_sign)
                result_reg = {a_sign, 8'hFF, 23'h0};
            else
                result_reg = {1'b0, 8'hFF, 23'h400000}; // NaN
        end
        else if (a_inf)
            result_reg = {a_sign, 8'hFF, 23'h0};
        else if (b_inf)
            result_reg = {b_sign, 8'hFF, 23'h0};

        else if (a_zero && b_zero)
            result_reg = {a_sign & b_sign, 8'h00, 23'h0};
        else if (a_zero)
            result_reg = b_value;
        else if (b_zero)
            result_reg = a_value;

        else begin
        
            // =============================
            // 2. Preparar mantisas
            // =============================
            mant_a = a_sub ? {1'b0, a_frac, 1'b0} : {1'b1, a_frac, 1'b0};
            mant_b = b_sub ? {1'b0, b_frac, 1'b0} : {1'b1, b_frac, 1'b0};

            exp_a_adj = a_sub ? 8'h01 : a_exp;
            exp_b_adj = b_sub ? 8'h01 : b_exp;

            sticky = 0;

            // =============================
            // 3. Alineación de exponentes
            // =============================
            if (exp_a_adj >= exp_b_adj) begin
                exp_diff = exp_a_adj - exp_b_adj;
                exp_out  = exp_a_adj;

                A = {mant_a, 1'b0};

                if (exp_diff == 0) begin
                    B = {mant_b, 1'b0};
                end
                else begin
                    if (exp_diff >= 26) begin
                        B = 0;
                        sticky = |mant_b;
                    end else begin
                        B = ({mant_b, 1'b0} >> exp_diff);
                        sticky = |({mant_b,1'b0} << (26-exp_diff));
                    end
                    B[0] = B[0] | sticky;
                end
            end
            else begin
                exp_diff = exp_b_adj - exp_a_adj;
                exp_out  = b_exp;

                B = {mant_b, 1'b0};

                if (exp_diff == 0) begin
                    A = {mant_a, 1'b0};
                end
                else begin
                    if (exp_diff >= 26) begin
                        A = 0;
                        sticky = |mant_a;
                    end else begin
                        A = ({mant_a, 1'b0} >> exp_diff);
                        sticky = |({mant_a,1'b0} << (26-exp_diff));
                    end
                    A[0] = A[0] | sticky;
                end
            end

            // =============================
            // 4. Suma / Resta
            // =============================
            if (a_sign == b_sign) begin
                SUM = A + B;
                sign_out = a_sign;

                // Overflow normal
                if (SUM[26]) begin
                    guard = SUM[1];
                    round_bit = SUM[0];
                    SUM = SUM >> 1;
                    exp_out = exp_out + 1;
                end
            end
            else begin
                if (A >= B) begin
                    SUM = A - B;
                    sign_out = a_sign;
                end else begin
                    SUM = B - A;
                    sign_out = b_sign;
                end

                if (SUM == 0) begin
                    result_reg = 0;
                end
                else begin
                    // =============================
                    // 5. Normalización (LZC)
                    // =============================
                    lzc = 0;
                    while (lzc < 26 && SUM[25-lzc] == 0)
                        lzc = lzc + 1;

                    SUM = SUM << lzc;

                    if (exp_out > lzc)
                        exp_out = exp_out - lzc;
                    else
                        exp_out = 0;
                end
            end

            // =============================
            // 6. Extraer campos finales
            // =============================
            frac_out = SUM[24:2];
            guard     = SUM[1];
            round_bit = SUM[0];

            // =============================
            // 7. Round-to-nearest-even
            // =============================
            if (guard && (round_bit || frac_out[0])) begin
                frac_out = frac_out + 1;

                if (frac_out == 23'h800000) begin
                    exp_out = exp_out + 1;
                    frac_out = 0;
                end
            end

            // =============================
            // 8. Empaquetar resultado
            // =============================
            if (exp_out >= 8'hFF)
                result_reg = {sign_out, 8'hFF, 23'h0};
            else if (exp_out == 0)
                result_reg = {sign_out, 8'h00, frac_out};
            else
                result_reg = {sign_out, exp_out, frac_out};
        end
    end

endmodule
