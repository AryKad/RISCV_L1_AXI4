// ============================================================
// Instruction Memory - Simple BRAM, 4KB
// RISC-V SoC Project | Nexys A7 100T
// ============================================================
// Synchronous read, initialized from a hex file.
// Will be replaced by I$ cache in later build phase.
// 4KB = 1024 32-bit instructions.
// ============================================================

module instr_mem (
    input  wire        clk,
    input  wire [31:0] addr,      // Byte address from PC
    output reg  [31:0] instr      // 32-bit instruction out
);
    // 1024 words of 32 bits = 4KB
    reg [31:0] mem [0:1023];

    // Initialize from hex file
    // Create a file called program.hex in your project directory
    initial begin
        $readmemh("program.hex", mem);
    end

    // Synchronous read
    // Word-aligned: PC[31:2] indexes the memory
    // PC[1:0] always 0 for RV32I (instructions are 4-byte aligned)
    always @(posedge clk) begin
        instr <= mem[addr[11:2]];
    end

endmodule