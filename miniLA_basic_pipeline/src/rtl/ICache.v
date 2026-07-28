`timescale 1ns / 1ps

`include "defines.vh"

// Direct-mapped Instruction Cache
//   Capacity: 64 lines x 128 bits = 1KB
//   Ported from reference miniRV design

module ICache(
    input  wire         cpu_clk,
    input  wire         cpu_rst,        // high active
    // Interface to CPU
    input  wire         inst_rreq,      // instruction read request
    input  wire [31:0]  inst_addr,      // instruction address
    output reg          inst_valid,     // instruction valid
    output reg  [31:0]  inst_out,       // instruction output
    // Interface to Read Bus (from axi_bus)
    input  wire         dev_rrdy,       // bus ready to accept read request
    output wire [ 3:0]  cpu_ren,        // read enable to bus (combinational)
    output wire [31:0]  cpu_raddr,      // read address to bus (combinational)
    input  wire         dev_rvalid,     // bus data valid
    input  wire [`IC_BLK_SIZE-1:0] dev_rdata  // data from bus (128 bits)
);

    localparam INDEX_W = 6;  // 64 lines
    localparam TAG_W   = 5;

    localparam ST_IDLE  = 2'd0;
    localparam ST_REQ   = 2'd1;
    localparam ST_WAIT  = 2'd2;

    reg [1:0] state;
    reg [31:0] miss_addr;

    reg [TAG_W-1:0] tags [0:63];
    reg [127:0] lines [0:63];
    reg valid [0:63];
    integer i;

    wire [INDEX_W-1:0] cpu_index = inst_addr[INDEX_W+3:4];
    wire [TAG_W-1:0]   cpu_tag   = inst_addr[31:INDEX_W+4];
    wire cpu_hit = valid[cpu_index] && tags[cpu_index] == cpu_tag;

    wire [INDEX_W-1:0] miss_index = miss_addr[INDEX_W+3:4];
    wire [TAG_W-1:0]   miss_tag   = miss_addr[31:INDEX_W+4];

    function [31:0] pick_word;
        input [127:0] line_data;
        input [  1:0] word_offset;
        begin
            case (word_offset)
                2'b00:   pick_word = line_data[31:0];
                2'b01:   pick_word = line_data[63:32];
                2'b10:   pick_word = line_data[95:64];
                default: pick_word = line_data[127:96];
            endcase
        end
    endfunction

    assign cpu_ren   = (state == ST_REQ) ? 4'hF : 4'h0;
    assign cpu_raddr = {miss_addr[31:4], 4'b0000};

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            state     <= ST_IDLE;
            inst_valid <= 1'b0;
            inst_out   <= 32'h0;
            miss_addr  <= 32'h0;
            for (i = 0; i < 64; i = i + 1)
                valid[i] <= 1'b0;
        end else begin
            inst_valid <= 1'b0;
            case (state)
                ST_IDLE: begin
                    if (inst_rreq) begin
                        if (cpu_hit) begin
                            inst_out <= pick_word(lines[cpu_index], inst_addr[3:2]);
                            inst_valid <= 1'b1;
                        end else begin
                            miss_addr <= inst_addr;
                            state <= ST_REQ;
                        end
                    end
                end

                ST_REQ:
                    if (dev_rrdy)
                        state <= ST_WAIT;

                ST_WAIT: begin
                    if (dev_rvalid) begin
                        lines[miss_index] <= dev_rdata;
                        tags[miss_index]  <= miss_tag;
                        valid[miss_index] <= 1'b1;
                        inst_out   <= pick_word(dev_rdata, miss_addr[3:2]);
                        inst_valid <= 1'b1;
                        state <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
