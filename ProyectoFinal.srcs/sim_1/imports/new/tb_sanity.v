`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/18/2025 07:26:32 PM
// Design Name: 
// Module Name: tb_sanity
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns / 1ps

module tb_sanity;
  // Señales para Main Decoder
  reg  [6:0] op;
  wire RegWrite, MemWrite, Branch;
  
  // Instancia del Decoder (UUT 1)
  maindec uut_dec (
    .op(op),
    .RegWrite(RegWrite),
    .MemWrite(MemWrite),
    .Branch(Branch)
    // Ignoramos los demás por ahora
  );
  
  initial begin
    $display("=== INICIANDO TEST DE SANIDAD ===");
    
    // PRUEBA 1: Instrucción Opcode 0 (La "Burbuja" del Flush)
    op = 7'b0000000;
    #10;
    
    $display("INPUT: Opcode = 0000000 (Flush Bubble)");
    $display("OUTPUT: RegWrite = %b | MemWrite = %b | Branch = %b", RegWrite, MemWrite, Branch);
    
    if (RegWrite === 1'bx || MemWrite === 1'bx) begin
        $display("🚨 FALLO CRÍTICO: El Decoder saca 'X' cuando entra un 0.");
        $display("   SOLUCIÓN: Tu archivo maindec.v NO se ha actualizado o sigue mal.");
    end else begin
        $display("✅ DECODER OK: Saca 0 limpio.");
    end
    
    $stop;
  end
endmodule
