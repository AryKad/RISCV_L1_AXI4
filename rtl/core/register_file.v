// ============================================================
// Register File - 32 × 32-bit registers
// RISC-V SoC Project | Nexys A7 100T
// ============================================================
// - 32 registers: x0 through x31
// - x0 hardwired to zero (reads always return 0, writes ignored)
// - Two asynchronous read ports (RS1, RS2)
// - One synchronous write port (RD), write on rising clock edge
// - Write-first: if write and read address match, new value
//   is forwarded directly to read output same cycle
// ============================================================

module register_file (
    input  wire        clk,
    input  wire        rst,

    // Read port 1 (RS1)
    input  wire [4:0]  rs1_addr,    // Register address to read
    output wire [31:0] rs1_data,    // Register value out

    // Read port 2 (RS2)
    input  wire [4:0]  rs2_addr,    // Register address to read
    output wire [31:0] rs2_data,    // Register value out

    // Write port (RD)
    input  wire [4:0]  rd_addr,     // Register address to write
    input  wire [31:0] rd_data,     // Value to write
    input  wire        rd_we        // Write enable - 1 = write
);

    // ----------------------------------------------------------
    // 32 registers, each 32 bits wide
    // Index 0 = x0, index 31 = x31
    // Synthesizes to distributed RAM (LUT-based) on Artix-7
    // ----------------------------------------------------------
    reg [31:0] regs [31:0];

    // ----------------------------------------------------------
    // Synchronous write
    // x0 is hardwired to zero - ignore writes to address 0
    // ----------------------------------------------------------
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            // Initialize all registers to 0 on reset
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end else if (rd_we && rd_addr != 5'd0) begin
            // Write only if write enable is asserted
            // and destination is not x0
            regs[rd_addr] <= rd_data;
        end
    end

    // ----------------------------------------------------------
    // Asynchronous read port 1 (RS1)
    // Write-first: if reading the same address being written
    // this cycle, forward the new write data directly
    // x0 always returns 0
    // ----------------------------------------------------------
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 :
                      (rd_we && rd_addr == rs1_addr) ? rd_data :
                      regs[rs1_addr];

    // ----------------------------------------------------------
    // Asynchronous read port 2 (RS2)
    // Same write-first forwarding logic as RS1
    // ----------------------------------------------------------
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 :
                      (rd_we && rd_addr == rs2_addr) ? rd_data :
                      regs[rs2_addr];

endmodule