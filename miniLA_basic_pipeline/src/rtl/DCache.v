`timescale 1ns / 1ps

`include "defines.vh"

// Direct-mapped Data Cache (Write-through + Write-allocate)
//   Capacity: 64 lines x 128 bits = 1KB
//   Direct-mapped, write-through + write-allocate

module DCache(
    input  wire         cpu_clk,
    input  wire         cpu_rst,        // high active
    // Interface to CPU
    input  wire [ 3:0]  data_ren,       // read enable
    input  wire [31:0]  data_addr,      // address (read/write shared)
    output reg          data_valid,     // read data valid
    output reg  [31:0]  data_rdata,     // read data to CPU
    input  wire [ 3:0]  data_wen,       // write enable
    input  wire [31:0]  data_wdata,     // write data
    output reg          data_wresp,     // write response
    // Interface to Bus
    input  wire         dev_wrdy,       // bus write ready
    output wire [ 3:0]  cpu_wen,        // write enable to bus (combinational)
    output wire [31:0]  cpu_waddr,      // write address to bus (combinational)
    output wire [31:0]  cpu_wdata,      // write data to bus (combinational)
    input  wire         dev_rrdy,       // bus read ready
    output wire [ 3:0]  cpu_ren,        // read enable to bus (combinational)
    output wire [31:0]  cpu_raddr,      // read address to bus (combinational)
    input  wire         dev_rvalid,     // bus read data valid
    input  wire [`DC_BLK_SIZE-1:0] dev_rdata  // read data from bus (128 bits)
);

    localparam INDEX_W = 6;  // 64 lines, 6-bit index
    localparam TAG_W   = 5;

    localparam ST_IDLE   = 4'd0;
    localparam ST_RD_REQ = 4'd1;
    localparam ST_RD_WAIT= 4'd2;
    localparam ST_WR_REQ = 4'd3;
    localparam ST_WR_WAIT= 4'd4;

    reg [3:0] state;
    reg [31:0] request_addr;
    reg [31:0] request_wdata;
    reg [3:0] request_wen;

    reg [TAG_W-1:0] tags [0:63];
    reg [127:0] lines [0:63];
    reg valid [0:63];
    integer i;

    wire [INDEX_W-1:0] cpu_index = data_addr[INDEX_W+3:4];
    wire [TAG_W-1:0]   cpu_tag   = data_addr[31:INDEX_W+4];
    wire cpu_hit = valid[cpu_index] && tags[cpu_index] == cpu_tag;

    wire [INDEX_W-1:0] request_index = request_addr[INDEX_W+3:4];
    wire [TAG_W-1:0]   request_tag   = request_addr[31:INDEX_W+4];

    function [31:0] pick_word;
        input [127:0] block;
        input [  1:0] word;
        begin
            case (word)
                2'd0: pick_word = block[31:0];
                2'd1: pick_word = block[63:32];
                2'd2: pick_word = block[95:64];
                default: pick_word = block[127:96];
            endcase
        end
    endfunction

    assign cpu_ren   = (state == ST_RD_REQ) ? 4'hF : 4'h0;
    assign cpu_raddr = {request_addr[31:4], 4'b0000};
    assign cpu_wen   = (state == ST_WR_REQ) ? request_wen : 4'h0;
    assign cpu_waddr = request_addr;
    assign cpu_wdata = request_wdata;

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            state <= ST_IDLE;
            request_addr  <= 32'h0;
            request_wdata <= 32'h0;
            request_wen   <= 4'h0;
            data_valid <= 1'b0;
            data_rdata <= 32'h0;
            data_wresp <= 1'b0;
            for (i = 0; i < 64; i = i + 1)
                valid[i] <= 1'b0;
        end else begin
            data_valid <= 1'b0;
            data_wresp <= 1'b0;
            case (state)
                ST_IDLE: begin
                    if (|data_wen) begin
                        request_addr  <= data_addr;
                        request_wdata <= data_wdata;
                        request_wen   <= data_wen;
                        if (cpu_hit)
                            valid[cpu_index] <= 1'b0;
                        state <= ST_WR_REQ;
                    end else if (|data_ren) begin
                        if (cpu_hit) begin
                            data_rdata <= pick_word(lines[cpu_index], data_addr[3:2]);
                            data_valid <= 1'b1;
                        end else begin
                            request_addr <= data_addr;
                            state <= ST_RD_REQ;
                        end
                    end
                end

                ST_RD_REQ:
                    if (dev_rrdy)
                        state <= ST_RD_WAIT;

                ST_RD_WAIT: begin
                    if (dev_rvalid) begin
                        lines[request_index] <= dev_rdata;
                        tags[request_index]  <= request_tag;
                        valid[request_index] <= 1'b1;
                        data_rdata <= pick_word(dev_rdata, request_addr[3:2]);
                        data_valid <= 1'b1;
                        state <= ST_IDLE;
                    end
                end

                ST_WR_REQ:
                    if (dev_wrdy)
                        state <= ST_WR_WAIT;

                ST_WR_WAIT: begin
                    if (dev_wrdy) begin
                        data_wresp <= 1'b1;
                        state <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
