// ============================================================
// Data Memory - Simple BRAM, 4KB
// RISC-V SoC Project | Nexys A7 100T
// ============================================================
// Synchronous read and write.
// Supports byte-enable writes for SB, SH, SW.
// Will be replaced by D$ cache in later build phase.
// 4KB = 1024 32-bit words.
// ============================================================

module data_mem (
    input  wire        clk,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [31:0] addr,        // Byte address
    input  wire [31:0] write_data,  // Data to write
    input  wire [3:0]  byte_en,     // Byte enable for writes
    output reg  [31:0] read_data    // Data read out
);
    reg [31:0] mem [0:1023];

    // Initialize to zero
    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1)
            mem[i] = 32'd0;
    end

    // Synchronous write with byte enables
    // byte_en[0] = byte 0 (bits 7:0)
    // byte_en[1] = byte 1 (bits 15:8)
    // byte_en[2] = byte 2 (bits 23:16)
    // byte_en[3] = byte 3 (bits 31:24)
    always @(posedge clk) begin
        if (mem_write) begin
            if (byte_en[0]) mem[addr[11:2]][7:0]   <= write_data[7:0];
            if (byte_en[1]) mem[addr[11:2]][15:8]  <= write_data[15:8];
            if (byte_en[2]) mem[addr[11:2]][23:16] <= write_data[23:16];
            if (byte_en[3]) mem[addr[11:2]][31:24] <= write_data[31:24];
        end
    end

    // Synchronous read
    always @(posedge clk) begin
        if (mem_read)
            read_data <= mem[addr[11:2]];
        else
            read_data <= 32'd0;
    end

endmodule