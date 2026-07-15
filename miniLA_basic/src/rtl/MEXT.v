`timescale 1ns / 1ps

`include "defines.vh"

module MEXT (
    input  wire [ 2:0]  op,
    input  wire [31:0]  din,
    input  wire [ 1:0]  byte_offs,
    output reg  [31:0]  ext
);

    reg [31:0] real_din;
    always @(*) begin
        case (byte_offs)
            2'b01  : real_din = { 8'h0, din[31: 8]};
            2'b10  : real_din = {16'h0, din[31:16]};
            2'b11  : real_din = {24'h0, din[31:24]};
            default: real_din = din;
        endcase
    end

    always @(*) begin
        case (op)
            `RAM_EXT_B : ext = {{24{real_din[ 7]}}, real_din[ 7:0]};  // 符号扩展8位
            `RAM_EXT_BU: ext = {24'h0, real_din[ 7:0]};               // 零扩展8位
            `RAM_EXT_H : ext = {{16{real_din[15]}}, real_din[15:0]};  // 符号扩展16位
            `RAM_EXT_HU: ext = {16'h0, real_din[15:0]};               // 零扩展16位
            default    : ext = real_din;                               // ld.w: 直通32位
        endcase
    end

endmodule
