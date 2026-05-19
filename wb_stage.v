// ============================================================
// WB Stage - Write Back
// RISC-V SoC Project | Nexys A7 100T
// ============================================================
// Selects between ALU result and memory read data.
// Drives register file write port.
// ============================================================

module wb_stage (
    // From MEM/WB pipeline register
    input  wire [31:0] mem_wb_alu_result,
    input  wire [31:0] mem_wb_read_data,
    input  wire [4:0]  mem_wb_rd_addr,
    input  wire        mem_wb_reg_write,
    input  wire        mem_wb_mem_to_reg,

    // To register file write port
    output wire [31:0] wb_data,      // data to write
    output wire [4:0]  wb_rd_addr,   // destination register
    output wire        wb_reg_write  // write enable
);

    // ----------------------------------------------------------
    // Result mux
    // mem_to_reg=1 → load instruction, use memory data
    // mem_to_reg=0 → ALU instruction, use ALU result
    // ----------------------------------------------------------
    assign wb_data     = mem_wb_mem_to_reg ? mem_wb_read_data 
                                           : mem_wb_alu_result;
    assign wb_rd_addr  = mem_wb_rd_addr;
    assign wb_reg_write= mem_wb_reg_write;

endmodule