// Hazard Detection Unit
// RISC-V SoC Project | Nexys A7 100T
// ============================================================
// Detects load-use hazards - the one case forwarding can't fix.
// When detected: stalls IF and ID, inserts bubble into EX.
//
// Also handles branch/jump flush signals:
// When EX detects branch taken or jump, flush IF and ID
// to squash the two wrongly fetched instructions.
// ============================================================

module hazard_unit (
    // Load-use hazard detection
    // Check if instruction in EX is a load
    input  wire       id_ex_mem_read,   // 1 if EX instruction is load
    input  wire [4:0] id_ex_rd_addr,    // destination of EX instruction

    // Source registers of instruction currently in ID
    input  wire [4:0] if_id_rs1,        // rs1 of ID instruction
    input  wire [4:0] if_id_rs2,        // rs2 of ID instruction

    // Branch/jump from EX stage
    input  wire       branch_taken,     // branch resolved as taken
    input  wire       jump,             // JAL or JALR

    // Stall and flush outputs
    output wire       stall_f,          // freeze PC and IF/ID
    output wire       stall_d,          // freeze ID/EX
    output wire       flush_d,          // insert bubble into ID/EX
    output wire       flush_f           // flush IF/ID (branch/jump)
);

    // ----------------------------------------------------------
    // Load-use hazard detection
    // Stall if EX is a load AND its rd matches rs1 or rs2 of ID
    // x0 never causes a hazard (reads always return 0)
    // ----------------------------------------------------------
    wire load_use_hazard = id_ex_mem_read &&
                           (id_ex_rd_addr != 5'd0) &&
                           ((id_ex_rd_addr == if_id_rs1) ||
                            (id_ex_rd_addr == if_id_rs2));

    // ----------------------------------------------------------
    // Control hazard - branch taken or jump
    // Flush IF (squash wrongly fetched instruction)
    // Flush ID (squash instruction that entered ID)
    // ----------------------------------------------------------
    wire control_hazard = branch_taken || jump;

    // ----------------------------------------------------------
    // Output assignments
    // Load-use: stall IF and ID, insert bubble into EX
    // Control:  flush IF/ID pipeline registers
    // Both can occur simultaneously (unlikely but handled)
    // ----------------------------------------------------------
    assign stall_f = load_use_hazard;
    assign stall_d = load_use_hazard;
    assign flush_d = load_use_hazard || control_hazard;
    assign flush_f = control_hazard;

endmodule