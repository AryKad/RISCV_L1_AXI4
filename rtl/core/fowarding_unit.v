// ============================================================
// Forwarding Unit
// RISC-V SoC Project | Nexys A7 100T
// ============================================================
// Detects data hazards and generates forwarding mux selects.
// Compares destination registers of instructions in EX/MEM
// and MEM/WB against source registers of current EX instruction.
//
// Forward encoding:
//   2'b00 = no forward, use ID/EX register file value
//   2'b01 = forward from MEM/WB (2 cycles ago)
//   2'b10 = forward from EX/MEM (1 cycle ago)
// ============================================================

module forwarding_unit (
    // Source registers of instruction currently in EX
    input  wire [4:0] id_ex_rs1_addr,
    input  wire [4:0] id_ex_rs2_addr,

    // Destination register of instruction in EX/MEM
    input  wire [4:0] ex_mem_rd_addr,
    input  wire       ex_mem_reg_write,

    // Destination register of instruction in MEM/WB
    input  wire [4:0] mem_wb_rd_addr,
    input  wire       mem_wb_reg_write,

    // Forwarding mux selects
    output reg  [1:0] forward_a,  // for operand A (rs1)
    output reg  [1:0] forward_b   // for operand B (rs2)
);

    always @(*) begin
        // Default: no forwarding
        forward_a = 2'b00;
        forward_b = 2'b00;

        // Forward A - check EX/MEM first (higher priority, more recent)
        if (ex_mem_reg_write &&
            ex_mem_rd_addr != 5'd0 &&
            ex_mem_rd_addr == id_ex_rs1_addr)
            forward_a = 2'b10; // forward from EX/MEM

        else if (mem_wb_reg_write &&
                 mem_wb_rd_addr != 5'd0 &&
                 mem_wb_rd_addr == id_ex_rs1_addr)
            forward_a = 2'b01; // forward from MEM/WB

        // Forward B - same priority logic
        if (ex_mem_reg_write &&
            ex_mem_rd_addr != 5'd0 &&
            ex_mem_rd_addr == id_ex_rs2_addr)
            forward_b = 2'b10; // forward from EX/MEM

        else if (mem_wb_reg_write &&
                 mem_wb_rd_addr != 5'd0 &&
                 mem_wb_rd_addr == id_ex_rs2_addr)
            forward_b = 2'b01; // forward from MEM/WB
    end

endmodule