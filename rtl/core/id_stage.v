// ============================================================
// ID Stage - Instruction Decode
// RISC-V SoC Project | Nexys A7 100T
// ============================================================
// Decodes the 32-bit instruction from IF/ID pipeline register.
// Produces:
//   - Register read addresses (rs1, rs2)
//   - Sign-extended immediate
//   - ALU control signal
//   - Pipeline control signals
//   - ID/EX pipeline register outputs
// ============================================================

module id_stage (
    input  wire        clk,
    input  wire        rst,

    // From IF/ID pipeline register
    input  wire [31:0] if_id_instr,   // Raw instruction
    input  wire [31:0] if_id_pc,      // PC of this instruction

    // From register file (combinational read)
    input  wire [31:0] rs1_data,      // RS1 value
    input  wire [31:0] rs2_data,      // RS2 value

    // To register file - read addresses
    output wire [4:0]  rs1_addr,      // RS1 address
    output wire [4:0]  rs2_addr,      // RS2 address

    // Hazard/flush control
    input  wire        stall_d,       // 1 = freeze ID/EX register
    input  wire        flush_d,       // 1 = insert NOP into ID/EX

    // ID/EX pipeline register outputs
    output reg  [31:0] id_ex_pc,
    output reg  [31:0] id_ex_rs1_data,
    output reg  [31:0] id_ex_rs2_data,
    output reg  [4:0]  id_ex_rs1_addr,  // needed by forwarding unit
    output reg  [4:0]  id_ex_rs2_addr,  // needed by forwarding unit
    output reg  [4:0]  id_ex_rd_addr,
    output reg  [31:0] id_ex_imm,
    output reg  [3:0]  id_ex_alu_ctrl,
    output reg         id_ex_alu_src,   // 0=rs2, 1=immediate
    output reg         id_ex_reg_write,
    output reg         id_ex_mem_read,
    output reg         id_ex_mem_write,
    output reg         id_ex_mem_to_reg,
    output reg         id_ex_branch,
    output reg         id_ex_jump,
    output reg  [2:0]  id_ex_funct3,    // needed for branch type and mem width
    output reg id_ex_is_mul  // 1 if M-extension multiply instruction
);

    // ----------------------------------------------------------
    // Instruction field extraction
    // These bit positions are fixed across all RV32I formats
    // ----------------------------------------------------------
    wire [6:0] opcode = if_id_instr[6:0];
    wire [4:0] rd     = if_id_instr[11:7];
    wire [2:0] funct3 = if_id_instr[14:12];
    wire [4:0] rs1    = if_id_instr[19:15];
    wire [4:0] rs2    = if_id_instr[24:20];
    wire [6:0] funct7 = if_id_instr[31:25];

    // Register file read addresses - combinational, no clock
    assign rs1_addr = rs1;
    assign rs2_addr = rs2;

    // ----------------------------------------------------------
    // Immediate generator
    // Reconstructs and sign-extends immediate from scattered bits
    // ----------------------------------------------------------
    reg [31:0] imm;

    always @(*) begin
        case (opcode)
            // I-type: ADDI, ANDI, ORI, XORI, SLTI, SLTIU, loads, JALR
            7'b0010011,
            7'b0000011,
            7'b1100111: imm = { {20{if_id_instr[31]}},
                                 if_id_instr[31:20] };

            // S-type: SB, SH, SW
            7'b0100011: imm = { {20{if_id_instr[31]}},
                                 if_id_instr[31:25],
                                 if_id_instr[11:7] };

            // B-type: BEQ, BNE, BLT, BGE, BLTU, BGEU
            7'b1100011: imm = { {19{if_id_instr[31]}},
                                 if_id_instr[31],
                                 if_id_instr[7],
                                 if_id_instr[30:25],
                                 if_id_instr[11:8],
                                 1'b0 };

            // U-type: LUI, AUIPC
            7'b0110111,
            7'b0010111: imm = { if_id_instr[31:12], 12'd0 };

            // J-type: JAL
            7'b1101111: imm = { {11{if_id_instr[31]}},
                                 if_id_instr[31],
                                 if_id_instr[19:12],
                                 if_id_instr[20],
                                 if_id_instr[30:21],
                                 1'b0 };

            default:    imm = 32'd0;
        endcase
    end

    // ----------------------------------------------------------
    // ALU control decoder
    // Combines opcode, funct3, funct7 to produce 4-bit alu_ctrl
    // Matches encoding defined in alu.v
    // ----------------------------------------------------------
    // ALU control encoding (from alu.v):
    // 0000=ADD, 0001=SUB, 0010=AND, 0011=OR, 0100=XOR
    // 0101=SLL, 0110=SRL, 0111=SRA, 1000=SLT, 1001=SLTU
    // ----------------------------------------------------------
    reg [3:0] alu_ctrl;

    always @(*) begin
        case (opcode)
            // R-type - funct7 differentiates SUB from ADD, SRA from SRL
            7'b0110011: begin
                case (funct3)
                    3'b000: alu_ctrl = (funct7[5]) ? 4'b0001 : 4'b0000; // SUB:ADD
                    3'b001: alu_ctrl = 4'b0101; // SLL
                    3'b010: alu_ctrl = 4'b1000; // SLT
                    3'b011: alu_ctrl = 4'b1001; // SLTU
                    3'b100: alu_ctrl = 4'b0100; // XOR
                    3'b101: alu_ctrl = (funct7[5]) ? 4'b0111 : 4'b0110; // SRA:SRL
                    3'b110: alu_ctrl = 4'b0011; // OR
                    3'b111: alu_ctrl = 4'b0010; // AND
                    default:alu_ctrl = 4'b0000;
                endcase
            end

            // I-type arithmetic - same as R-type but no SUB (no funct7)
            7'b0010011: begin
                case (funct3)
                    3'b000: alu_ctrl = 4'b0000; // ADDI
                    3'b001: alu_ctrl = 4'b0101; // SLLI
                    3'b010: alu_ctrl = 4'b1000; // SLTI
                    3'b011: alu_ctrl = 4'b1001; // SLTIU
                    3'b100: alu_ctrl = 4'b0100; // XORI
                    3'b101: alu_ctrl = (funct7[5]) ? 4'b0111 : 4'b0110; // SRAI:SRLI
                    3'b110: alu_ctrl = 4'b0011; // ORI
                    3'b111: alu_ctrl = 4'b0010; // ANDI
                    default:alu_ctrl = 4'b0000;
                endcase
            end

            // Loads - ALU computes address = rs1 + imm
            7'b0000011: alu_ctrl = 4'b0000; // ADD

            // Stores - ALU computes address = rs1 + imm
            7'b0100011: alu_ctrl = 4'b0000; // ADD

            // Branches - ALU computes rs1 - rs2, checks zero/sign
            7'b1100011: alu_ctrl = 4'b0001; // SUB

            // LUI - pass immediate directly
            // We use ADD with rs1=x0 (decoder sets alu_src=1)
            7'b0110111: alu_ctrl = 4'b0000; // ADD (x0 + imm)

            // AUIPC - PC + imm
            7'b0010111: alu_ctrl = 4'b0000; // ADD

            // JAL, JALR - ALU computes return address PC+4
            7'b1101111: alu_ctrl = 4'b0000; // ADD
            7'b1100111: alu_ctrl = 4'b0000; // ADD

            // M-extension - MUL handled separately in EX stage
            // ALU ctrl irrelevant, EX stage detects M-extension
            
            7'b0110011: alu_ctrl = 4'b0000; // placeholder

            default:    alu_ctrl = 4'b0000;
        endcase
    end

    // ----------------------------------------------------------
    // Main control decoder
    // Produces all pipeline control signals from opcode
    // ----------------------------------------------------------
    reg reg_write, mem_read, mem_write, mem_to_reg;
    reg alu_src, branch, jump;
    // M-extension: opcode=0110011, funct7=0000001
    wire is_mul = (opcode == 7'b0110011) && (funct7 == 7'b0000001);
    always @(*) begin
        // Safe defaults - all signals off
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;
        alu_src    = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;

        case (opcode)
            7'b0110011: begin // R-type
                reg_write = 1'b1;
            end

            7'b0010011: begin // I-type arithmetic
                reg_write = 1'b1;
                alu_src   = 1'b1; // operand B is immediate
            end

            7'b0000011: begin // Load
                reg_write  = 1'b1;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1; // rd gets memory data
                alu_src    = 1'b1; // address = rs1 + imm
            end

            7'b0100011: begin // Store
                mem_write = 1'b1;
                alu_src   = 1'b1; // address = rs1 + imm
            end

            7'b1100011: begin // Branch
                branch = 1'b1;
                // alu_src = 0: ALU compares rs1 and rs2
            end

            7'b0110111: begin // LUI
                reg_write = 1'b1;
                alu_src   = 1'b1;
            end

            7'b0010111: begin // AUIPC
                reg_write = 1'b1;
                alu_src   = 1'b1;
            end

            7'b1101111: begin // JAL
                reg_write = 1'b1;
                jump      = 1'b1;
            end

            7'b1100111: begin // JALR
                reg_write = 1'b1;
                jump      = 1'b1;
                alu_src   = 1'b1;
            end

            default: begin // NOP, SYSTEM, unknown
                // all signals remain 0
            end
        endcase
    end

    // ----------------------------------------------------------
    // ID/EX pipeline register
    // Latches all decoded signals for EX stage
    // Flush: zero all control signals (convert to NOP)
    // Stall: hold current values
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (rst || flush_d) begin
            // Insert NOP - all control signals zero
            id_ex_pc         <= 32'd0;
            id_ex_is_mul <= 1'b0;
            id_ex_rs1_data   <= 32'd0;
            id_ex_rs2_data   <= 32'd0;
            id_ex_rs1_addr   <= 5'd0;
            id_ex_rs2_addr   <= 5'd0;
            id_ex_rd_addr    <= 5'd0;
            id_ex_imm        <= 32'd0;
            id_ex_alu_ctrl   <= 4'd0;
            id_ex_alu_src    <= 1'b0;
            id_ex_reg_write  <= 1'b0;
            id_ex_mem_read   <= 1'b0;
            id_ex_mem_write  <= 1'b0;
            id_ex_mem_to_reg <= 1'b0;
            id_ex_branch     <= 1'b0;
            id_ex_jump       <= 1'b0;
            id_ex_funct3     <= 3'd0;
        end else if (!stall_d) begin
            // Normal operation - latch decoded values
            id_ex_pc         <= if_id_pc;
            id_ex_rs1_data   <= rs1_data;
            id_ex_rs2_data   <= rs2_data;
            id_ex_rs1_addr   <= rs1;
            id_ex_rs2_addr   <= rs2;
            id_ex_rd_addr    <= rd;
            id_ex_imm        <= imm;
            id_ex_alu_ctrl   <= alu_ctrl;
            id_ex_alu_src    <= alu_src;
            id_ex_reg_write  <= reg_write;
            id_ex_mem_read   <= mem_read;
            id_ex_mem_write  <= mem_write;
            id_ex_mem_to_reg <= mem_to_reg;
            id_ex_branch     <= branch;
            id_ex_jump       <= jump;
            id_ex_funct3     <= funct3;
            id_ex_is_mul <= is_mul;
        end
        // stall_d == 1: hold all values
    end

endmodule