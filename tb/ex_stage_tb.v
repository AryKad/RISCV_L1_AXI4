// ============================================================
// EX Stage Testbench
// ============================================================
module ex_stage_tb;

    reg         clk, rst;
    reg  [31:0] id_ex_pc;
    reg  [31:0] id_ex_rs1_data, id_ex_rs2_data;
    reg  [4:0]  id_ex_rs1_addr, id_ex_rs2_addr, id_ex_rd_addr;
    reg  [31:0] id_ex_imm;
    reg  [3:0]  id_ex_alu_ctrl;
    reg         id_ex_alu_src, id_ex_reg_write;
    reg         id_ex_mem_read, id_ex_mem_write, id_ex_mem_to_reg;
    reg         id_ex_branch, id_ex_jump, id_ex_is_mul;
    reg  [2:0]  id_ex_funct3;
    reg  [1:0]  forward_a, forward_b;
    reg  [31:0] ex_mem_alu_result, wb_result;

    wire        branch_taken, jump;
    wire [31:0] branch_target, jump_target;
    wire [31:0] ex_mem_alu_result_reg;
    wire [31:0] ex_mem_rs2_data;
    wire [4:0]  ex_mem_rd_addr;
    wire        ex_mem_reg_write, ex_mem_mem_read;
    wire        ex_mem_mem_write, ex_mem_mem_to_reg;
    wire [2:0]  ex_mem_funct3;

    ex_stage uut (
        .clk                  (clk),
        .rst                  (rst),
        .id_ex_pc             (id_ex_pc),
        .id_ex_rs1_data       (id_ex_rs1_data),
        .id_ex_rs2_data       (id_ex_rs2_data),
        .id_ex_rs1_addr       (id_ex_rs1_addr),
        .id_ex_rs2_addr       (id_ex_rs2_addr),
        .id_ex_rd_addr        (id_ex_rd_addr),
        .id_ex_imm            (id_ex_imm),
        .id_ex_alu_ctrl       (id_ex_alu_ctrl),
        .id_ex_alu_src        (id_ex_alu_src),
        .id_ex_reg_write      (id_ex_reg_write),
        .id_ex_mem_read       (id_ex_mem_read),
        .id_ex_mem_write      (id_ex_mem_write),
        .id_ex_mem_to_reg     (id_ex_mem_to_reg),
        .id_ex_branch         (id_ex_branch),
        .id_ex_jump           (id_ex_jump),
        .id_ex_funct3         (id_ex_funct3),
        .id_ex_is_mul         (id_ex_is_mul),
        .forward_a            (forward_a),
        .forward_b            (forward_b),
        .ex_mem_alu_result    (ex_mem_alu_result),
        .wb_result            (wb_result),
        .branch_taken         (branch_taken),
        .jump                 (jump),
        .branch_target        (branch_target),
        .jump_target          (jump_target),
        .ex_mem_alu_result_reg(ex_mem_alu_result_reg),
        .ex_mem_rs2_data      (ex_mem_rs2_data),
        .ex_mem_rd_addr       (ex_mem_rd_addr),
        .ex_mem_reg_write     (ex_mem_reg_write),
        .ex_mem_mem_read      (ex_mem_mem_read),
        .ex_mem_mem_write     (ex_mem_mem_write),
        .ex_mem_mem_to_reg    (ex_mem_mem_to_reg),
        .ex_mem_funct3        (ex_mem_funct3)
    );

    always #5 clk = ~clk;

    initial begin
        $display("=== EX Stage Testbench ===");
        clk = 0; rst = 1;
        id_ex_pc = 0; id_ex_rs1_data = 0; id_ex_rs2_data = 0;
        id_ex_rs1_addr = 0; id_ex_rs2_addr = 0; id_ex_rd_addr = 0;
        id_ex_imm = 0; id_ex_alu_ctrl = 0; id_ex_alu_src = 0;
        id_ex_reg_write = 0; id_ex_mem_read = 0; id_ex_mem_write = 0;
        id_ex_mem_to_reg = 0; id_ex_branch = 0; id_ex_jump = 0;
        id_ex_is_mul = 0; id_ex_funct3 = 0;
        forward_a = 0; forward_b = 0;
        ex_mem_alu_result = 0; wb_result = 0;

        @(posedge clk); #1;
        @(posedge clk); #1;
        rst = 0;

        // --------------------------------------------------
        // Test 1: ADD x3 = x1 + x2 (no forwarding)
        // rs1=10, rs2=20, expect result=30
        // --------------------------------------------------
        @(posedge clk); #1;
        id_ex_rs1_data = 32'd10;
        id_ex_rs2_data = 32'd20;
        id_ex_alu_ctrl = 4'b0000; // ADD
        id_ex_alu_src  = 1'b0;    // use rs2
        id_ex_rd_addr  = 5'd3;
        id_ex_reg_write= 1'b1;
        id_ex_branch   = 1'b0;
        id_ex_jump     = 1'b0;
        id_ex_is_mul   = 1'b0;
        forward_a = 2'b00; forward_b = 2'b00;

        @(posedge clk); #1;
        if (ex_mem_alu_result_reg == 32'd30)
            $display("PASS Test1: ADD result=%0d", ex_mem_alu_result_reg);
        else
            $display("FAIL Test1: ADD got=%0d", ex_mem_alu_result_reg);

        // --------------------------------------------------
        // Test 2: ADDI x1 = x0 + 42 (immediate)
        // rs1=0, imm=42, alu_src=1, expect result=42
        // --------------------------------------------------
        @(posedge clk); #1;
        id_ex_rs1_data = 32'd0;
        id_ex_imm      = 32'd42;
        id_ex_alu_ctrl = 4'b0000; // ADD
        id_ex_alu_src  = 1'b1;    // use immediate
        id_ex_rd_addr  = 5'd1;
        id_ex_reg_write= 1'b1;
        id_ex_is_mul   = 1'b0;
        forward_a = 2'b00; forward_b = 2'b00;

        @(posedge clk); #1;
        if (ex_mem_alu_result_reg == 32'd42)
            $display("PASS Test2: ADDI result=%0d", ex_mem_alu_result_reg);
        else
            $display("FAIL Test2: ADDI got=%0d", ex_mem_alu_result_reg);

        // --------------------------------------------------
        // Test 3: Forwarding from EX/MEM
        // rs1 should come from ex_mem_alu_result (forward_a=10)
        // ex_mem has value 99, rs2=1, expect 99+1=100
        // --------------------------------------------------
        @(posedge clk); #1;
        id_ex_rs1_data    = 32'd0;   // stale value in register
        id_ex_rs2_data    = 32'd1;
        ex_mem_alu_result = 32'd99;  // fresh value from EX/MEM
        id_ex_alu_ctrl    = 4'b0000; // ADD
        id_ex_alu_src     = 1'b0;
        id_ex_is_mul      = 1'b0;
        forward_a = 2'b10; // forward from EX/MEM
        forward_b = 2'b00;

        @(posedge clk); #1;
        if (ex_mem_alu_result_reg == 32'd100)
            $display("PASS Test3: EX/MEM forward result=%0d",
                      ex_mem_alu_result_reg);
        else
            $display("FAIL Test3: EX/MEM forward got=%0d",
                      ex_mem_alu_result_reg);

        // --------------------------------------------------
        // Test 4: BEQ branch taken (rs1 == rs2)
        // --------------------------------------------------
        @(posedge clk); #1;
        id_ex_rs1_data = 32'd5;
        id_ex_rs2_data = 32'd5;
        id_ex_pc       = 32'h00000010;
        id_ex_imm      = 32'd8;      // branch offset
        id_ex_branch   = 1'b1;
        id_ex_funct3   = 3'b000;     // BEQ
        id_ex_alu_src  = 1'b0;
        id_ex_is_mul   = 1'b0;
        forward_a = 2'b00; forward_b = 2'b00;
        #2;
        if (branch_taken == 1'b1 && branch_target == 32'h00000018)
            $display("PASS Test4: BEQ taken, target=%h", branch_target);
        else
            $display("FAIL Test4: branch_taken=%b target=%h",
                      branch_taken, branch_target);

        // --------------------------------------------------
        // Test 5: BNE branch not taken (rs1 == rs2)
        // --------------------------------------------------
        @(posedge clk); #1;
        id_ex_rs1_data = 32'd5;
        id_ex_rs2_data = 32'd5;
        id_ex_branch   = 1'b1;
        id_ex_funct3   = 3'b001;     // BNE
        id_ex_is_mul   = 1'b0;
        forward_a = 2'b00; forward_b = 2'b00;
        #2;
        if (branch_taken == 1'b0)
            $display("PASS Test5: BNE not taken (rs1==rs2)");
        else
            $display("FAIL Test5: BNE should not be taken");

        // --------------------------------------------------
        // Test 6: MUL x3 = x1 * x2
        // rs1=6, rs2=7, expect 42
        // --------------------------------------------------
        @(posedge clk); #1;
        id_ex_rs1_data = 32'd6;
        id_ex_rs2_data = 32'd7;
        id_ex_alu_src  = 1'b0;
        id_ex_branch   = 1'b0;
        id_ex_funct3   = 3'b000;  // MUL (lower 32)
        id_ex_is_mul   = 1'b1;
        forward_a = 2'b00; forward_b = 2'b00;

        @(posedge clk); #1;
        if (ex_mem_alu_result_reg == 32'd42)
            $display("PASS Test6: MUL result=%0d", ex_mem_alu_result_reg);
        else
            $display("FAIL Test6: MUL got=%0d", ex_mem_alu_result_reg);

        $display("=== Testbench Complete ===");
        $finish;
    end

endmodule