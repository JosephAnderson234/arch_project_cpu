module fpu_add_fp32_vivado (
        input  wire        op_sel,       // 0 = add (A+B), 1 = sub (A-B)
        input  wire [31:0] a,            // Operando A (FP32)
        input  wire [31:0] b,            // Operando B (FP32)
        output wire [31:0] result,       // Resultado (FP32)
        output wire [4:0] flags          // Flags de la operación
    );

    // -------------------------
    // Etapa 0 (comb): Unpack + clasificación + "specials"
    // -------------------------
    wire sA = a[31];
    wire sB_orig = b[31];
    wire sB = sB_orig ^ op_sel; // Invertir signo de B si es resta

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

    // Mantisas 24b (bit oculto=1 si normal)
    wire [23:0] MA_c = A_isSub ? {1'b0, fA} : {(eA!=8'd0), fA};
    wire [23:0] MB_c = B_isSub ? {1'b0, fB} : {(eB!=8'd0), fB};

    // Exponentes desbiaseados (convención subnormal = -126)
    function signed [12:0] unbias;
        input [7:0] E;
        begin
            if (E==8'd0)
                unbias = 13'sd1 - 13'sd127; // -126
            else
                unbias = $signed({5'b0,E}) - 13'sd127;
        end
    endfunction
    wire signed [12:0] eA_unb_c = unbias(eA);
    wire signed [12:0] eB_unb_c = unbias(eB);

    // Lógica de "Specials" de suma (directa)
    reg        sp_is_special_c;
    reg [31:0] sp_word_c;
    reg [4:0]  sp_flags_c;

    localparam [31:0] QNAN_CANON = {1'b0, 8'hFF, 1'b1, 22'd0};

    always @* begin
        sp_is_special_c = 1'b0;
        sp_word_c       = 32'b0;
        sp_flags_c      = 5'b0;

        // NaN -> qNaN canónico + invalid
        if (A_isNaN || B_isNaN) begin
            sp_is_special_c = 1'b1;
            sp_flags_c      = 5'b1_0000;                 // invalid
            sp_word_c       = QNAN_CANON;
        end
        // +Inf + -Inf => qNaN + invalid (considerando op_sel)
        else if ((A_isInf && B_isInf) && (sA ^ sB)) begin
            sp_is_special_c = 1'b1;
            sp_flags_c      = 5'b1_0000;
            sp_word_c       = QNAN_CANON;
        end
        // Inf + finite  OR Inf + Inf (same sign) => ±Inf
        else if (A_isInf || B_isInf) begin
            sp_is_special_c = 1'b1;
            sp_word_c       = {(A_isInf ? sA : sB), 8'hFF, 23'b0};
        end
    end

    // ---------------------------------------------------------
    // Etapa 1 (comb): Alineación + suma/resta + normalización
    // ---------------------------------------------------------
    // La operación efectiva depende de los signos DESPUÉS de aplicar op_sel
    wire effective_sub = (sA != sB); // RESTA efectiva si signos diferentes

    reg        sL_c, sS_c;
    reg signed [12:0] eL_c, eS_c;
    reg [27:0] extL_c, extS_c;
    reg [5:0]  shift_c;
    reg [27:0] S_aligned_c;
    reg        sticky_dropped_c;

    reg        sOUT_c1;
    reg signed [12:0] eSUM1_c1;
    reg [23:0] frac_with_hidden_c1;
    reg        G_c1, R_c1, S_c1;
    reg        exact_zero_c1;

    // Auxiliares para lógica interna
    reg [27:0] sum_ext;
    reg [27:0] diff_ext;
    reg [27:0] diff_norm;
    integer    i;
    integer    lz;
    reg        found;
    reg [27:0] dropped_mask;

    always @* begin
        // Inicialización de defaults
        sL_c = 1'b0;
        sS_c = 1'b0;
        eL_c = 13'sd0;
        eS_c = 13'sd0;
        extL_c = 28'd0;
        extS_c = 28'd0;
        shift_c = 6'd0;
        S_aligned_c = 28'd0;
        sticky_dropped_c = 1'b0;
        exact_zero_c1 = 1'b0;

        // ===== SELECCIÓN DEL MAYOR EN MAGNITUD ABSOLUTA =====
        // Siempre elegir el de mayor magnitud para alinear correctamente
        if (eA_unb_c > eB_unb_c) begin
            // A es mayor en magnitud
            sL_c  = sA;
            sS_c  = sB;
            eL_c  = eA_unb_c;
            eS_c  = eB_unb_c;
            extL_c = {1'b0, MA_c, 3'b000};
            extS_c = {1'b0, MB_c, 3'b000};

        end
        else if (eA_unb_c < eB_unb_c) begin
            // B es mayor en magnitud
            sL_c  = sB;
            sS_c  = sA;
            eL_c  = eB_unb_c;
            eS_c  = eA_unb_c;
            extL_c = {1'b0, MB_c, 3'b000};
            extS_c = {1'b0, MA_c, 3'b000};

        end
        else begin
            // Exponentes iguales → comparar mantisas
            if (MA_c >= MB_c) begin
                // A mayor o igual en magnitud
                sL_c  = sA;
                sS_c  = sB;
                eL_c  = eA_unb_c;
                eS_c  = eB_unb_c;
                extL_c = {1'b0, MA_c, 3'b000};
                extS_c = {1'b0, MB_c, 3'b000};
            end
            else begin
                // B mayor en magnitud
                sL_c  = sB;
                sS_c  = sA;
                eL_c  = eB_unb_c;
                eS_c  = eA_unb_c;
                extL_c = {1'b0, MB_c, 3'b000};
                extS_c = {1'b0, MA_c, 3'b000};
            end
        end

        // ===== ALINEACIÓN CON STICKY BIT =====
        if (eL_c >= eS_c)
            shift_c = (eL_c - eS_c);
        else
            shift_c = 6'd0;

        if (shift_c == 0) begin
            S_aligned_c      = extS_c;
            sticky_dropped_c = 1'b0;
        end
        else if (shift_c >= 6'd28) begin
            // Todo cae -> sticky = OR de todos los bits
            S_aligned_c      = 28'd0;
            sticky_dropped_c = |extS_c;
        end
        else begin
            S_aligned_c      = (extS_c >> shift_c);
            // Máscara para bits descartados
            dropped_mask     = (28'h1 << shift_c) - 1;
            sticky_dropped_c = |(extS_c & dropped_mask);
        end

        // ===== OPERACIÓN EFECTIVA: SUMA O RESTA =====
        if (!effective_sub) begin
            // ================= SUMA EFECTIVA =================
            // Signos iguales: |A| + |B| con signo común
            sOUT_c1 = sL_c; // Signo común
            sum_ext = extL_c + S_aligned_c;

            if (sum_ext == 28'd0) begin
                // Resultado exacto cero
                exact_zero_c1       = 1'b1;
                frac_with_hidden_c1 = 24'd0;
                G_c1 = 1'b0;
                R_c1 = 1'b0;
                S_c1 = 1'b0;
                eSUM1_c1 = 13'sd0;
                // Signo del cero: +0 en RNE, excepto si ambos eran -0
                sOUT_c1  = (A_isZero && B_isZero && sA && sB) ? 1'b1 : 1'b0;
            end
            else if (sum_ext[27]) begin
                // Overflow a bit 27 -> normalizar dividiendo por 2
                frac_with_hidden_c1 = sum_ext[27:4]; // 24 bits
                G_c1 = sum_ext[3];
                R_c1 = sum_ext[2];
                S_c1 = sum_ext[1] | sum_ext[0] | sticky_dropped_c;
                eSUM1_c1 = eL_c + 1;
            end
            else begin
                // Resultado normalizado en bit 26
                frac_with_hidden_c1 = sum_ext[26:3];
                G_c1 = sum_ext[2];
                R_c1 = sum_ext[1];
                S_c1 = sum_ext[0] | sticky_dropped_c;
                eSUM1_c1 = eL_c;
            end
        end
        else begin
            // ================ RESTA EFECTIVA =================
            // Signos diferentes: |A| - |B|
            // El signo viene del operando de mayor magnitud (sL_c)
            sOUT_c1  = sL_c;
            diff_ext = extL_c - S_aligned_c;

            if (diff_ext == 28'd0) begin
                // Cancelación exacta -> +0 en modo RNE
                exact_zero_c1       = 1'b1;
                frac_with_hidden_c1 = 24'd0;
                G_c1 = 1'b0;
                R_c1 = 1'b0;
                S_c1 = 1'b0;
                eSUM1_c1 = 13'sd0;
                sOUT_c1  = 1'b0; // Siempre +0 en RNE
            end
            else begin
                // ===== CONTEO DE LEADING ZEROS =====
                // Buscamos el primer '1' desde la posición 26 hacia abajo
                lz    = 0;
                found = 1'b0;
                for (i=26; i>=0; i=i-1) begin
                    if (!found && diff_ext[i]) begin
                        lz    = 26 - i;
                        found = 1'b1;
                    end
                end
                if (!found)
                    lz = 27;

                // Normalizar desplazando a la izquierda
                if (lz >= 27)
                    diff_norm = 28'd0;
                else
                    diff_norm = diff_ext << lz;

                // Extraer mantisa y bits de redondeo
                frac_with_hidden_c1 = diff_norm[26:3]; // 24 bits
                G_c1 = diff_norm[2];
                R_c1 = diff_norm[1];
                S_c1 = diff_norm[0] | sticky_dropped_c;
                eSUM1_c1 = eL_c - $signed({7'd0, lz[5:0]});
            end
        end
    end

    // ---------------------------------------------------------
    // Etapa 2 (comb): Redondeo RNE + empaquetado + flags
    // ---------------------------------------------------------
    wire [22:0] frac_pre_c2 = frac_with_hidden_c1[22:0];
    wire        roundUp_c2  = G_c1 && (R_c1 || S_c1 || frac_pre_c2[0]);

    wire [24:0] rounded_c2  = {1'b0, frac_with_hidden_c1} + (roundUp_c2 ? 25'd1 : 25'd0);

    reg  [23:0] frac_fin_c2;
    reg  signed [12:0] eSUM2_c2;
    always @* begin
        if (rounded_c2[24]) begin
            // Overflow por redondeo -> shift derecha
            frac_fin_c2 = rounded_c2[24:1];
            eSUM2_c2    = eSUM1_c1 + 1;
        end
        else begin
            frac_fin_c2 = rounded_c2[23:0];
            eSUM2_c2    = eSUM1_c1;
        end
    end

    // Detección de casos especiales
    wire is_zero_path_c2 = exact_zero_c1;

    // Exponente re-biased y condiciones
    wire signed [13:0] E_biased_c2     = eSUM2_c2 + 13'sd127;
    wire        overflow_c2            = (E_biased_c2 > 13'sd254);
    wire        under_biased_nonpos_c2 = (E_biased_c2 <= 0);
    wire        inexact_rnd_c2         = (G_c1 | R_c1 | S_c1);

    // Empaquetado final
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

        if (is_zero_path_c2) begin
            // Usar el signo correcto del cero
            normal_word_c2  = {sOUT_c1, 8'd0, 23'd0};
            normal_flags_c2 = 5'b0;
        end
        else if (overflow_c2) begin
            // Overflow -> ±Infinito
            normal_word_c2     = {sOUT_c1, 8'hFF, 23'b0};
            normal_flags_c2[2] = 1'b1;    // overflow
            normal_flags_c2[0] = 1'b1;    // inexact (siempre en overflow)
        end
        else if (under_biased_nonpos_c2) begin
            // ===== SUBNORMALIZACIÓN =====
            shift_den = (1 - E_biased_c2); // >= 1

            if (shift_den >= 24) begin
                // Todo se pierde -> resultado ±0
                normal_word_c2     = {sOUT_c1, 8'd0, 23'd0};
                normal_flags_c2[1] = 1'b1;                   // underflow
                lost_bits = |frac_fin_c2;
                normal_flags_c2[0] = inexact_rnd_c2 | lost_bits;
            end
            else begin
                // Shift dentro del rango [1..23]
                frac_den = frac_fin_c2 >> shift_den;
                normal_word_c2     = {sOUT_c1, 8'd0, frac_den[22:0]};
                normal_flags_c2[1] = 1'b1;                   // underflow

                // Detectar bits perdidos
                mask24 = ((24'h1 << shift_den) - 1);
                lost_bits = |(frac_fin_c2 & mask24);
                normal_flags_c2[0] = inexact_rnd_c2 | lost_bits;
            end
        end
        else begin
            // ===== NÚMERO NORMAL =====
            normal_word_c2     = {sOUT_c1, E_biased_c2[7:0], frac_fin_c2[22:0]};
            normal_flags_c2[0] = inexact_rnd_c2;
        end
    end

    // ===== SALIDAS FINALES =====
    assign result = sp_is_special_c ? sp_word_c  : normal_word_c2;
    assign flags  = sp_is_special_c ? sp_flags_c : normal_flags_c2;

endmodule
