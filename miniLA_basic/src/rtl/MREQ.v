`timescale 1ns / 1ps

`include "defines.vh"

module MREQ (
    input  wire [31:0]  ram_addr,

    input  wire [ 2:0]  ram_rop,
    output reg  [ 3:0]  da_ren,
    output wire [31:0]  da_addr,

    input  wire [ 3:0]  ram_wop,
    input  wire [31:0]  ram_wdata,
    output reg  [ 3:0]  da_wen,
    output reg  [31:0]  da_wdata
);

    wire [1:0] offset = ram_addr[1:0];

    assign da_addr = ram_addr;

    // ================================================================
    // 写访存请求 (Store)
    // ================================================================
    always @(*) begin
        da_wen   = 4'h0;
        da_wdata = 32'h0;

        case (ram_wop)
            `RAM_WE_B: begin
                // st.b: 根据字节偏移写入1字节
                case (offset)
                    2'b00: begin da_wen = 4'b0001; da_wdata = {24'h0, ram_wdata[7:0]}; end
                    2'b01: begin da_wen = 4'b0010; da_wdata = {16'h0, ram_wdata[7:0], 8'h0}; end
                    2'b10: begin da_wen = 4'b0100; da_wdata = {8'h0, ram_wdata[7:0], 16'h0}; end
                    2'b11: begin da_wen = 4'b1000; da_wdata = {ram_wdata[7:0], 24'h0}; end
                endcase
            end
            `RAM_WE_H: begin
                // st.h: 根据半字偏移写入2字节 (offset[1]对齐)
                case (offset[1])
                    1'b0: begin da_wen = 4'b0011; da_wdata = {16'h0, ram_wdata[15:0]}; end
                    1'b1: begin da_wen = 4'b1100; da_wdata = {ram_wdata[15:0], 16'h0}; end
                endcase
            end
            `RAM_WE_W: begin
                // st.w: 写入4字节 (需字对齐)
                if (offset == 2'h0) begin
                    da_wen   = 4'b1111;
                    da_wdata = ram_wdata;
                end
            end
        endcase
    end

    // ================================================================
    // 读访存请求 (Load)
    // ================================================================
    always @(*) begin
        if (ram_rop != `RAM_EXT_N) begin
            case (ram_rop)
                `RAM_EXT_B, `RAM_EXT_BU: begin
                    // 字节对齐无要求，可任意offset
                    case (offset)
                        2'b00: da_ren = 4'b0001;
                        2'b01: da_ren = 4'b0010;
                        2'b10: da_ren = 4'b0100;
                        2'b11: da_ren = 4'b1000;
                    endcase
                end
                `RAM_EXT_H, `RAM_EXT_HU: begin
                    // 半字对齐: offset[0]必须为0
                    da_ren = (offset[0] == 1'b0) ?
                        (offset[1] ? 4'b1100 : 4'b0011) : 4'h0;
                end
                default: begin
                    // ld.w: 字对齐
                    da_ren = (offset == 2'h0) ? 4'hF : 4'h0;
                end
            endcase
        end else
            da_ren = 4'h0;
    end

endmodule
