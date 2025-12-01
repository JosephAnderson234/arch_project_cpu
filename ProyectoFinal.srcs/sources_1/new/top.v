module top(input  clk, reset,
               output [31:0] WriteData, DataAdr,
               output MemWrite);

    wire [31:0] PC, Instr, ReadData;

    // instantiate processor and memories
    pipeline pipeline1(
                 .clk(clk),
                 .reset(reset),
                 .PCF(PC),
                 .InstrF(Instr),
                 .MemWriteM(MemWrite),
                 .DataAdr(DataAdr),
                 .WriteDataM(WriteData),
                 .ReadDataM(ReadData)
             );

    imem imem(
             .a(PC),
             .rd(Instr)
         );

    dmem dmem(
             .clk(clk),
             .we(MemWrite),
             .a(DataAdr),
             .wd(WriteData),
             .rd(ReadData)
         );
endmodule