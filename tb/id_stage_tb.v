// ============================================================
// ID Stage Testbench
// ============================================================
module id_stage_tb;

    reg         clk, rst;
    reg  [31:0] if_id_instr, if_id_pc;
    reg  [31:0] rs1_data, rs2_data;
    reg         stall_d, flush_d;

    wire [4:0]  rs1_addr, rs2_addr;
    wire [31:0] id_ex_pc, id_ex_rs1_data, id_ex_rs2_data;
    wire [4:0]  id_ex_rs1_addr, id_ex_rs2_addr, id_ex_rd_addr;
    wire [31:0] id_ex_imm;
    wire [3:0]  id_ex_alu_ctrl;
    wire        id_ex_alu_src, id_ex_reg_write;
    wire        id_ex_mem_read, id_ex_mem_write, id_ex_mem_to_reg;
    wire        id_ex_branch, id_ex_jump;
    wire [2:0]  id_ex_funct3;

    id_stage uut (
        .clk            (clk),
        .rst            (rst),
        .if_id_instr    (if_id_instr),
        .if_id_pc       (if_id_pc),
        .rs1_data       (rs1_data),
        .rs2_data       (rs2_data),
        .rs1_addr       (rs1_addr),
        .rs2_addr       (rs2_addr),
        .stall_d        (stall_d),
        .flush_d        (flush_d),
        .id_ex_pc       (id_ex_pc),
        .id_ex_rs1_data (id_ex_rs1_data),
        .id_ex_rs2_data (id_ex_rs2_data),
        .id_ex_rs1_addr (id_ex_rs1_addr),
        .id_ex_rs2_addr (id_ex_rs2_addr),
        .id_ex_rd_addr  (id_ex_rd_addr),
        .id_ex_imm      (id_ex_imm),
        .id_ex_alu_ctrl (id_ex_alu_ctrl),
        .id_ex_alu_src  (id_ex_alu_src),
        .id_ex_reg_write(id_ex_reg_write),
        .id_ex_mem_read (id_ex_mem_read),
        .id_ex_mem_write(id_ex_mem_write),
        .id_ex_mem_to_reg(id_ex_mem_to_reg),
        .id_ex_branch   (id_ex_branch),
        .id_ex_jump     (id_ex_jump),
        .id_ex_funct3   (id_ex_funct3)
    );

    always #5 clk = ~clk;

    initial begin
        $display("=== ID Stage Testbench ===");
        clk = 0; rst = 1;
        if_id_instr = 0; if_id_pc = 0;
        rs1_data = 0; rs2_data = 0;
        stall_d = 0; flush_d = 0;

        @(posedge clk); #1;
        @(posedge clk); #1;
        rst = 0;

        // --------------------------------------------------
        // Test 1: ADDI x1, x0, 5
        // opcode=0010011, rd=1, funct3=000, rs1=0, imm=5
        // Encoding: 000000000101 00000 000 00001 0010011
        // --------------------------------------------------
        @(posedge clk); #1;
        if_id_instr = 32'h00500093; // ADDI x1, x0, 5
        if_id_pc    = 32'h00000000;
        rs1_data    = 32'd0;
        rs2_data    = 32'd0;

        @(posedge clk); #1;
        $display("Test1 ADDI x1,x0,5:");
        $display("  rs1_addr=%0d rs2_addr=%0d rd=%0d",
                  rs1_addr, rs2_addr, id_ex_rd_addr);
        $display("  imm=%0d alu_ctrl=%b alu_src=%b",
                  id_ex_imm, id_ex_alu_ctrl, id_ex_alu_src);
        $display("  reg_write=%b mem_read=%b mem_write=%b",
                  id_ex_reg_write, id_ex_mem_read, id_ex_mem_write);
        if (id_ex_rd_addr==5'd1 && id_ex_imm==32'd5 &&
            id_ex_alu_ctrl==4'b0000 && id_ex_alu_src==1'b1 &&
            id_ex_reg_write==1'b1)
            $display("  PASS Test1");
        else
            $display("  FAIL Test1");

        // --------------------------------------------------
        // Test 2: ADD x3, x1, x2 (R-type)
        // opcode=0110011, funct3=000, funct7=0000000
        // --------------------------------------------------
        @(posedge clk); #1;
        if_id_instr = 32'h002081B3; // ADD x3, x1, x2
        if_id_pc    = 32'h00000004;
        rs1_data    = 32'd10;
        rs2_data    = 32'd20;

        @(posedge clk); #1;
        $display("Test2 ADD x3,x1,x2:");
        $display("  rs1_addr=%0d rs2_addr=%0d rd=%0d",
                  rs1_addr, rs2_addr, id_ex_rd_addr);
        $display("  alu_ctrl=%b alu_src=%b reg_write=%b",
                  id_ex_alu_ctrl, id_ex_alu_src, id_ex_reg_write);
        if (id_ex_rd_addr==5'd3 && id_ex_alu_ctrl==4'b0000 &&
            id_ex_alu_src==1'b0 && id_ex_reg_write==1'b1)
            $display("  PASS Test2");
        else
            $display("  FAIL Test2");

        // --------------------------------------------------
        // Test 3: LW x4, 8(x1) - load
        // opcode=0000011, funct3=010, imm=8
        // --------------------------------------------------
        @(posedge clk); #1;
        if_id_instr = 32'h00812203; // LW x4, 8(x1)
        rs1_data    = 32'd100;

        @(posedge clk); #1;
        $display("Test3 LW x4,8(x1):");
        $display("  imm=%0d mem_read=%b mem_to_reg=%b alu_src=%b",
                  id_ex_imm, id_ex_mem_read,
                  id_ex_mem_to_reg, id_ex_alu_src);
        if (id_ex_imm==32'd8 && id_ex_mem_read==1'b1 &&
            id_ex_mem_to_reg==1'b1 && id_ex_alu_src==1'b1 &&
            id_ex_reg_write==1'b1)
            $display("  PASS Test3");
        else
            $display("  FAIL Test3");

        // --------------------------------------------------
        // Test 4: SW x2, 4(x1) - store
        // opcode=0100011, funct3=010, imm=4
        // --------------------------------------------------
        @(posedge clk); #1;
        if_id_instr = 32'h0020A223; // SW x2, 4(x1)

        @(posedge clk); #1;
        $display("Test4 SW x2,4(x1):");
        $display("  imm=%0d mem_write=%b reg_write=%b",
                  id_ex_imm, id_ex_mem_write, id_ex_reg_write);
        if (id_ex_imm==32'd4 && id_ex_mem_write==1'b1 &&
            id_ex_reg_write==1'b0)
            $display("  PASS Test4");
        else
            $display("  FAIL Test4");

        // --------------------------------------------------
        // Test 5: BEQ x1, x2, offset=8
        // opcode=1100011, funct3=000
        // --------------------------------------------------
        @(posedge clk); #1;
        if_id_instr = 32'h00208463; // BEQ x1, x2, +8

        @(posedge clk); #1;
        $display("Test5 BEQ x1,x2,+8:");
        $display("  branch=%b imm=%0d reg_write=%b",
                  id_ex_branch, id_ex_imm, id_ex_reg_write);
        if (id_ex_branch==1'b1 && id_ex_imm==32'd8 &&
            id_ex_reg_write==1'b0)
            $display("  PASS Test5");
        else
            $display("  FAIL Test5");

        // --------------------------------------------------
        // Test 6: Flush - should produce NOP
        // --------------------------------------------------
        @(posedge clk); #1;
        if_id_instr = 32'h00500093; // ADDI again
        flush_d = 1;

        @(posedge clk); #1;
        flush_d = 0;
        $display("Test6 Flush:");
        if (id_ex_reg_write==1'b0 && id_ex_mem_read==1'b0 &&
            id_ex_mem_write==1'b0 && id_ex_branch==1'b0)
            $display("  PASS Test6: NOP inserted");
        else
            $display("  FAIL Test6: control signals not zeroed");

        $display("=== Testbench Complete ===");
        $finish;
    end

endmodule