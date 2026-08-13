`timescale 1ns / 1ps

`include "defines.vh"

module ALU (
    input  wire         rst,
    input  wire         clk,
    input  wire [ 4:0]  op,
    input  wire [31:0]  a,
    input  wire [31:0]  b,
    input  wire         md_start,

    output reg  [31:0]  c,
    output reg          br,
    output wire         busy
);

    wire start_mul  = md_start && ((op == `ALU_MUL) | (op == `ALU_MULH));
    wire start_mulu = md_start && (op == `ALU_MULHU);
    wire start_div  = md_start && ((op == `ALU_DIV) | (op == `ALU_MOD));
    wire start_divu = md_start && ((op == `ALU_DIVU) | (op == `ALU_MODU));

    wire [63:0] mul_res, mulu_res;
    wire        mul_busy, mulu_busy;
    wire [31:0] div_quo, divu_quo;
    wire [31:0] div_rem, divu_rem;
    wire        div_busy, divu_busy;

    reg  [31:0] md_a;
    reg  [31:0] md_b;
    reg  [ 4:0] md_op;

    wire [31:0] abs_a = a[31] ? (~a + 32'h1) : a;
    wire [31:0] abs_b = b[31] ? (~b + 32'h1) : b;

    wire div_neg_quo = md_a[31] ^ md_b[31];
    wire [31:0] div_quo_signed = div_neg_quo ? (~div_quo + 1'b1) : div_quo;
    wire [31:0] div_rem_signed = md_a[31] ? (~div_rem + 1'b1) : div_rem;

    assign busy = mul_busy | mulu_busy | div_busy | divu_busy;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            md_a  <= 32'h0;
            md_b  <= 32'h0;
            md_op <= `ALU_ADD;
        end else if (md_start) begin
            md_a  <= a;
            md_b  <= b;
            md_op <= op;
        end
    end

    always @(*) begin
        case (op)
            `ALU_ADD  : c = a + b;
            `ALU_SUB  : c = a - b;
            `ALU_OR   : c = a | b;
            `ALU_AND  : c = a & b;
            `ALU_XOR  : c = a ^ b;
            `ALU_SLL  : c = a << b[4:0];
            `ALU_SRL  : c = a >> b[4:0];
            `ALU_SRA  : c = $signed(a) >>> b[4:0];
            `ALU_SLT  : c = ($signed(a) < $signed(b)) ? 32'h1 : 32'h0;
            `ALU_SLTU : c = (a < b) ? 32'h1 : 32'h0;
            `ALU_MUL  : c = mul_res[31:0];
            `ALU_MULH : c = mul_res[63:32];
            `ALU_MULHU: c = mulu_res[63:32];
            `ALU_DIV  : c = md_b == 32'h0 ? 32'h0 : div_quo_signed;
            `ALU_DIVU : c = md_b == 32'h0 ? 32'h0 : divu_quo;
            `ALU_MOD  : c = md_b == 32'h0 ? 32'h0 : div_rem_signed;
            `ALU_MODU : c = md_b == 32'h0 ? 32'h0 : divu_rem;
            default   : c = 32'h0;
        endcase
    end

    // 分支条件(组合)
    always @(*) begin
        case (op)
            `ALU_BEQ  : br = (a == b);
            `ALU_BNE  : br = (a != b);
            `ALU_BLT  : br = ($signed(a) < $signed(b));
            `ALU_BGE  : br = ($signed(a) >= $signed(b));
            `ALU_BLTU : br = (a < b);
            `ALU_BGEU : br = (a >= b);
            default   : br = 1'b0;
        endcase
    end

    // 有符号乘法器(Booth)
    multiplier #(32) U_mul (
        .clk    (clk),
        .rst    (rst),
        .x      (a),
        .y      (b),
        .start  (start_mul),
        .z      (mul_res),
        .busy   (mul_busy)
    );

    // 无符号乘法器
    multiplier #(33) U_mulu (
        .clk    (clk),
        .rst    (rst),
        .x      ({1'b0, a}),
        .y      ({1'b0, b}),
        .start  (start_mulu),
        .z      (mulu_res),
        .busy   (mulu_busy)
    );

    // 有符号除法器(恢复余数)
    divider #(32) U_div (
        .clk    (clk),
        .rst    (rst),
        .x      (abs_a),
        .y      (abs_b),
        .start  (start_div),
        .z      (div_quo),
        .r      (div_rem),
        .busy   (div_busy)
    );

    // 无符号除法器
    divider #(33) U_divu (
        .clk    (clk),
        .rst    (rst),
        .x      ({1'b0, a}),
        .y      ({1'b0, b}),
        .start  (start_divu),
        .z      (divu_quo),
        .r      (divu_rem),
        .busy   (divu_busy)
    );

endmodule
