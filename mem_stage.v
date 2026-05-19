// ============================================================
// MEM Stage - Memory Access
// RISC-V SoC Project | Nexys A7 100T
// ============================================================
// Handles load and store instructions.
// Computes byte enables for SB/SH/SW.
// Sign/zero extends loaded data for LB/LH/LBU/LHU.
// Passes through control signals to MEM/WB register.
// ============================================================

module mem_stage (
    input  wire        clk,
    input  wire        rst,

    // From EX/MEM pipeline register
    input  wire [31:0] ex_mem_alu_result,  // memory address or ALU result
    input  wire [31:0] ex_mem_rs2_data,    // store data
    input  wire [4:0]  ex_mem_rd_addr,
    input  wire        ex_mem_reg_write,
    input  wire        ex_mem_mem_read,
    input  wire        ex_mem_mem_write,
    input  wire        ex_mem_mem_to_reg,
    input  wire [2:0]  ex_mem_funct3,

    // MEM/WB pipeline register outputs
    output reg  [31:0] mem_wb_alu_result,  // passes through for non-loads
    output reg  [31:0] mem_wb_read_data,   // loaded data (after extension)
    output reg  [4:0]  mem_wb_rd_addr,
    output reg         mem_wb_reg_write,
    output reg         mem_wb_mem_to_reg
);

    // ----------------------------------------------------------
    // Byte enable generation
    // addr[1:0] gives byte offset within the word
    // SW: all 4 bytes enabled
    // SH: 2 bytes enabled, position depends on addr[1]
    // SB: 1 byte enabled, position depends on addr[1:0]
    // ----------------------------------------------------------
    reg [3:0] byte_en;

    always @(*) begin
        byte_en = 4'b0000;
        if (ex_mem_mem_write) begin
            case (ex_mem_funct3)
                3'b010: byte_en = 4'b1111; // SW - all 4 bytes
                3'b001: begin              // SH - 2 bytes
                    case (ex_mem_alu_result[1])
                        1'b0: byte_en = 4'b0011; // lower halfword
                        1'b1: byte_en = 4'b1100; // upper halfword
                    endcase
                end
                3'b000: begin              // SB - 1 byte
                    case (ex_mem_alu_result[1:0])
                        2'b00: byte_en = 4'b0001;
                        2'b01: byte_en = 4'b0010;
                        2'b10: byte_en = 4'b0100;
                        2'b11: byte_en = 4'b1000;
                    endcase
                end
                default: byte_en = 4'b0000;
            endcase
        end
    end

    // ----------------------------------------------------------
    // Write data alignment
    // For SB/SH, data must be placed in correct byte lane
    // ----------------------------------------------------------
    reg [31:0] aligned_write_data;

    always @(*) begin
        case (ex_mem_funct3)
            3'b010: aligned_write_data = ex_mem_rs2_data; // SW
            3'b001: begin // SH
                case (ex_mem_alu_result[1])
                    1'b0: aligned_write_data = ex_mem_rs2_data;
                    1'b1: aligned_write_data = {ex_mem_rs2_data[15:0], 16'b0};
                endcase
            end
            3'b000: begin // SB
                case (ex_mem_alu_result[1:0])
                    2'b00: aligned_write_data = ex_mem_rs2_data;
                    2'b01: aligned_write_data = {ex_mem_rs2_data[7:0], 8'b0, 16'b0};
                    2'b10: aligned_write_data = {ex_mem_rs2_data[7:0], 16'b0, 8'b0};
                    2'b11: aligned_write_data = {ex_mem_rs2_data[7:0], 24'b0};
                endcase
            end
            default: aligned_write_data = ex_mem_rs2_data;
        endcase
    end

    // ----------------------------------------------------------
    // Data memory instance
    // ----------------------------------------------------------
    wire [31:0] raw_read_data;

    data_mem dmem (
        .clk        (clk),
        .mem_read   (ex_mem_mem_read),
        .mem_write  (ex_mem_mem_write),
        .addr       (ex_mem_alu_result),
        .write_data (aligned_write_data),
        .byte_en    (byte_en),
        .read_data  (raw_read_data)
    );

    // ----------------------------------------------------------
    // Load data sign/zero extension
    // Applied after memory read, before MEM/WB register
    // ----------------------------------------------------------
    reg [31:0] extended_read_data;

    always @(*) begin
        case (ex_mem_funct3)
            3'b010: extended_read_data = raw_read_data; // LW - full word
            3'b000: extended_read_data = {{24{raw_read_data[7]}},
                                           raw_read_data[7:0]};   // LB
            3'b001: extended_read_data = {{16{raw_read_data[15]}},
                                           raw_read_data[15:0]};  // LH
            3'b100: extended_read_data = {24'd0, raw_read_data[7:0]};  // LBU
            3'b101: extended_read_data = {16'd0, raw_read_data[15:0]}; // LHU
            default: extended_read_data = raw_read_data;
        endcase
    end

    // ----------------------------------------------------------
    // MEM/WB pipeline register
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            mem_wb_alu_result <= 32'd0;
            mem_wb_read_data  <= 32'd0;
            mem_wb_rd_addr    <= 5'd0;
            mem_wb_reg_write  <= 1'b0;
            mem_wb_mem_to_reg <= 1'b0;
        end else begin
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_read_data  <= extended_read_data;
            mem_wb_rd_addr    <= ex_mem_rd_addr;
            mem_wb_reg_write  <= ex_mem_reg_write;
            mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
        end
    end

endmodule