// ============================================================
// IF Stage - Instruction Fetch
// RISC-V SoC Project | Nexys A7 100T
// ============================================================
// Contains:
//   - PC register with next-PC mux
//   - Interface to instruction memory
//   - IF/ID pipeline register
//
// Next PC priority (highest to lowest):
//   1. Branch target (branch taken, from EX stage)
//   2. Jump target   (JAL/JALR, from EX stage)
//   3. PC + 4        (normal sequential execution)
//
// Control inputs:
//   stall_f  - hold PC and IF/ID register (load-use hazard)
//   flush_f  - insert NOP into IF/ID (branch misprediction)
// ============================================================

module if_stage (
    input  wire        clk,
    input  wire        rst,

    // Control signals from hazard/branch logic
    input  wire        stall_f,       // 1 = freeze IF stage
    input  wire        flush_f,       // 1 = flush IF/ID register

    // Branch/jump redirect from EX stage
    input  wire        branch_taken,  // 1 = branch resolved as taken
    input  wire        jump,          // 1 = JAL or JALR
    input  wire [31:0] branch_target, // Target PC for branch
    input  wire [31:0] jump_target,   // Target PC for jump

    // IF/ID pipeline register outputs (to ID stage)
    output reg  [31:0] if_id_pc,      // PC of fetched instruction
    output reg  [31:0] if_id_instr    // Fetched instruction
);

    // ----------------------------------------------------------
    // PC register
    // Holds address of instruction currently being fetched
    // ----------------------------------------------------------
    reg  [31:0] pc;
    wire [31:0] pc_next;
    wire [31:0] instr_out;  // Raw instruction from memory

    // ----------------------------------------------------------
    // Next PC mux
    // Priority: branch > jump > PC+4
    // Both branch and jump signals come from EX stage
    // ----------------------------------------------------------
    assign pc_next = branch_taken ? branch_target :
                     jump         ? jump_target   :
                                    pc + 32'd4;

    // ----------------------------------------------------------
    // PC register update
    // Stall: hold current PC (do not advance)
    // Reset: jump to address 0 (start of program)
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (rst)
            pc <= 32'd0;
        else if (!stall_f)
            pc <= pc_next;
        // if stall_f == 1: pc holds its value (implicit)
    end

    // ----------------------------------------------------------
    // Instruction memory instance
    // ----------------------------------------------------------
    instr_mem imem (
        .clk  (clk),
        .addr (pc),
        .instr(instr_out)
    );

    // ----------------------------------------------------------
    // IF/ID pipeline register
    // Latches PC and instruction, passes to ID stage
    //
    // Flush: insert NOP (32'd0 = ADDI x0,x0,0 in RV32I)
    //        Used when branch was mispredicted
    // Stall: hold current IF/ID values, do not update
    // Normal: latch new PC and instruction
    //
    // Note: because instr_mem is synchronous (registered output),
    // the instruction appears one cycle after the PC is presented.
    // So if_id_pc is registered one cycle behind instr_out.
    // We store pc (current fetch address) alongside the instruction
    // that will appear next cycle.
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            if_id_pc    <= 32'd0;
            if_id_instr <= 32'd0;
        end else if (flush_f) begin
            // Branch misprediction - squash fetched instruction
            if_id_pc    <= 32'd0;
            if_id_instr <= 32'd0; // NOP
        end else if (!stall_f) begin
            // Normal operation - advance pipeline
            if_id_pc    <= pc;
            if_id_instr <= instr_out;
        end
        // stall_f == 1 and no flush: hold current values
    end

endmodule