module imem(input  [31:0] a,
                output [31:0] rd);

    reg [31:0] RAM[63:0];
    integer i;

    initial begin
        // Initialize all memory to NOP (addi x0, x0, 0)
        for (i = 0; i < 64; i = i + 1) begin
            RAM[i] = 32'h00000013;
        end

        // Try to load from file
        $readmemh("riscvtest.txt", RAM);

        // Display first few instructions to verify loading
        $display("[imem] Instruction memory initialized:");
        $display("  RAM[0x00] = 0x%h", RAM[0]);
        $display("  RAM[0x01] = 0x%h", RAM[1]);
        $display("  RAM[0x02] = 0x%h", RAM[2]);
        $display("  RAM[0x03] = 0x%h", RAM[3]);
    end

    assign rd = RAM[a[31:2]]; // word aligned
endmodule