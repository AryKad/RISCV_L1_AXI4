// ============================================================
// ALU Testbench - self checking
// ============================================================
module alu_tb;

    reg  [3:0]  alu_ctrl;
    reg  [31:0] operand_a;
    reg  [31:0] operand_b;
    wire [31:0] result;
    wire        zero;

    // Instantiate ALU
    alu uut (
        .alu_ctrl  (alu_ctrl),
        .operand_a (operand_a),
        .operand_b (operand_b),
        .result    (result),
        .zero      (zero)
    );

    // Task for self-checking
    task check;
        input [31:0] expected;
        input [63:0] test_name; // just for display
        begin
            #10;
            if (result !== expected) begin
                $display("FAIL %s: got %h, expected %h",
                          test_name, result, expected);
            end else begin
                $display("PASS %s: result = %h", test_name, result);
            end
        end
    endtask

    initial begin
        $display("=== ALU Testbench ===");

        // ADD: 5 + 3 = 8
        alu_ctrl = 4'b0000; operand_a = 32'd5; operand_b = 32'd3;
        #10; if (result !== 32'd8) $display("FAIL ADD"); else $display("PASS ADD");

        // SUB: 10 - 4 = 6
        alu_ctrl = 4'b0001; operand_a = 32'd10; operand_b = 32'd4;
        #10; if (result !== 32'd6) $display("FAIL SUB"); else $display("PASS SUB");

        // AND: 0xFF & 0x0F = 0x0F
        alu_ctrl = 4'b0010; operand_a = 32'hFF; operand_b = 32'h0F;
        #10; if (result !== 32'h0F) $display("FAIL AND"); else $display("PASS AND");

        // OR: 0xF0 | 0x0F = 0xFF
        alu_ctrl = 4'b0011; operand_a = 32'hF0; operand_b = 32'h0F;
        #10; if (result !== 32'hFF) $display("FAIL OR"); else $display("PASS OR");

        // XOR: 0xFF ^ 0xFF = 0
        alu_ctrl = 4'b0100; operand_a = 32'hFF; operand_b = 32'hFF;
        #10; if (result !== 32'd0) $display("FAIL XOR"); else $display("PASS XOR");

        // SLL: 1 << 4 = 16
        alu_ctrl = 4'b0101; operand_a = 32'd1; operand_b = 32'd4;
        #10; if (result !== 32'd16) $display("FAIL SLL"); else $display("PASS SLL");

        // SRL: 16 >> 2 = 4
        alu_ctrl = 4'b0110; operand_a = 32'd16; operand_b = 32'd2;
        #10; if (result !== 32'd4) $display("FAIL SRL"); else $display("PASS SRL");

        // SRA: -8 >>> 1 = -4 (arithmetic, preserves sign)
        alu_ctrl = 4'b0111; operand_a = 32'hFFFFFFF8; operand_b = 32'd1;
        #10; if (result !== 32'hFFFFFFFC) $display("FAIL SRA"); else $display("PASS SRA");

        // SLT: -1 < 1 → 1 (signed)
        alu_ctrl = 4'b1000; operand_a = 32'hFFFFFFFF; operand_b = 32'd1;
        #10; if (result !== 32'd1) $display("FAIL SLT"); else $display("PASS SLT");

        // SLTU: 0xFFFFFFFF > 1 unsigned → 0
        alu_ctrl = 4'b1001; operand_a = 32'hFFFFFFFF; operand_b = 32'd1;
        #10; if (result !== 32'd0) $display("FAIL SLTU"); else $display("PASS SLTU");

        // Zero flag: 5 - 5 = 0, zero should be 1
        alu_ctrl = 4'b0001; operand_a = 32'd5; operand_b = 32'd5;
        #10; if (zero !== 1'b1) $display("FAIL ZERO FLAG"); else $display("PASS ZERO FLAG");

        $display("=== Testbench Complete ===");
        $finish;
    end

endmodule