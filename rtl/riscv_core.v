// ============================================================
// RISC-V Core - Top Level Integration
// RV32I + M (MUL) | 5-stage pipeline
// Nexys A7 100T | Artix-7 XC7A100T
// ============================================================
// Instantiates and connects:
//   - IF Stage (PC, instruction memory)
//   - ID Stage (decoder, immediate gen, ID/EX register)
//   - EX Stage (ALU, MUL, forwarding muxes, EX/MEM register)
//   - MEM Stage (data memory, load extension, MEM/WB register)
//   - WB Stage (result mux)
//   - Register File (32x32, dual read, single write)
//   - Forwarding Unit (data hazard bypass)
//   - Hazard Detection Unit (load-use stall, branch flush)
// ============================================================

module riscv_core (
    input wire clk,
    input wire rst
);

    // ==========================================================
    // WIRE DECLARATIONS - all inter-module connections
    // ==========================================================

    // ---- Hazard Unit outputs ----
    wire stall_f, stall_d, flush_d, flush_f;

    // ---- IF Stage outputs ----
    wire [31:0] if_id_pc;
    wire [31:0] if_id_instr;

    // ---- Register File connections ----
    wire [4:0]  rs1_addr, rs2_addr;
    wire [31:0] rs1_data, rs2_data;

    // ---- WB Stage outputs (register file write) ----
    wire [31:0] wb_data;
    wire [4:0]  wb_rd_addr;
    wire        wb_reg_write;

    // ---- ID Stage outputs ----
    wire [31:0] id_ex_pc;
    wire [31:0] id_ex_rs1_data, id_ex_rs2_data;
    wire [4:0]  id_ex_rs1_addr, id_ex_rs2_addr, id_ex_rd_addr;
    wire [31:0] id_ex_imm;
    wire [3:0]  id_ex_alu_ctrl;
    wire        id_ex_alu_src;
    wire        id_ex_reg_write, id_ex_mem_read;
    wire        id_ex_mem_write, id_ex_mem_to_reg;
    wire        id_ex_branch, id_ex_jump, id_ex_is_mul;
    wire [2:0]  id_ex_funct3;

    // ---- Forwarding Unit outputs ----
    wire [1:0]  forward_a, forward_b;

    // ---- EX Stage outputs ----
    wire        branch_taken, ex_jump;
    wire [31:0] branch_target, jump_target;
    wire [31:0] ex_mem_alu_result;
    wire [31:0] ex_mem_rs2_data;
    wire [4:0]  ex_mem_rd_addr;
    wire        ex_mem_reg_write, ex_mem_mem_read;
    wire        ex_mem_mem_write, ex_mem_mem_to_reg;
    wire [2:0]  ex_mem_funct3;

    // ---- MEM Stage outputs ----
    wire [31:0] mem_wb_alu_result;
    wire [31:0] mem_wb_read_data;
    wire [4:0]  mem_wb_rd_addr;
    wire        mem_wb_reg_write, mem_wb_mem_to_reg;

    // ---- WB result for forwarding ----
    // WB result is what forwarding unit uses for MEM/WB forward
    // It's the same as wb_data
    wire [31:0] wb_result = wb_data;

    // ==========================================================
    // MODULE INSTANTIATIONS
    // ==========================================================

    // ---- Hazard Detection Unit ----
    hazard_unit hazard (
        .id_ex_mem_read (id_ex_mem_read),
        .id_ex_rd_addr  (id_ex_rd_addr),
        .if_id_rs1      (if_id_instr[19:15]), // rs1 field of ID instr
        .if_id_rs2      (if_id_instr[24:20]), // rs2 field of ID instr
        .branch_taken   (branch_taken),
        .jump           (ex_jump),
        .stall_f        (stall_f),
        .stall_d        (stall_d),
        .flush_d        (flush_d),
        .flush_f        (flush_f)
    );

    // ---- IF Stage ----
    if_stage if_inst (
        .clk           (clk),
        .rst           (rst),
        .stall_f       (stall_f),
        .flush_f       (flush_f),
        .branch_taken  (branch_taken),
        .jump          (ex_jump),
        .branch_target (branch_target),
        .jump_target   (jump_target),
        .if_id_pc      (if_id_pc),
        .if_id_instr   (if_id_instr)
    );

    // ---- Register File ----
    register_file regfile (
        .clk      (clk),
        .rst      (rst),
        .rs1_addr (rs1_addr),
        .rs2_addr (rs2_addr),
        .rd_addr  (wb_rd_addr),
        .rd_data  (wb_data),
        .rd_we    (wb_reg_write),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

    // ---- ID Stage ----
    id_stage id_inst (
        .clk             (clk),
        .rst             (rst),
        .if_id_instr     (if_id_instr),
        .if_id_pc        (if_id_pc),
        .rs1_data        (rs1_data),
        .rs2_data        (rs2_data),
        .rs1_addr        (rs1_addr),
        .rs2_addr        (rs2_addr),
        .stall_d         (stall_d),
        .flush_d         (flush_d),
        .id_ex_pc        (id_ex_pc),
        .id_ex_rs1_data  (id_ex_rs1_data),
        .id_ex_rs2_data  (id_ex_rs2_data),
        .id_ex_rs1_addr  (id_ex_rs1_addr),
        .id_ex_rs2_addr  (id_ex_rs2_addr),
        .id_ex_rd_addr   (id_ex_rd_addr),
        .id_ex_imm       (id_ex_imm),
        .id_ex_alu_ctrl  (id_ex_alu_ctrl),
        .id_ex_alu_src   (id_ex_alu_src),
        .id_ex_reg_write (id_ex_reg_write),
        .id_ex_mem_read  (id_ex_mem_read),
        .id_ex_mem_write (id_ex_mem_write),
        .id_ex_mem_to_reg(id_ex_mem_to_reg),
        .id_ex_branch    (id_ex_branch),
        .id_ex_jump      (id_ex_jump),
        .id_ex_funct3    (id_ex_funct3),
        .id_ex_is_mul    (id_ex_is_mul)
    );

    // ---- Forwarding Unit ----
    forwarding_unit fwd (
        .id_ex_rs1_addr  (id_ex_rs1_addr),
        .id_ex_rs2_addr  (id_ex_rs2_addr),
        .ex_mem_rd_addr  (ex_mem_rd_addr),
        .ex_mem_reg_write(ex_mem_reg_write),
        .mem_wb_rd_addr  (mem_wb_rd_addr),
        .mem_wb_reg_write(mem_wb_reg_write),
        .forward_a       (forward_a),
        .forward_b       (forward_b)
    );

    // ---- EX Stage ----
    ex_stage ex_inst (
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
        .jump                 (ex_jump),
        .branch_target        (branch_target),
        .jump_target          (jump_target),
        .ex_mem_alu_result_reg(ex_mem_alu_result),
        .ex_mem_rs2_data      (ex_mem_rs2_data),
        .ex_mem_rd_addr       (ex_mem_rd_addr),
        .ex_mem_reg_write     (ex_mem_reg_write),
        .ex_mem_mem_read      (ex_mem_mem_read),
        .ex_mem_mem_write     (ex_mem_mem_write),
        .ex_mem_mem_to_reg    (ex_mem_mem_to_reg),
        .ex_mem_funct3        (ex_mem_funct3)
    );

    // ---- MEM Stage ----
    mem_stage mem_inst (
        .clk               (clk),
        .rst               (rst),
        .ex_mem_alu_result (ex_mem_alu_result),
        .ex_mem_rs2_data   (ex_mem_rs2_data),
        .ex_mem_rd_addr    (ex_mem_rd_addr),
        .ex_mem_reg_write  (ex_mem_reg_write),
        .ex_mem_mem_read   (ex_mem_mem_read),
        .ex_mem_mem_write  (ex_mem_mem_write),
        .ex_mem_mem_to_reg (ex_mem_mem_to_reg),
        .ex_mem_funct3     (ex_mem_funct3),
        .mem_wb_alu_result (mem_wb_alu_result),
        .mem_wb_read_data  (mem_wb_read_data),
        .mem_wb_rd_addr    (mem_wb_rd_addr),
        .mem_wb_reg_write  (mem_wb_reg_write),
        .mem_wb_mem_to_reg (mem_wb_mem_to_reg)
    );

    // ---- WB Stage ----
    wb_stage wb_inst (
        .mem_wb_alu_result (mem_wb_alu_result),
        .mem_wb_read_data  (mem_wb_read_data),
        .mem_wb_rd_addr    (mem_wb_rd_addr),
        .mem_wb_reg_write  (mem_wb_reg_write),
        .mem_wb_mem_to_reg (mem_wb_mem_to_reg),
        .wb_data           (wb_data),
        .wb_rd_addr        (wb_rd_addr),
        .wb_reg_write      (wb_reg_write)
    );

endmodule