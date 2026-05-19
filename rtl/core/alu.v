// ============================================================
// ALU - Arithmetic Logic Unit
// RISC-V SoC Project | Nexys A7 100T
// ============================================================
// Purely combinational - no clock, no state.
// Performs all arithmetic and logic operations for RV32I.
//
// Inputs:
//   alu_ctrl  [3:0] - selects operation (defined below)
//   operand_a [31:0] - first operand (always from RS1)
//   operand_b [31:0] - second operand (RS2 or immediate)
//
// Outputs:
//   result    [31:0] - computation result
//   zero             - 1 if result == 0 (used for branches)
// ============================================================

module alu (
    input  wire [3:0]  alu_ctrl,    // Operation select
    input  wire [31:0] operand_a,   // RS1 value
    input  wire [31:0] operand_b,   // RS2 or immediate
    output reg  [31:0] result,      // Computation result
    output wire        zero         // 1 if result == 0
);

    // ----------------------------------------------------------
    // ALU control encoding
    // ----------------------------------------------------------
    localparam ALU_ADD  = 4'b0000;  // Addition
    localparam ALU_SUB  = 4'b0001;  // Subtraction
    localparam ALU_AND  = 4'b0010;  // Bitwise AND
    localparam ALU_OR   = 4'b0011;  // Bitwise OR
    localparam ALU_XOR  = 4'b0100;  // Bitwise XOR
    localparam ALU_SLL  = 4'b0101;  // Shift left logical
    localparam ALU_SRL  = 4'b0110;  // Shift right logical
    localparam ALU_SRA  = 4'b0111;  // Shift right arithmetic
    localparam ALU_SLT  = 4'b1000;  // Set less than (signed)
    localparam ALU_SLTU = 4'b1001;  // Set less than (unsigned)

    // ----------------------------------------------------------
    // Shift amount - only lower 5 bits of operand_b are used
    // RV32I spec: shift amount is always rs2[4:0] or shamt[4:0]
    // ----------------------------------------------------------
    wire [4:0] shamt = operand_b[4:0];

    // ----------------------------------------------------------
    // Signed interpretations for SLT
    // Verilog treats everything as unsigned by default.
    // We need explicit signed casting for signed comparison.
    // ----------------------------------------------------------
    wire signed [31:0] signed_a = operand_a;
    wire signed [31:0] signed_b = operand_b;

    // ----------------------------------------------------------
    // ALU operation select
    // ----------------------------------------------------------
    always @(*) begin
        case (alu_ctrl)
            ALU_ADD  : result = operand_a + operand_b;
            ALU_SUB  : result = operand_a - operand_b;
            ALU_AND  : result = operand_a & operand_b;
            ALU_OR   : result = operand_a | operand_b;
            ALU_XOR  : result = operand_a ^ operand_b;
            ALU_SLL  : result = operand_a << shamt;
            ALU_SRL  : result = operand_a >> shamt;
            // >>> is arithmetic right shift in Verilog
            // only works correctly on signed types
            ALU_SRA  : result = signed_a >>> shamt;
            // SLT: 1 if signed_a < signed_b, else 0
            ALU_SLT  : result = (signed_a < signed_b) ? 32'd1 : 32'd0;
            // SLTU: same but unsigned comparison
            ALU_SLTU : result = (operand_a < operand_b) ? 32'd1 : 32'd0;
            // Safety default - should never hit in correct operation
            default  : result = 32'd0;
        endcase
    end

    // ----------------------------------------------------------
    // Zero flag - used by branch instructions
    // BEQ: branch if (A - B) == 0 → zero == 1
    // BNE: branch if (A - B) != 0 → zero == 0
    // ----------------------------------------------------------
    assign zero = (result == 32'd0);

endmodule