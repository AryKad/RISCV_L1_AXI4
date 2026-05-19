// ============================================================
// MEM Stage Testbench
// ============================================================
module mem_stage_tb;

    reg         clk, rst;
    reg  [31:0] ex_mem_alu_result;
    reg  [31:0] ex_mem_rs2_data;
    reg  [4:0]  ex_mem_rd_addr;
    reg         ex_mem_reg_write;
    reg         ex_mem_mem_read;
    reg         ex_mem_mem_write;
    reg         ex_mem_mem_to_reg;
    reg  [2:0]  ex_mem_funct3;

    wire [31:0] mem_wb_alu_result;
    wire [31:0] mem_wb_read_data;
    wire [4:0]  mem_wb_rd_addr;
    wire        mem_wb_reg_write;
    wire        mem_wb_mem_to_reg;

    mem_stage uut (
        .clk              (clk),
        .rst              (rst),
        .ex_mem_alu_result(ex_mem_alu_result),
        .ex_mem_rs2_data  (ex_mem_rs2_data),
        .ex_mem_rd_addr   (ex_mem_rd_addr),
        .ex_mem_reg_write (ex_mem_reg_write),
        .ex_mem_mem_read  (ex_mem_mem_read),
        .ex_mem_mem_write (ex_mem_mem_write),
        .ex_mem_mem_to_reg(ex_mem_mem_to_reg),
        .ex_mem_funct3    (ex_mem_funct3),
        .mem_wb_alu_result(mem_wb_alu_result),
        .mem_wb_read_data (mem_wb_read_data),
        .mem_wb_rd_addr   (mem_wb_rd_addr),
        .mem_wb_reg_write (mem_wb_reg_write),
        .mem_wb_mem_to_reg(mem_wb_mem_to_reg)
    );

    always #5 clk = ~clk;

    initial begin
        $display("=== MEM Stage Testbench ===");
        clk = 0; rst = 1;
        ex_mem_alu_result = 0; ex_mem_rs2_data = 0;
        ex_mem_rd_addr = 0; ex_mem_reg_write = 0;
        ex_mem_mem_read = 0; ex_mem_mem_write = 0;
        ex_mem_mem_to_reg = 0; ex_mem_funct3 = 0;

        @(posedge clk); #1;
        @(posedge clk); #1;
        rst = 0;

        // --------------------------------------------------
        // Test 1: SW - store word 0xDEADBEEF to address 0
        // Then LW - load it back
        // --------------------------------------------------
        // SW
        @(posedge clk); #1;
        ex_mem_alu_result  = 32'h00000000; // address 0
        ex_mem_rs2_data    = 32'hDEADBEEF;
        ex_mem_mem_write   = 1'b1;
        ex_mem_mem_read    = 1'b0;
        ex_mem_funct3      = 3'b010;       // SW
        ex_mem_reg_write   = 1'b0;
        ex_mem_mem_to_reg  = 1'b0;

        @(posedge clk); #1;
        ex_mem_mem_write = 1'b0;

        // LW from address 0
        @(posedge clk); #1;
        ex_mem_alu_result  = 32'h00000000;
        ex_mem_mem_read    = 1'b1;
        ex_mem_funct3      = 3'b010;       // LW
        ex_mem_rd_addr     = 5'd1;
        ex_mem_reg_write   = 1'b1;
        ex_mem_mem_to_reg  = 1'b1;

        @(posedge clk); #1;
        ex_mem_mem_read = 1'b0;

        // result appears in MEM/WB after one more cycle
        @(posedge clk); #1;
        if (mem_wb_read_data == 32'hDEADBEEF)
            $display("PASS Test1: LW got %h", mem_wb_read_data);
        else
            $display("FAIL Test1: LW got %h", mem_wb_read_data);

        // --------------------------------------------------
        // Test 2: SB then LB - store byte 0xFF, load sign extended
        // --------------------------------------------------
        @(posedge clk); #1;
        ex_mem_alu_result  = 32'h00000004; // address 4
        ex_mem_rs2_data    = 32'h000000FF; // byte = 0xFF
        ex_mem_mem_write   = 1'b1;
        ex_mem_mem_read    = 1'b0;
        ex_mem_funct3      = 3'b000;       // SB
        ex_mem_reg_write   = 1'b0;

        @(posedge clk); #1;
        ex_mem_mem_write = 1'b0;

        // LB from address 4 - expect 0xFFFFFFFF (-1)
        @(posedge clk); #1;
        ex_mem_alu_result  = 32'h00000004;
        ex_mem_mem_read    = 1'b1;
        ex_mem_funct3      = 3'b000;       // LB
        ex_mem_rd_addr     = 5'd2;
        ex_mem_reg_write   = 1'b1;
        ex_mem_mem_to_reg  = 1'b1;

        @(posedge clk); #1;
        ex_mem_mem_read = 1'b0;

        @(posedge clk); #1;
        if (mem_wb_read_data == 32'hFFFFFFFF)
            $display("PASS Test2: LB sign extended = %h", mem_wb_read_data);
        else
            $display("FAIL Test2: LB got %h", mem_wb_read_data);

        // --------------------------------------------------
        // Test 3: LBU - load byte zero extended
        // Same address 4, byte = 0xFF, expect 0x000000FF
        // --------------------------------------------------
        @(posedge clk); #1;
        ex_mem_alu_result  = 32'h00000004;
        ex_mem_mem_read    = 1'b1;
        ex_mem_funct3      = 3'b100;       // LBU
        ex_mem_rd_addr     = 5'd3;
        ex_mem_reg_write   = 1'b1;
        ex_mem_mem_to_reg  = 1'b1;

        @(posedge clk); #1;
        ex_mem_mem_read = 1'b0;

        @(posedge clk); #1;
        if (mem_wb_read_data == 32'h000000FF)
            $display("PASS Test3: LBU zero extended = %h", mem_wb_read_data);
        else
            $display("FAIL Test3: LBU got %h", mem_wb_read_data);

        // --------------------------------------------------
        // Test 4: Non-memory instruction - ALU result passes through
        // --------------------------------------------------
        @(posedge clk); #1;
        ex_mem_alu_result  = 32'hCAFEBABE;
        ex_mem_mem_read    = 1'b0;
        ex_mem_mem_write   = 1'b0;
        ex_mem_mem_to_reg  = 1'b0;
        ex_mem_reg_write   = 1'b1;
        ex_mem_rd_addr     = 5'd4;

        @(posedge clk); #1;
        if (mem_wb_alu_result == 32'hCAFEBABE &&
            mem_wb_mem_to_reg == 1'b0)
            $display("PASS Test4: ALU passthrough = %h", mem_wb_alu_result);
        else
            $display("FAIL Test4: got %h", mem_wb_alu_result);

        $display("=== Testbench Complete ===");
        $finish;
    end

endmodule