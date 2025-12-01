module fpu_mul_fp32_vivado (
        input  wire [31:0] a, b,
        output wire [31:0] result,
        output wire [4:0] flags
    );

    localparam [31:0] QNAN = {1'b0, 8'hFF, 1'b1, 22'd0};
    localparam BIAS = 127;

    // =========================================================================
    // Etapa 0 — Unpack + clasificación + specials
    // =========================================================================
    wire sA = a[31], sB = b[31];
    wire [7:0]  eA = a[30:23], eB = b[30:23];
    wire [22:0] fA = a[22:0],  fB = b[22:0];

    wire A_isZero = (eA==8'd0) && (fA==0);
    wire B_isZero = (eB==8'd0) && (fB==0);
    wire A_isSub  = (eA==0)     && (fA!=0);
    wire B_isSub  = (eB==0)     && (fB!=0);
    wire A_isInf  = (eA==8'hFF) && (fA==0);
    wire B_isInf  = (eB==8'hFF) && (fB==0);
    wire A_isNaN  = (eA==8'hFF) && (fA!=0);
    wire B_isNaN  = (eB==8'hFF) && (fB!=0);

    wire sOUT_c = sA ^ sB;

    reg sp_is_special_c;
    reg [31:0] sp_word_c;
    reg [4:0]  sp_flags_c;

    always @* begin
        sp_is_special_c = 0;
        sp_word_c       = 0;
        sp_flags_c      = 0;

        // NaN siempre gana
        if (A_isNaN || B_isNaN) begin
            sp_is_special_c = 1;
            sp_flags_c      = 5'b1_0000; // invalid
            sp_word_c       = QNAN;
        end
        // 0 * Inf => invalid
        else if ((A_isZero && B_isInf) || (A_isInf && B_isZero)) begin
            sp_is_special_c = 1;
            sp_flags_c      = 5'b1_0000; // invalid
            sp_word_c       = QNAN;
        end
        // Inf * finito → Inf
        else if (A_isInf || B_isInf) begin
            sp_is_special_c = 1;
            sp_word_c       = {sOUT_c, 8'hFF, 23'd0};
        end
        // 0 * finito → 0
        else if (A_isZero || B_isZero) begin
            sp_is_special_c = 1;
            sp_word_c       = {sOUT_c, 8'd0, 23'd0};
        end
    end

    // Mantisas con bit oculto
    wire [23:0] MA_c = A_isSub ? {1'b0,fA} : {(eA!=0), fA};
    wire [23:0] MB_c = B_isSub ? {1'b0,fB} : {(eB!=0), fB};

    // Exponentes desbiaseados
    function signed [12:0] unbias(input [7:0] E);
        if (E==0)
            unbias = 13'sd1 - 13'sd127;
        else
            unbias = $signed({5'b0,E}) - 13'sd127;
    endfunction

    wire signed [12:0] eA_unb = unbias(eA);
    wire signed [12:0] eB_unb = unbias(eB);

    wire signed [12:0] eSUM0 = eA_unb + eB_unb;

    // =========================================================================
    // Etapa 1 — Producto de mantisas + pre-normalización
    // =========================================================================
    wire [47:0] PROD = MA_c * MB_c;

    reg [47:0] Pn_c;
    reg signed [12:0] eSUM1_c;

    always @* begin
        if (PROD[47]) begin
            // 10.xxxxxxx
            Pn_c    = PROD >> 1;
            eSUM1_c = eSUM0 + 1;
        end
        else if (PROD[46]) begin
            // 1.xxxxxxx
            Pn_c    = PROD;
            eSUM1_c = eSUM0;
        end
        else begin
            // 0.xxxxxxx (solo ocurre con subnormales)
            Pn_c    = PROD << 1;
            eSUM1_c = eSUM0 - 1;
        end
    end

    // =========================================================================
    // Etapa 2 — Round-to-Nearest-Even + empaquetado IEEE
    // =========================================================================
    wire [22:0] frac_pre = Pn_c[45:23];
    wire        G = Pn_c[22];
    wire        R = Pn_c[21];
    wire        S = |Pn_c[20:0];

    wire roundUp = G && (R || S || frac_pre[0]);

    wire [23:0] frac_with_hidden = {Pn_c[46], frac_pre};

    wire [24:0] rounded = {1'b0, frac_with_hidden} +
         (roundUp ? 25'd1 : 25'd0);

    reg [23:0] frac_fin;
    reg signed [12:0] eSUM2;

    always @* begin
        if (rounded[24]) begin
            // overflow mantisa → shift + exp+1
            frac_fin = rounded[24:1];
            eSUM2    = eSUM1_c + 1;
        end
        else begin
            frac_fin = rounded[23:0];
            eSUM2    = eSUM1_c;
        end
    end

    // Sesgar exponente
    wire signed [13:0] E_biased = eSUM2 + 13'sd127;

    wire overflow  = (E_biased > 13'sd254);
    wire underflow = (E_biased <= 0);
    wire inexact   = (G | R | S);

    // =========================================================================
    // Empaquetado final (normal/subnormal)
    // =========================================================================
    reg [31:0] normal_word;
    reg [4:0]  normal_flags;

    integer shift;
    reg [23:0] frac_den;
    reg lost_bits;
    reg [23:0] mask;

    always @* begin
        normal_word  = 0;
        normal_flags = 0;
        lost_bits    = 0;

        if (overflow) begin
            normal_word       = {sOUT_c, 8'hFF, 23'd0};
            normal_flags[2]   = 1'b1;  // overflow
            normal_flags[0]   = 1'b1;  // inexact obligatorio
        end

        else if (underflow) begin
            shift = (1 - E_biased);

            if (shift >= 24) begin
                normal_word       = {sOUT_c, 8'd0, 23'd0};
                normal_flags[1]   = 1;
                lost_bits         = |frac_fin;
                normal_flags[0]   = inexact | lost_bits;
            end
            else begin
                mask = (24'h1 << shift) - 1;
                frac_den = frac_fin >> shift;

                lost_bits = |(frac_fin & mask);

                normal_word       = {sOUT_c, 8'd0, frac_den[22:0]};
                normal_flags[1]   = 1'b1;
                normal_flags[0]   = inexact | lost_bits;
            end
        end

        else begin
            normal_word       = {sOUT_c, E_biased[7:0], frac_fin[22:0]};
            normal_flags[0]   = inexact;
        end
    end

    // =========================================================================
    // Selección final: specials tienen prioridad
    // =========================================================================
    assign result = sp_is_special_c ? sp_word_c  : normal_word;
    assign flags  = sp_is_special_c ? sp_flags_c : normal_flags;

endmodule
