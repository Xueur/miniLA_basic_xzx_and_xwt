`timescale 1ns / 1ps

`include "defines.vh"

// 直连映射数据Cache (写穿+写分配)

module DCache(
    input  wire         cpu_clk,
    input  wire         cpu_rst,        // 高有效
    // CPU接口
    input  wire [ 3:0]  data_ren,       // 读使能
    input  wire [31:0]  data_addr,      // 地址 (读写共享)
    output reg          data_valid,     // 读数据有效
    output reg  [31:0]  data_rdata,     // 读数据
    input  wire [ 3:0]  data_wen,       // 写使能
    input  wire [31:0]  data_wdata,     // 写数据
    output reg          data_wresp,     // 写响应
    // 总线接口
    input  wire         dev_wrdy,       // 总线写就绪
    output wire [ 3:0]  cpu_wen,        // 写使能 (组合)
    output wire [31:0]  cpu_waddr,      // 写地址(组合)
    output wire [31:0]  cpu_wdata,      // 写数据 (组合)
    input  wire         dev_rrdy,       // 总线读就绪
    output wire [ 3:0]  cpu_ren,        // 读使能 (组合)
    output wire [31:0]  cpu_raddr,      // 读地址(组合)
    input  wire         dev_rvalid,     // 总线读数据有效
    input  wire [`DC_BLK_SIZE-1:0] dev_rdata  // 读数据(128位)
);

    localparam INDEX_W = 6;  // 64行, 6位索引
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
