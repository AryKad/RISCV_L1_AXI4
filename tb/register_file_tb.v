module register_file_tb;
    reg        clk, rst;
    reg  [4:0] rs1_addr, rs2_addr, rd_addr;
    reg [31:0] rd_data;
    reg        rd_we;
    wire[31:0] rs1_data, rs2_data;

    register_file uut (
        .clk(clk), .rst(rst),
        .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
        .rd_addr(rd_addr), .rd_data(rd_data), .rd_we(rd_we),
        .rs1_data(rs1_data), .rs2_data(rs2_data)
    );

    always #5 clk = ~clk;

    // Helper task - wait for posedge then apply stimulus
    // The #1 pushes stimulus AFTER the clock edge
    task apply_write;
        input [4:0]  addr;
        input [31:0] data;
        begin
            @(posedge clk); #1;
            rd_addr = addr; rd_data = data; rd_we = 1;
            @(posedge clk); #1;  // this posedge captures the write
            rd_we = 0; rd_addr = 0; rd_data = 0;
        end
    endtask

    initial begin
        $display("=== Register File Testbench ===");
        clk = 0; rst = 1; rd_we = 0;
        rs1_addr = 0; rs2_addr = 0;
        rd_addr = 0; rd_data = 0;

        @(posedge clk); #1;
        @(posedge clk); #1;
        rst = 0;

        // Test 1: Write x1 = 0xDEADBEEF, read back
        apply_write(5'd1, 32'hDEADBEEF);
        rs1_addr = 5'd1;
        #2;
        if (rs1_data !== 32'hDEADBEEF)
            $display("FAIL Test1: got %h", rs1_data);
        else
            $display("PASS Test1: x1 = %h", rs1_data);

        // Test 2: Write x0 = 0xFFFFFFFF, should stay 0
        apply_write(5'd0, 32'hFFFFFFFF);
        rs1_addr = 5'd0;
        #2;
        if (rs1_data !== 32'd0)
            $display("FAIL Test2: got %h", rs1_data);
        else
            $display("PASS Test2: x0 = 0 (write ignored)");

        // Test 3: Write x2 = 0xCAFEBABE, dual read x2 and x1
        apply_write(5'd2, 32'hCAFEBABE);
        rs1_addr = 5'd2;
        rs2_addr = 5'd1;
        #2;
        if (rs1_data !== 32'hCAFEBABE || rs2_data !== 32'hDEADBEEF)
            $display("FAIL Test3: rs1=%h rs2=%h", rs1_data, rs2_data);
        else
            $display("PASS Test3: dual read rs1=%h rs2=%h", rs1_data, rs2_data);

        // Test 4: Write-first forwarding
        // Set rs1_addr and rd_addr to same register simultaneously
        // rs1_data should immediately show new value via forwarding
        @(posedge clk); #1;
        rs1_addr = 5'd3;
        rd_addr  = 5'd3; rd_data = 32'h12345678; rd_we = 1;
        #2;
        if (rs1_data !== 32'h12345678)
            $display("FAIL Test4: got %h", rs1_data);
        else
            $display("PASS Test4: write-first forwarding = %h", rs1_data);
        @(posedge clk); #1;
        rd_we = 0;

        $display("=== Testbench Complete ===");
        $finish;
    end
endmodule