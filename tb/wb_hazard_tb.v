// ============================================================
// WB Stage + Hazard Unit Testbench
// ============================================================
module wb_hazard_tb;

    // ---- WB Stage signals ----
    reg  [31:0] mem_wb_alu_result;
    reg  [31:0] mem_wb_read_data;
    reg  [4:0]  mem_wb_rd_addr;
    reg         mem_wb_reg_write;
    reg         mem_wb_mem_to_reg;

    wire [31:0] wb_data;
    wire [4:0]  wb_rd_addr;
    wire        wb_reg_write;

    wb_stage wb_uut (
        .mem_wb_alu_result (mem_wb_alu_result),
        .mem_wb_read_data  (mem_wb_read_data),
        .mem_wb_rd_addr    (mem_wb_rd_addr),
        .mem_wb_reg_write  (mem_wb_reg_write),
        .mem_wb_mem_to_reg (mem_wb_mem_to_reg),
        .wb_data           (wb_data),
        .wb_rd_addr        (wb_rd_addr),
        .wb_reg_write      (wb_reg_write)
    );

    // ---- Hazard Unit signals ----
    reg        id_ex_mem_read;
    reg  [4:0] id_ex_rd_addr;
    reg  [4:0] if_id_rs1, if_id_rs2;
    reg        branch_taken, jump;

    wire       stall_f, stall_d, flush_d, flush_f;

    hazard_unit haz_uut (
        .id_ex_mem_read (id_ex_mem_read),
        .id_ex_rd_addr  (id_ex_rd_addr),
        .if_id_rs1      (if_id_rs1),
        .if_id_rs2      (if_id_rs2),
        .branch_taken   (branch_taken),
        .jump           (jump),
        .stall_f        (stall_f),
        .stall_d        (stall_d),
        .flush_d        (flush_d),
        .flush_f        (flush_f)
    );

    initial begin
        $display("=== WB + Hazard Unit Testbench ===");

        // --------------------------------------------------
        // WB Test 1: ALU result passthrough (mem_to_reg=0)
        // --------------------------------------------------
        mem_wb_alu_result = 32'hDEADBEEF;
        mem_wb_read_data  = 32'h12345678;
        mem_wb_rd_addr    = 5'd5;
        mem_wb_reg_write  = 1'b1;
        mem_wb_mem_to_reg = 1'b0;
        #5;
        if (wb_data == 32'hDEADBEEF && wb_reg_write == 1'b1)
            $display("PASS WB Test1: ALU result = %h", wb_data);
        else
            $display("FAIL WB Test1: got %h", wb_data);

        // --------------------------------------------------
        // WB Test 2: Memory data selected (mem_to_reg=1)
        // --------------------------------------------------
        mem_wb_mem_to_reg = 1'b1;
        #5;
        if (wb_data == 32'h12345678)
            $display("PASS WB Test2: mem data = %h", wb_data);
        else
            $display("FAIL WB Test2: got %h", wb_data);

        // --------------------------------------------------
        // WB Test 3: reg_write=0 - no write
        // --------------------------------------------------
        mem_wb_reg_write  = 1'b0;
        mem_wb_mem_to_reg = 1'b0;
        #5;
        if (wb_reg_write == 1'b0)
            $display("PASS WB Test3: reg_write=0 correctly");
        else
            $display("FAIL WB Test3: reg_write should be 0");

        // --------------------------------------------------
        // Hazard Test 1: Load-use hazard detected
        // LW x1 in EX, ADD x3,x1,x2 in ID
        // --------------------------------------------------
        id_ex_mem_read = 1'b1;  // EX is a load
        id_ex_rd_addr  = 5'd1;  // loading into x1
        if_id_rs1      = 5'd1;  // ID reads x1
        if_id_rs2      = 5'd2;
        branch_taken   = 1'b0;
        jump           = 1'b0;
        #5;
        if (stall_f==1'b1 && stall_d==1'b1 && flush_d==1'b1)
            $display("PASS Hazard Test1: load-use stall detected");
        else
            $display("FAIL Hazard Test1: stall_f=%b stall_d=%b flush_d=%b",
                      stall_f, stall_d, flush_d);

        // --------------------------------------------------
        // Hazard Test 2: No hazard - different registers
        // LW x1 in EX, ADD x3,x4,x5 in ID (doesn't use x1)
        // --------------------------------------------------
        id_ex_rd_addr = 5'd1;
        if_id_rs1     = 5'd4;
        if_id_rs2     = 5'd5;
        #5;
        if (stall_f==1'b0 && stall_d==1'b0)
            $display("PASS Hazard Test2: no stall (different registers)");
        else
            $display("FAIL Hazard Test2: false stall detected");

        // --------------------------------------------------
        // Hazard Test 3: x0 never causes hazard
        // LW x0 in EX - writes to x0 which is hardwired 0
        // --------------------------------------------------
        id_ex_rd_addr = 5'd0;
        if_id_rs1     = 5'd0;
        if_id_rs2     = 5'd0;
        #5;
        if (stall_f==1'b0)
            $display("PASS Hazard Test3: x0 never causes stall");
        else
            $display("FAIL Hazard Test3: x0 should not cause stall");

        // --------------------------------------------------
        // Hazard Test 4: Branch taken - flush IF and ID
        // --------------------------------------------------
        id_ex_mem_read = 1'b0;
        id_ex_rd_addr  = 5'd0;
        if_id_rs1      = 5'd1;
        if_id_rs2      = 5'd2;
        branch_taken   = 1'b1;
        jump           = 1'b0;
        #5;
        if (flush_f==1'b1 && flush_d==1'b1 && stall_f==1'b0)
            $display("PASS Hazard Test4: branch flush correct");
        else
            $display("FAIL Hazard Test4: flush_f=%b flush_d=%b stall_f=%b",
                      flush_f, flush_d, stall_f);

        // --------------------------------------------------
        // Hazard Test 5: No hazard - not a load instruction
        // --------------------------------------------------
        id_ex_mem_read = 1'b0; // not a load
        id_ex_rd_addr  = 5'd1;
        if_id_rs1      = 5'd1; // same register but not load
        branch_taken   = 1'b0;
        jump           = 1'b0;
        #5;
        if (stall_f==1'b0 && flush_d==1'b0)
            $display("PASS Hazard Test5: no stall for non-load");
        else
            $display("FAIL Hazard Test5: false stall on non-load");

        $display("=== Testbench Complete ===");
        $finish;
    end

endmodule