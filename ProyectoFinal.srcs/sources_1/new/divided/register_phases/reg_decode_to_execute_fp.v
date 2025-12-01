module reg_decode_to_execute_fp (
        input             clk,
        input             reset,
        input             clr, // <--- NUEVO INPUT
        input[31:0] rd1D, rd2D, rd3D, rd4D,
        output reg[31:0] rd1E, rd2E, rd3E, rd4E
);

    always @(posedge clk or posedge reset) begin
        if (reset || clr) begin
            // Reset/Flush: NOP
            rd1E <= 32'b0;
            rd2E <= 32'b0;
            rd3E <= 32'b0;
            rd4E <= 32'b0;
        end
        else begin
            // Propagar señales
            rd1E <= rd1D;
            rd2E <= rd2D;
            rd3E <= rd3D;
            rd4E <= rd4D;
        end
    end

endmodule