// ============================================================
// IF Stage Testbench
// ============================================================
module if_stage_tb;

    reg         clk, rst;
    reg         stall_f, flush_f;
    reg         branch_taken, jump;
    reg  [31:0] branch_target, jump_target;
    wire [31:0] if_id_pc, if_id_instr;

    if_stage uut (
        .clk          (clk),
        .rst          (rst),
        .stall_f      (stall_f),
        .flush_f      (flush_f),
        .branch_taken (branch_taken),
        .jump         (jump),
        .branch_target(branch_target),
        .jump_target  (jump_target),
        .if_id_pc     (if_id_pc),
        .if_id_instr  (if_id_instr)
    );

    always #5 clk = ~clk;

    initial begin
        $display("=== IF Stage Testbench ===");
        clk = 0; rst = 1;
        stall_f = 0; flush_f = 0;
        branch_taken = 0; jump = 0;
        branch_target = 0; jump_target = 0;

        // Release reset
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst = 0;

        // Let pipeline fill - watch PC advance by 4 each cycle
        repeat(6) begin
            @(posedge clk); #1;
            $display("PC=%h  instr=%h", if_id_pc, if_id_instr);
        end

        // Test stall - PC should hold
        $display("--- Asserting stall ---");
        stall_f = 1;
        repeat(3) begin
            @(posedge clk); #1;
            $display("PC=%h  instr=%h (stalled)", if_id_pc, if_id_instr);
        end
        stall_f = 0;

        // Test flush - IF/ID should go to NOP
        $display("--- Asserting flush ---");
        flush_f = 1;
        @(posedge clk); #1;
        $display("PC=%h  instr=%h (should be NOP=0)", if_id_pc, if_id_instr);
        flush_f = 0;

        // Test branch redirect
        $display("--- Branch taken to 0x10 ---");
        branch_taken = 1;
        branch_target = 32'h00000010; // jump to instruction 4
        @(posedge clk); #1;
        branch_taken = 0;
        repeat(4) begin
            @(posedge clk); #1;
            $display("PC=%h  instr=%h", if_id_pc, if_id_instr);
        end

        $display("=== Testbench Complete ===");
        $finish;
    end

endmodule