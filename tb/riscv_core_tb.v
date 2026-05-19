// RISC-V Core Integration Testbench
// ============================================================
module riscv_core_tb;

    reg clk, rst;

    riscv_core uut (
        .clk (clk),
        .rst (rst)
    );

    always #5 clk = ~clk;

    // Access register file internals for verification
    // Vivado allows hierarchical path access in simulation
    wire [31:0] x1 = uut.regfile.regs[1];
    wire [31:0] x2 = uut.regfile.regs[2];
    wire [31:0] x3 = uut.regfile.regs[3];
    wire [31:0] x5 = uut.regfile.regs[5];
    wire [31:0] x6 = uut.regfile.regs[6];
    wire [31:0] x7 = uut.regfile.regs[7];

    initial begin
        $display("=== RISC-V Core Integration Test ===");
        clk = 0; rst = 1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst = 0;

        // Wait enough cycles for all instructions to complete
        // 9 instructions + pipeline fill + stall cycles = ~20 cycles
        repeat(25) @(posedge clk);
        #1;

        $display("Register file state after execution:");
        $display("  x1 = %0d (expect 5)",  x1);
        $display("  x2 = %0d (expect 10)", x2);
        $display("  x3 = %0d (expect 15)", x3);
        $display("  x5 = %0d (expect 15)", x5);
        $display("  x6 = %0d (expect -1 = %0d)", x6, 32'hFFFFFFFF);
        $display("  x7 = %0d (expect 12)", x7);

        if (x1 == 32'd5)    $display("PASS x1=5");
        else                $display("FAIL x1=%0d", x1);

        if (x2 == 32'd10)   $display("PASS x2=10");
        else                $display("FAIL x2=%0d", x2);

        if (x3 == 32'd15)   $display("PASS x3=15 (forwarding worked)");
        else                $display("FAIL x3=%0d", x3);

        if (x5 == 32'd15)   $display("PASS x5=15 (load worked)");
        else                $display("FAIL x5=%0d", x5);

        if (x6 == 32'hFFFFFFFF) $display("PASS x6=-1");
        else                    $display("FAIL x6=%h", x6);

        if (x7 == 32'd12)   $display("PASS x7=12 (branch not taken)");
        else                $display("FAIL x7=%0d", x7);

        $display("=== Integration Test Complete ===");
        $finish;
    end
    always @(posedge clk) begin
        #1;
        $display("t=%0t PC=%h x1=%0d x2=%0d x3=%0d",
                  $time, uut.if_inst.pc,
                  uut.regfile.regs[1],
                  uut.regfile.regs[2],
                  uut.regfile.regs[3]);
    end
    always @(posedge clk) begin
        #1;
        $display("t=%0t PC=%h stall_f=%b flush_f=%b flush_d=%b branch_taken=%b forward_a=%b forward_b=%b",
                  $time, uut.if_inst.pc,
                  uut.stall_f, uut.flush_f, uut.flush_d,
                  uut.branch_taken,
                  uut.forward_a, uut.forward_b);
    end
endmodule