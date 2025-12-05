`timescale 1ns / 1ps

module mul_floating_points(
    input  [31:0] a_value,
    input  [31:0] b_value,
    output [31:0] result_value
);

//======================================================
// 1. Separación de campos IEEE754
//======================================================
wire        a_sign      = a_value[31];
wire        b_sign      = b_value[31];
wire [7:0]  a_exp       = a_value[30:23];
wire [7:0]  b_exp       = b_value[30:23];
wire [22:0] a_mant      = a_value[22:0];
wire [22:0] b_mant      = b_value[22:0];

//======================================================
// 2. Detección de casos especiales IEEE754
//======================================================
wire a_is_zero = (a_exp == 8'd0) && (a_mant == 23'd0);
wire b_is_zero = (b_exp == 8'd0) && (b_mant == 23'd0);

wire a_is_inf  = (a_exp == 8'hFF) && (a_mant != 0);
wire b_is_inf  = (b_exp == 8'hFF) && (b_mant != 0);

wire a_is_nan  = (a_exp == 8'hFF) && (a_mant != 0);
wire b_is_nan  = (b_exp == 8'hFF) && (b_mant != 0);

//======================================================
// 3. Signo del resultado
//======================================================
wire res_sign = a_sign ^ b_sign;

//======================================================
// 4. Manejo de NaNs o infinitos
//======================================================
wire [31:0] nan_value = {1'b0, 8'hFF, 23'h400000}; // Quiet NaN estándar

reg [31:0] special_case;
always @(*) begin
    if (a_is_nan || b_is_nan)
        special_case = nan_value;

    else if (a_is_inf && b_is_zero)
        special_case = nan_value; // inf * 0 = NaN

    else if (a_is_zero && b_is_inf)
        special_case = nan_value;

    else if (a_is_inf || b_is_inf)
        special_case = {res_sign, 8'hFF, 23'd0};  // ±inf

    else if (a_is_zero || b_is_zero)
        special_case = {res_sign, 8'd0, 23'd0};  // ±0

    else
        special_case = 32'hFFFFFFFF;  // significa: NO caso especial
end

//======================================================
// 5. Si es caso especial, devolvemos directamente
//======================================================
wire special = (special_case != 32'hFFFFFFFF);

//======================================================
// 6. Preparar mantisas con bit oculto
//======================================================
wire [23:0] mant_a = (a_exp == 0) ? {1'b0, a_mant} : {1'b1, a_mant};
wire [23:0] mant_b = (b_exp == 0) ? {1'b0, b_mant} : {1'b1, b_mant};

//======================================================
// 7. Multiplicación de mantisas (48 bits)
//======================================================
wire [47:0] mant_prod = mant_a * mant_b;

//======================================================
// 8. Suma de exponentes
//======================================================
// Para subnormales, el exponente real es 1 - bias (= -126)
wire signed [9:0] a_exp_real = (a_exp == 0) ? -126 : (a_exp - 127);
wire signed [9:0] b_exp_real = (b_exp == 0) ? -126 : (b_exp - 127);

wire signed [9:0] exp_sum = a_exp_real + b_exp_real;

//======================================================
// 9. Normalización (si el producto tiene 1 en la posición 47)
//======================================================
wire leading = mant_prod[47];

wire [22:0] final_mantissa =
        leading ? mant_prod[46:24] : mant_prod[45:23];

wire signed [9:0] final_exp =
        leading ? (exp_sum + 1) : exp_sum;

//======================================================
// 10. Reajuste del exponente a rango IEEE754
//======================================================
wire overflow  = (final_exp > 127);
wire underflow = (final_exp < -126);

wire [7:0] final_exp_field =
        overflow  ? 8'hFF :
        underflow ? 8'h00 :
                    (final_exp + 127);

//======================================================
// 11. Resultado ensamblado
//======================================================
wire [31:0] normal_result =
    {res_sign, final_exp_field, final_mantissa};

//======================================================
// 12. Seleccionar entre caso especial o normal
//======================================================
assign result_value = special ? special_case : normal_result;

endmodule
