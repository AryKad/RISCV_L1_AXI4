// ============================================================
// EX Stage - Execute
// RISC-V SoC Project | Nexys A7 100T
// ============================================================
// Performs:
//   - Operand selection via forwarding muxes
//   - ALU operation
//   - MUL operation (M-extension, DSP48E1 inferred)
//   - Branch target and decision
//   - Jump target
//   - EX/MEM pipeline register
// ============================================================

module ex_stage (
    input  wire        clk,
    input  wire        rst,

    // From ID/EX pipeline register
    input  wire [31:0] id_ex_pc,
    input  wire [31:0] id_ex_rs1_data,
    input  wire [31:0] id_ex_rs2_data,
    input  wire [4:0]  id_ex_rs1_addr,
    input  wire [4:0]  id_ex_rs2_addr,
    input  wire [4:0]  id_ex_rd_addr,
    input  wire [31:0] id_ex_imm,
    input  wire [3:0]  id_ex_alu_ctrl,
    input  wire        id_ex_alu_src,
    input  wire        id_ex_reg_write,
    input  wire        id_ex_mem_read,
    input  wire        id_ex_mem_write,
    input  wire        id_ex_mem_to_reg,
    input  wire        id_ex_branch,
    input  wire        id_ex_jump,
    input  wire [2:0]  id_ex_funct3,
    // funct7 bit 1 distinguishes MUL from R-type
    input  wire        id_ex_is_mul,

    // Forwarding inputs
    input  wire [1:0]  forward_a,
    input  wire [1:0]  forward_b,

    // Forward data sources
    input  wire [31:0] ex_mem_alu_result, // from EX/MEM (1 cycle ago)
    input  wire [31:0] wb_result,         // from MEM/WB (2 cycles ago)

    // Branch/jump outputs back to IF stage
    output wire        branch_taken,
    output wire        jump,
    output wire [31:0] branch_target,
    output wire [31:0] jump_target,

    // EX/MEM pipeline register outputs
    output reg  [31:0] ex_mem_alu_result_reg,
    output reg  [31:0] ex_mem_rs2_data,
    output reg  [4:0]  ex_mem_rd_addr,
    output reg         ex_mem_reg_write,
    output reg         ex_mem_mem_read,
    output reg         ex_mem_mem_write,
    output reg         ex_mem_mem_to_reg,
    output reg  [2:0]  ex_mem_funct3
);

    // ----------------------------------------------------------
    // Forwarding muxes - select correct operand A and B
    // ----------------------------------------------------------
    reg [31:0] operand_a_raw; // rs1 after forwarding
    reg [31:0] operand_b_raw; // rs2 after forwarding

    always @(*) begin
        case (forward_a)
            2'b00:   operand_a_raw = id_ex_rs1_data;     // no forward
            2'b01:   operand_a_raw = wb_result;           // from MEM/WB
            2'b10:   operand_a_raw = ex_mem_alu_result;   // from EX/MEM
            default: operand_a_raw = id_ex_rs1_data;
        endcase

        case (forward_b)
            2'b00:   operand_b_raw = id_ex_rs2_data;     // no forward
            2'b01:   operand_b_raw = wb_result;           // from MEM/WB
            2'b10:   operand_b_raw = ex_mem_alu_result;   // from EX/MEM
            default: operand_b_raw = id_ex_rs2_data;
        endcase
    end

    // ----------------------------------------------------------
    // ALU source mux
    // alu_src=1: use immediate (I-type, loads, stores)
    // alu_src=0: use forwarded rs2 (R-type, branches)
    // ----------------------------------------------------------
    wire [31:0] operand_b_alu = id_ex_alu_src ? id_ex_imm : operand_b_raw;

    // ----------------------------------------------------------
    // ALU instance
    // ----------------------------------------------------------
    wire [31:0] alu_result;
    wire        alu_zero;

    alu alu_inst (
        .alu_ctrl  (id_ex_alu_ctrl),
        .operand_a (operand_a_raw),
        .operand_b (operand_b_alu),
        .result    (alu_result),
        .zero      (alu_zero)
    );

    // ----------------------------------------------------------
    // MUL unit (M-extension)
    // Vivado infers DSP48E1 automatically from * operator
    // Only lower 32 bits for MUL, upper 32 for MULH variants
    // funct3 distinguishes MUL/MULH/MULHU/MULHSU
    // ----------------------------------------------------------
    wire signed [31:0] signed_a = operand_a_raw;
    wire signed [31:0] signed_b = operand_b_raw;
    wire        [63:0] mul_result_full = 
                       {32'd0, operand_a_raw} * {32'd0, operand_b_raw};
    wire signed [63:0] mul_result_signed = signed_a * signed_b;

    // Intermediate wires for MUL results
    wire [63:0] mulhsu_result = $signed({{32{operand_a_raw[31]}}, 
                                operand_a_raw}) * 
                                {32'd0, operand_b_raw};

    reg [31:0] mul_result;
    always @(*) begin
        case (id_ex_funct3)
            3'b000: mul_result = mul_result_full[31:0];    // MUL
            3'b001: mul_result = mul_result_signed[63:32]; // MULH
            3'b011: mul_result = mul_result_full[63:32];   // MULHU
            3'b010: mul_result = mulhsu_result[63:32];     // MULHSU
            default: mul_result = 32'd0;
        endcase
    end

    // ----------------------------------------------------------
    // Result mux: ALU or MUL
    // ----------------------------------------------------------
    wire [31:0] ex_result = id_ex_is_mul ? mul_result : alu_result;

    // ----------------------------------------------------------
    // Branch target = PC + imm (B-type immediate already has bit0=0)
    // ----------------------------------------------------------
    assign branch_target = id_ex_pc + id_ex_imm;

    // ----------------------------------------------------------
    // Branch decision - based on funct3 and ALU flags
    // ALU performs SUB (rs1 - rs2) for all branches
    // ----------------------------------------------------------
    wire signed [31:0] signed_alu_a = operand_a_raw;
    wire signed [31:0] signed_alu_b = operand_b_raw;

    reg branch_taken_reg;
    always @(*) begin
        branch_taken_reg = 1'b0;
        if (id_ex_branch) begin
            case (id_ex_funct3)
                3'b000: branch_taken_reg = (operand_a_raw == operand_b_raw); // BEQ
                3'b001: branch_taken_reg = (operand_a_raw != operand_b_raw); // BNE
                3'b100: branch_taken_reg = (signed_alu_a < signed_alu_b);   // BLT
                3'b101: branch_taken_reg = (signed_alu_a >= signed_alu_b);  // BGE
                3'b110: branch_taken_reg = (operand_a_raw < operand_b_raw); // BLTU
                3'b111: branch_taken_reg = (operand_a_raw >= operand_b_raw);// BGEU
                default: branch_taken_reg = 1'b0;
            endcase
        end
    end

    assign branch_taken = branch_taken_reg;

    // ----------------------------------------------------------
    // Jump target
    // JAL:  target = PC + imm  (same as branch_target)
    // JALR: target = rs1 + imm (ALU computes this when alu_src=1)
    // For JAL: alu_src=0, we use branch_target
    // For JALR: alu_src=1, ALU result IS the target
    // ----------------------------------------------------------
    // Distinguish JAL vs JALR by opcode - but opcode not passed through.
    // We use alu_src: JAL has alu_src=0, JALR has alu_src=1
    // JAL target = PC + imm, JALR target = rs1 + imm (= alu_result)
    assign jump_target = id_ex_alu_src ? alu_result : branch_target;
    assign jump        = id_ex_jump;

    // ----------------------------------------------------------
    // EX/MEM pipeline register
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            ex_mem_alu_result_reg <= 32'd0;
            ex_mem_rs2_data       <= 32'd0;
            ex_mem_rd_addr        <= 5'd0;
            ex_mem_reg_write      <= 1'b0;
            ex_mem_mem_read       <= 1'b0;
            ex_mem_mem_write      <= 1'b0;
            ex_mem_mem_to_reg     <= 1'b0;
            ex_mem_funct3         <= 3'd0;
        end else begin
            ex_mem_alu_result_reg <= ex_result;
            ex_mem_rs2_data       <= operand_b_raw; // for stores
            ex_mem_rd_addr        <= id_ex_rd_addr;
            ex_mem_reg_write      <= id_ex_reg_write;
            ex_mem_mem_read       <= id_ex_mem_read;
            ex_mem_mem_write      <= id_ex_mem_write;
            ex_mem_mem_to_reg     <= id_ex_mem_to_reg;
            ex_mem_funct3         <= id_ex_funct3;
        end
    end

endmodule