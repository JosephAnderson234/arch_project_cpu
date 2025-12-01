`timescale 1ns / 1ps

module t_debug;
  reg          clk, reset;
  wire [31:0]  WriteData, DataAdr;
  wire         MemWrite;

  top dut(.clk(clk), .reset(reset), .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));

  always begin clk = 1; #5; clk = 0; #5; end

  initial begin
    $display("=== DIAGNOSTICO PROFUNDO ===");
    reset = 1; #22; reset = 0;
    #600; $display("🚨 TIMEOUT"); $stop;
  end

  always @(negedge clk) begin
    if (!reset) begin
       // Monitor de la instrucción 20 (BEQ) y sus alrededores
       if (dut.pipeline1.PCF === 32'h20 || dut.pipeline1.PCF === 32'h1c) begin
           $display("\n--- ANALISIS CICLO T=%0t ---", $time);
           $display("PC Fetch: %h | Instr Decode: %h", dut.pipeline1.PCF, dut.pipeline1.InstrD);
           
           // 1. REVISAR STALLS (¿Se volvieron X?)
           $display("CONTROL: StallF=%b | FlushE=%b | PCSrcE=%b", 
                    dut.pipeline1.hu.StallF, dut.pipeline1.hu.FlushE, dut.pipeline1.PCSrcE);

           // 2. REVISAR EXECUTE (¿Qué entra a la ALU?)
           $display("EXECUTE: BranchE=%b | ZeroE=%b", dut.pipeline1.c.BranchE, dut.pipeline1.c.ZeroE);
           $display("   -> ALU SrcA: %h (Viene de %b)", dut.pipeline1.dp.SrcAE, dut.pipeline1.hu.ForwardAE);
           $display("   -> ALU SrcB: %h (Viene de %b)", dut.pipeline1.dp.SrcBE, dut.pipeline1.hu.ForwardBE);
           
           // 3. PISTA DE ORO: ¿El dato adelantado es X?
           // Si ForwardAE=10, miramos ALUResultM (Etapa Memoria)
           if (dut.pipeline1.hu.ForwardAE == 2'b10)
               $display("   -> Forwarding desde MEM: ALUResultM = %h", dut.pipeline1.dp.reg_execute_to_memory_instance.ALUResultM);
           
           // Si ForwardAE=01, miramos ResultW (Etapa Writeback)
           if (dut.pipeline1.hu.ForwardAE == 2'b01)
               $display("   -> Forwarding desde WB: ResultW = %h", dut.pipeline1.dp.resultmux.y);
               
           if (dut.pipeline1.PCSrcE === 1'bx) begin 
               $display("💥 ERROR ENCONTRADO AQUÍ 💥"); 
               $stop; 
           end
       end
    end
  end
endmodule