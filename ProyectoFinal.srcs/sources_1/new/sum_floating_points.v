`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.11.2025 09:59:43
// Design Name: 
// Module Name: sum_floating_points
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Sumador IEEE-754 single precision (32-bit) mejorado
//              Maneja correctamente NaN, Inf, ceros, subnormales y redondeo
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sum_floating_points(
    input [31:0] a_value, 
    input [31:0] b_value, 
    output [31:0] result_value
);

    // ========== Decodificación de entradas ==========
    wire a_sign = a_value[31];
    wire b_sign = b_value[31];
    wire [7:0] a_exp = a_value[30:23];
    wire [7:0] b_exp = b_value[30:23];
    wire [22:0] a_frac = a_value[22:0];
    wire [22:0] b_frac = b_value[22:0];

    // ========== Detección de casos especiales ==========
    wire a_is_nan   = (a_exp == 8'hFF) && (a_frac != 23'h0);
    wire b_is_nan   = (b_exp == 8'hFF) && (b_frac != 23'h0);
    wire a_is_inf   = (a_exp == 8'hFF) && (a_frac == 23'h0);
    wire b_is_inf   = (b_exp == 8'hFF) && (b_frac == 23'h0);
    wire a_is_zero  = (a_exp == 8'h00) && (a_frac == 23'h0);
    wire b_is_zero  = (b_exp == 8'h00) && (b_frac == 23'h0);
    wire a_is_subnormal = (a_exp == 8'h00) && (a_frac != 23'h0);
    wire b_is_subnormal = (b_exp == 8'h00) && (b_frac != 23'h0);

    // ========== Registros internos ==========
    reg [31:0] result_reg;
    assign result_value = result_reg;

    // Variables de trabajo
    reg [24:0] mant_a;  // 25 bits: hidden bit + 23 frac + guard
    reg [24:0] mant_b;
    reg [7:0] exp_a_adj;
    reg [7:0] exp_b_adj;
    reg [7:0] exp_diff;
    reg [25:0] mant_aligned_a;  // 26 bits para alineación
    reg [25:0] mant_aligned_b;
    reg [26:0] sum_result;      // 27 bits para resultado de suma
    reg [7:0] result_exp;
    reg result_sign;
    reg [22:0] result_frac;
    reg [4:0] lz_count;         // Leading zero count
    reg guard, round, sticky;
    
    // ========== Lógica combinacional principal ==========
    always @(*) begin
        // Valores por defecto
        result_reg = 32'h0;
        mant_a = 25'h0;
        mant_b = 25'h0;
        exp_a_adj = 8'h0;
        exp_b_adj = 8'h0;
        exp_diff = 8'h0;
        mant_aligned_a = 26'h0;
        mant_aligned_b = 26'h0;
        sum_result = 27'h0;
        result_exp = 8'h0;
        result_sign = 1'b0;
        result_frac = 23'h0;
        guard = 1'b0;
        round = 1'b0;
        sticky = 1'b0;
        lz_count = 5'h0;

        // ========== MANEJO DE CASOS ESPECIALES ==========
        
        // Caso 1: Si cualquier operando es NaN
        if (a_is_nan) begin
            result_reg = {1'b0, 8'hFF, 1'b1, a_frac[21:0]}; // Quiet NaN
        end 
        else if (b_is_nan) begin
            result_reg = {1'b0, 8'hFF, 1'b1, b_frac[21:0]}; // Quiet NaN
        end
        
        // Caso 2: Infinitos
        else if (a_is_inf && b_is_inf) begin
            if (a_sign == b_sign) begin
                result_reg = {a_sign, 8'hFF, 23'h0}; // Inf + Inf = Inf (mismo signo)
            end else begin
                result_reg = {1'b0, 8'hFF, 1'b1, 22'h0}; // Inf - Inf = NaN
            end
        end
        else if (a_is_inf) begin
            result_reg = {a_sign, 8'hFF, 23'h0}; // Inf + x = Inf
        end
        else if (b_is_inf) begin
            result_reg = {b_sign, 8'hFF, 23'h0}; // x + Inf = Inf
        end
        
        // Caso 3: Ceros
        else if (a_is_zero && b_is_zero) begin
            result_reg = {a_sign & b_sign, 8'h00, 23'h0}; // +0 excepto -0 + -0 = -0
        end
        else if (a_is_zero) begin
            result_reg = b_value; // 0 + b = b
        end
        else if (b_is_zero) begin
            result_reg = a_value; // a + 0 = a
        end
        
        // ========== OPERACIÓN NORMAL ==========
        else begin
            // Preparar mantisas (con bit implícito)
            if (a_is_subnormal) begin
                mant_a = {1'b0, a_frac, 1'b0}; // Sin bit implícito para subnormales
                exp_a_adj = 8'h01; // Tratar como exponente 1
            end else begin
                mant_a = {1'b1, a_frac, 1'b0}; // Bit implícito = 1
                exp_a_adj = a_exp;
            end

            if (b_is_subnormal) begin
                mant_b = {1'b0, b_frac, 1'b0};
                exp_b_adj = 8'h01;
            end else begin
                mant_b = {1'b1, b_frac, 1'b0};
                exp_b_adj = b_exp;
            end

            // Alineación de exponentes
            if (exp_a_adj >= exp_b_adj) begin
                exp_diff = exp_a_adj - exp_b_adj;
                result_exp = exp_a_adj;
                mant_aligned_a = {mant_a, 1'b0};
                
                // Shift derecho con sticky bit
                if (exp_diff == 0) begin
                    mant_aligned_b = {mant_b, 1'b0};
                end else if (exp_diff >= 26) begin
                    mant_aligned_b = 26'h0;
                    mant_aligned_b[0] = |mant_b; // sticky
                end else begin
                    mant_aligned_b = {mant_b, 1'b0} >> exp_diff;
                    // Calcular sticky bit de los bits perdidos
                    case (exp_diff)
                        8'd1:  sticky = mant_b[0];
                        8'd2:  sticky = |mant_b[1:0];
                        8'd3:  sticky = |mant_b[2:0];
                        8'd4:  sticky = |mant_b[3:0];
                        8'd5:  sticky = |mant_b[4:0];
                        8'd6:  sticky = |mant_b[5:0];
                        8'd7:  sticky = |mant_b[6:0];
                        8'd8:  sticky = |mant_b[7:0];
                        8'd9:  sticky = |mant_b[8:0];
                        8'd10: sticky = |mant_b[9:0];
                        8'd11: sticky = |mant_b[10:0];
                        8'd12: sticky = |mant_b[11:0];
                        8'd13: sticky = |mant_b[12:0];
                        8'd14: sticky = |mant_b[13:0];
                        8'd15: sticky = |mant_b[14:0];
                        8'd16: sticky = |mant_b[15:0];
                        8'd17: sticky = |mant_b[16:0];
                        8'd18: sticky = |mant_b[17:0];
                        8'd19: sticky = |mant_b[18:0];
                        8'd20: sticky = |mant_b[19:0];
                        8'd21: sticky = |mant_b[20:0];
                        8'd22: sticky = |mant_b[21:0];
                        8'd23: sticky = |mant_b[22:0];
                        8'd24: sticky = |mant_b[23:0];
                        default: sticky = |mant_b[24:0];
                    endcase
                    mant_aligned_b[0] = mant_aligned_b[0] | sticky;
                end
            end else begin
                exp_diff = exp_b_adj - exp_a_adj;
                result_exp = exp_b_adj;
                mant_aligned_b = {mant_b, 1'b0};
                
                if (exp_diff == 0) begin
                    mant_aligned_a = {mant_a, 1'b0};
                end else if (exp_diff >= 26) begin
                    mant_aligned_a = 26'h0;
                    mant_aligned_a[0] = |mant_a;
                end else begin
                    mant_aligned_a = {mant_a, 1'b0} >> exp_diff;
                    case (exp_diff)
                        8'd1:  sticky = mant_a[0];
                        8'd2:  sticky = |mant_a[1:0];
                        8'd3:  sticky = |mant_a[2:0];
                        8'd4:  sticky = |mant_a[3:0];
                        8'd5:  sticky = |mant_a[4:0];
                        8'd6:  sticky = |mant_a[5:0];
                        8'd7:  sticky = |mant_a[6:0];
                        8'd8:  sticky = |mant_a[7:0];
                        8'd9:  sticky = |mant_a[8:0];
                        8'd10: sticky = |mant_a[9:0];
                        8'd11: sticky = |mant_a[10:0];
                        8'd12: sticky = |mant_a[11:0];
                        8'd13: sticky = |mant_a[12:0];
                        8'd14: sticky = |mant_a[13:0];
                        8'd15: sticky = |mant_a[14:0];
                        8'd16: sticky = |mant_a[15:0];
                        8'd17: sticky = |mant_a[16:0];
                        8'd18: sticky = |mant_a[17:0];
                        8'd19: sticky = |mant_a[18:0];
                        8'd20: sticky = |mant_a[19:0];
                        8'd21: sticky = |mant_a[20:0];
                        8'd22: sticky = |mant_a[21:0];
                        8'd23: sticky = |mant_a[22:0];
                        8'd24: sticky = |mant_a[23:0];
                        default: sticky = |mant_a[24:0];
                    endcase
                    mant_aligned_a[0] = mant_aligned_a[0] | sticky;
                end
            end

            // Suma/Resta según signos
            if (a_sign == b_sign) begin
                // Mismos signos: suma de magnitudes
                sum_result = {1'b0, mant_aligned_a} + {1'b0, mant_aligned_b};
                result_sign = a_sign;
                
                // Normalización después de suma
                if (sum_result[26]) begin
                    // Overflow: shift derecho
                    guard = sum_result[1];
                    round = sum_result[0];
                    sum_result = sum_result >> 1;
                    result_exp = result_exp + 8'd1;
                end
                
                result_frac = sum_result[24:2];
                guard = sum_result[1];
                round = sum_result[0];
                
            end else begin
                // Signos diferentes: resta de magnitudes
                if (mant_aligned_a >= mant_aligned_b) begin
                    sum_result = {1'b0, mant_aligned_a} - {1'b0, mant_aligned_b};
                    result_sign = a_sign;
                end else begin
                    sum_result = {1'b0, mant_aligned_b} - {1'b0, mant_aligned_a};
                    result_sign = b_sign;
                end
                
                // Normalización después de resta (leading zero detection)
                if (sum_result == 27'h0) begin
                    result_reg = 32'h0; // Resultado exacto es cero
                end else begin
                    // Contar leading zeros y normalizar
                    lz_count = 5'd0;
                    if      (!sum_result[25]) begin lz_count = 5'd1;  if (!sum_result[24]) begin lz_count = 5'd2;
                        if (!sum_result[23]) begin lz_count = 5'd3;  if (!sum_result[22]) begin lz_count = 5'd4;
                        if (!sum_result[21]) begin lz_count = 5'd5;  if (!sum_result[20]) begin lz_count = 5'd6;
                        if (!sum_result[19]) begin lz_count = 5'd7;  if (!sum_result[18]) begin lz_count = 5'd8;
                        if (!sum_result[17]) begin lz_count = 5'd9;  if (!sum_result[16]) begin lz_count = 5'd10;
                        if (!sum_result[15]) begin lz_count = 5'd11; if (!sum_result[14]) begin lz_count = 5'd12;
                        if (!sum_result[13]) begin lz_count = 5'd13; if (!sum_result[12]) begin lz_count = 5'd14;
                        if (!sum_result[11]) begin lz_count = 5'd15; if (!sum_result[10]) begin lz_count = 5'd16;
                        if (!sum_result[9])  begin lz_count = 5'd17; if (!sum_result[8])  begin lz_count = 5'd18;
                        if (!sum_result[7])  begin lz_count = 5'd19; if (!sum_result[6])  begin lz_count = 5'd20;
                        if (!sum_result[5])  begin lz_count = 5'd21; if (!sum_result[4])  begin lz_count = 5'd22;
                        if (!sum_result[3])  begin lz_count = 5'd23; if (!sum_result[2])  begin lz_count = 5'd24;
                        if (!sum_result[1])  begin lz_count = 5'd25; if (!sum_result[0])  begin lz_count = 5'd26;
                        end end end end end end end end end end end end end
                        end end end end end end end end end end end end end
                    end
                    
                    // Shift izquierdo y ajustar exponente
                    sum_result = sum_result << lz_count;
                    
                    if (result_exp > lz_count) begin
                        result_exp = result_exp - lz_count;
                    end else begin
                        result_exp = 8'h00; // Subnormal
                    end
                    
                    result_frac = sum_result[24:2];
                    guard = sum_result[1];
                    round = sum_result[0];
                end
            end

            // Redondeo Round-to-Nearest-Even
            if (guard && (round || result_frac[0])) begin
                if (result_frac == 23'h7FFFFF) begin
                    result_frac = 23'h0;
                    result_exp = result_exp + 8'd1;
                end else begin
                    result_frac = result_frac + 23'd1;
                end
            end

            // Verificar overflow de exponente
            if (result_exp >= 8'hFF) begin
                result_reg = {result_sign, 8'hFF, 23'h0}; // Infinito
            end else if (result_exp == 8'h00) begin
                result_reg = {result_sign, 8'h00, result_frac}; // Subnormal o cero
            end else begin
                result_reg = {result_sign, result_exp, result_frac};
            end
        end

endmodule
