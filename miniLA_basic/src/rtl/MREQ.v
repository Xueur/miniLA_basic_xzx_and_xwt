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
                // st.b: offset=0透传(匹配参考), offset≠0字节复制到所有lane
                case (offset)
                    2'b00: begin da_wen = 4'b0001; da_wdata = ram_wdata; end
                    default: begin da_wen = 4'b0001 << offset; da_wdata = {4{ram_wdata[7:0]}}; end
                endcase
            end
            `RAM_WE_H: begin
                // st.h: 半字复制到高低半字, da_wen控制写哪个
                da_wen = offset[1] ? 4'b1100 : 4'b0011;
                da_wdata = {2{ram_wdata[15:0]}};
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
