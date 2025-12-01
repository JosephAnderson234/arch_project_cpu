module fpu_div_fp32_vivado (
        input  wire [31:0] a,            // Operando A (FP32) - numerador
        input  wire [31:0] b,            // Operando B (FP32) - denominador
        output wire [31:0] result,       // Resultado (FP32)
        output wire [4:0] flags          // {invalid, div_by_zero, overflow, underflow, inexact}
    );

    localparam [31:0] QNAN_CANON = {1'b0, 8'hFF, 1'b1, 22'd0};
    localparam BIAS = 127;

    // -------------------------
    // Etapa 0 (comb): Unpack + clasificación + specials
    // -------------------------
    wire sA = a[31], sB = b[31];
    wire [7:0]  eA = a[30:23], eB = b[30:23];
    wire [22:0] fA = a[22:0],  fB = b[22:0];

    wire A_isZero = (eA==8'd0) && (fA==23'd0);
    wire B_isZero = (eB==8'd0) && (fB==23'd0);
    wire A_isSub  = (eA==8'd0) && (fA!=23'd0);
    wire B_isSub  = (eB==8'd0) && (fB!=23'd0);
    wire A_isInf  = (eA==8'hFF) && (fA==23'd0);
    wire B_isInf  = (eB==8'hFF) && (fB==23'd0);
    wire A_isNaN  = (eA==8'hFF) && (fA!=23'd0);
    wire B_isNaN  = (eB==8'hFF) && (fB!=23'd0);

    // Signo de salida
    wire sOUT_c = sA ^ sB;

    // Mantisas 24b (bit oculto=1 si normal)
    wire [23:0] MA_c = A_isSub ? {1'b0, fA} : {(eA!=8'd0), fA};
    wire [23:0] MB_c = B_isSub ? {1'b0, fB} : {(eB!=8'd0), fB};

    // Exponentes desbiaseados (signed)
    function signed [12:0] unbias;
        input [7:0] E;
        begin
            if (E==8'd0)
                unbias = 13'sd1 - 13'sd127;  // -126
            else
                unbias = $signed({5'b0,E}) - 13'sd127;
        end
    endfunction
    wire signed [12:0] eA_unb_c = unbias(eA);
    wire signed [12:0] eB_unb_c = unbias(eB);

    // Specials (comb)
    reg        sp_is_special_c;
    reg [31:0] sp_word_c;
    reg [4:0]  sp_flags_c;

    always @* begin
        sp_is_special_c = 1'b0;
        sp_word_c       = 32'b0;
        sp_flags_c      = 5'b0;

        // NaN en entrada -> qNaN + invalid
        // 0/0 y Inf/Inf también invalid (qNaN)
        if (A_isNaN || B_isNaN || (A_isZero && B_isZero) || (A_isInf && B_isInf)) begin
            sp_is_special_c = 1'b1;
            sp_flags_c      = 5'b1_0000;    // invalid
            sp_word_c       = QNAN_CANON;
        end
        // x / 0 (x finito no-cero) => ±Inf + div_by_zero
        else if (B_isZero && !(A_isZero || A_isNaN || A_isInf)) begin
            sp_is_special_c = 1'b1;
            sp_flags_c      = 5'b0_1000;    // div_by_zero
            sp_word_c       = {sOUT_c, 8'hFF, 23'b0};
        end
        // Inf / finite => ±Inf
        else if (A_isInf && !B_isInf) begin
            sp_is_special_c = 1'b1;
            sp_word_c       = {sOUT_c, 8'hFF, 23'b0};
        end
        // 0 / Inf => ±0
        else if (A_isZero && B_isInf) begin
            sp_is_special_c = 1'b1;
            sp_word_c       = {sOUT_c, 8'd0, 23'd0};
        end
        // else -> camino normal
    end

    // Señales de la etapa 0 que alimentan el camino normal
    wire sOUT_e1_input = sOUT_c;
    wire [23:0] MA_e1_input = MA_c;
    wire [23:0] MB_e1_input = MB_c;
    wire signed [12:0] eDIFF0_e1_input = eA_unb_c - eB_unb_c;
    wire sp_is_special_e1_input = sp_is_special_c;
    wire [31:0] sp_word_e1_input = sp_word_c;
    wire [4:0] sp_flags_e1_input = sp_flags_c;

    // ---------------------------------------------------------
    // Etapa 1 (comb): División de mantisas + pre-normalización
    // ---------------------------------------------------------
    // Q_scaled: aproximación a la mantisa escalada (tamaño 26 bits en este diseño)
    // Si MA >= MB calculamos con <<25 (Q_scaled en [2^25 .. 2^26) => bit 25 = 1)
    // Si MA <  MB calculamos con <<26 (Q_scaled en [2^25 .. 2^26) también tras ajustar exp)
    reg  [25:0] Q_scaled_c;
    reg         sticky_rem_c; // indicará si hay resto no-cero (S)
    reg  signed [12:0] eDIFF1_c;

    // temporales para división
    reg [49:0] numer; // lo usamos para crear {MA, shift}
    reg [23:0] denom;

    always @* begin
        // Defaults
        Q_scaled_c    = 26'd0;
        sticky_rem_c  = 1'b0;
        eDIFF1_c      = eDIFF0_e1_input;
        denom         = MB_e1_input;

        if (MB_e1_input == 24'd0) begin
            // debería haber sido manejado por specials; proteger
            Q_scaled_c   = 26'd0;
            sticky_rem_c = 1'b0;
            eDIFF1_c     = eDIFF0_e1_input;
        end
        else if (MA_e1_input >= MB_e1_input) begin
            // Queremos Q_scaled con MSB en bit 25 (1 <= Q < 2)
            numer = {MA_e1_input, 25'd0}; // 24 + 25 = 49 bits
            Q_scaled_c = numer / denom;   // división entera
            sticky_rem_c = ( (numer % denom) != 0 );
            eDIFF1_c = eDIFF0_e1_input;
            // En algunos casos extremos Q_scaled_c[25] podría quedar 0 (teórico),
            // pero usando <<25 con MA>=MB garantizamos Q in [1,2), por tanto bit25=1.
        end
        else begin
            // MA < MB -> queremos normalizar la mantisa (Q in [0.5,1) -> lo transformamos a [1,2) reduciendo expo)
            numer = {MA_e1_input, 26'd0};
            Q_scaled_c = numer / denom;   // ahora Q_scaled in [2^25/2 .. 2^26) -> bit25 may be 1
            sticky_rem_c = ( (numer % denom) != 0 );
            eDIFF1_c = eDIFF0_e1_input - 1;
            // tras esto Q_scaled_c[25] normalmente == 1 (porque numer/denom ~ (MA/MB)*2^26 >= 2^25)
        end
    end

    // Señales Etapa 1 -> Etapa 2
    wire sOUT_e2_input = sOUT_e1_input;
    wire [25:0] Q_scaled_e2_input = Q_scaled_c;
    wire S_e2_input = sticky_rem_c;
    wire signed [12:0] eDIFF1_e2_input = eDIFF1_c;
    wire sp_is_special_e2_input = sp_is_special_e1_input;
    wire [31:0] sp_word_e2_input = sp_word_e1_input;
    wire [4:0] sp_flags_e2_input = sp_flags_e1_input;

    // ---------------------------------------------------------
    // Etapa 2 (comb): RNE + empaquetado + flags
    // ---------------------------------------------------------
    // Interpretación de Q_scaled:
    // Q_scaled[25] = implicit leading bit (debe ser 1 si normalizado)
    // bits [24:2] -> frac_pre (23 bits)
    // bits [1] -> G
    // bits [0] -> R
    wire [22:0] frac_pre_c2 = Q_scaled_e2_input[24:2];
    wire        G_c2        = Q_scaled_e2_input[1];
    wire        R_c2        = Q_scaled_e2_input[0];
    wire        S_c2        = S_e2_input;
    wire        roundUp_c2  = G_c2 && (R_c2 || S_c2 || frac_pre_c2[0]);

    // Mantisa con hidden bit (24 bits)
    wire [23:0] frac_with_hidden_c2 = {Q_scaled_e2_input[25], frac_pre_c2}; // bit25 is hidden
    wire [24:0] rounded_c2 = {1'b0, frac_with_hidden_c2} + (roundUp_c2 ? 25'd1 : 25'd0);

    reg  [23:0] frac_fin_c2;
    reg  signed [12:0] eSUM2_c2;
    always @* begin
        if (rounded_c2[24]) begin
            // overflow en mantisa -> shift right 1 implícito y exponente +1
            frac_fin_c2 = rounded_c2[24:1];
            eSUM2_c2    = eDIFF1_e2_input + 1;
        end
        else begin
            frac_fin_c2 = rounded_c2[23:0];
            eSUM2_c2    = eDIFF1_e2_input;
        end
    end

    // Exponente re-bias y estados
    wire signed [13:0] E_biased_c2     = eSUM2_c2 + 13'sd127;
    wire        overflow_c2            = (E_biased_c2 > 13'sd254);
    wire        under_biased_nonpos_c2 = (E_biased_c2 <= 0);
    wire        inexact_rnd_c2         = (G_c2 | R_c2 | S_c2);

    // Empaquetado normal/subnormal
    reg [31:0] normal_word_c2;
    reg [4:0]  normal_flags_c2;

    integer shift_den;
    reg [23:0] frac_den;
    reg        lost_bits;
    reg [23:0] mask24;

    always @* begin
        normal_word_c2  = 32'b0;
        normal_flags_c2 = 5'b0;
        lost_bits = 1'b0;

        if (overflow_c2) begin
            // Overflow -> ±Inf; mark inexact (per IEEE when overflow produced by rounding/inexact)
            normal_word_c2     = {sOUT_e2_input, 8'hFF, 23'b0};
            normal_flags_c2[2] = 1'b1; // overflow
            normal_flags_c2[0] = 1'b1; // inexact (set on overflow)
        end
        else if (under_biased_nonpos_c2) begin
            // Subnormalización (underflow)
            shift_den = (1 - E_biased_c2); // >= 1
            if (shift_den >= 24) begin
                // todo se pierde -> ±0
                normal_word_c2     = {sOUT_e2_input, 8'd0, 23'd0};
                normal_flags_c2[1] = 1'b1; // underflow
                lost_bits = |frac_fin_c2;
                normal_flags_c2[0] = inexact_rnd_c2 | lost_bits;
            end
            else begin
                // shift_den in [1..23]
                mask24 = ((24'h1 << shift_den) - 1);
                frac_den = frac_fin_c2 >> shift_den;
                normal_word_c2     = {sOUT_e2_input, 8'd0, frac_den[22:0]};
                normal_flags_c2[1] = 1'b1; // underflow
                lost_bits = |(frac_fin_c2 & mask24);
                normal_flags_c2[0] = inexact_rnd_c2 | lost_bits;
            end
        end
        else begin
            // Normal
            normal_word_c2     = {sOUT_e2_input, E_biased_c2[7:0], frac_fin_c2[22:0]};
            normal_flags_c2[0] = inexact_rnd_c2;
        end
    end

    // Selección final respetando specials
    assign result = sp_is_special_e2_input ? sp_word_e2_input  : normal_word_c2;
    assign flags  = sp_is_special_e2_input ? sp_flags_e2_input : normal_flags_c2;

endmodule