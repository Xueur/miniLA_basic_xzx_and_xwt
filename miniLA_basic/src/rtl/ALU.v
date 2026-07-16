`timescale 1ns / 1ps

`include "defines.vh"

module ALU (
    input  wire         rst,
    input  wire         clk,
    input  wire [ 4:0]  op,
    input  wire [31:0]  a,
    input  wire [31:0]  b,

    output reg  [31:0]  c,
    output reg          br,
    output wire         busy
);

    wire        mul_flag, mulu_flag;
    wire [63:0] mul_res , mulu_res ;
    wire        mul_busy, mulu_busy;
    wire        div_flag, divu_flag;
    wire [31:0] div_quo , divu_quo ;
    wire [31:0] div_rem , divu_rem ;
    wire        div_busy, divu_busy;
    reg  [ 4:0] op_r;

    // ================================================================
    // 64-bit 乘积累 (用于 mulh.w / mulh.wu)
    // ================================================================
    wire [63:0] mul_signed_64;
    wire [63:0] mul_unsigned_64;
    assign mul_signed_64   = { {32{a[31]}}, a } * { {32{b[31]}}, b };
    assign mul_unsigned_64 = {32'b0, a} * {32'b0, b};

    // ================================================================
    // 运算结果 c (组合逻辑)
    // ================================================================
    always @(*) begin
        case (op_r != 0 ? op_r : op)
            `ALU_ADD  : c = a + b;
            `ALU_SUB  : c = a - b;
            `ALU_OR   : c = a | b;
            `ALU_AND  : c = a & b;
            `ALU_XOR  : c = a ^ b;
            `ALU_SLL  : c = a << b[4:0];
            `ALU_SRL  : c = a >> b[4:0];          // 逻辑右移
            `ALU_SRA  : c = $signed(a) >>> b[4:0]; // 算术右移
            `ALU_SLT  : c = ($signed(a) < $signed(b)) ? 32'h1 : 32'h0;
            `ALU_SLTU : c = (a < b) ? 32'h1 : 32'h0;
            `ALU_MUL  : c = a * b;
            `ALU_MULH : c = mul_signed_64[63:32];
            `ALU_MULHU: c = mul_unsigned_64[63:32];
            `ALU_DIV  : c = (b == 32'h0) ? $signed(32'h0) : $signed(a) / $signed(b);
            `ALU_DIVU : c = (b == 32'h0) ? 32'h0 : a / b;
            `ALU_MOD  : c = (b == 32'h0) ? $signed(32'h0) : $signed(a) % $signed(b);
            `ALU_MODU : c = (b == 32'h0) ? 32'h0 : a % b;
            default   : c = 32'h0;
        endcase
    end

    // ================================================================
    // 分支条件 br
    // ================================================================
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

    // ================================================================
    // 乘除法 (A组无此需求, 保留接口给B组)
    // ================================================================
    assign mul_flag  = 1'b0;
    assign mulu_flag = 1'b0;
    assign div_flag  = 1'b0;
    assign divu_flag = 1'b0;
    assign busy      = 1'b0;

    always @(posedge clk) begin
        if (mul_flag | mulu_flag | div_flag | divu_flag)
            op_r <= op;
        else if (!busy)
            op_r <= 4'h0;
    end

    multiplier #(32) U_mul (
        .clk    (clk),
        .rst    (rst),
        .x      (a),
        .y      (b),
        .start  (mul_flag),
        .z      (mul_res),
        .busy   (mul_busy)
    );

    multiplier #(33) U_mulu (
        .clk    (clk),
        .rst    (rst),
        .x      ({1'b0, a}),
        .y      ({1'b0, b}),
        .start  (mulu_flag),
        .z      (mulu_res),
        .busy   (mulu_busy)
    );

    divider #(32) U_div (
        .clk    (clk),
        .rst    (rst),
        .x      (a[31] ? {1'b1, ~a[30:0] + 31'h1} : a),
        .y      (b[31] ? {1'b1, ~b[30:0] + 31'h1} : b),
        .start  (div_flag),
        .z      (div_quo),
        .r      (div_rem),
        .busy   (div_busy)
    );

    divider #(33) U_divu (
        .clk    (clk),
        .rst    (rst),
        .x      ({1'b0, a}),
        .y      ({1'b0, b}),
        .start  (divu_flag),
        .z      (divu_quo),
        .r      (divu_rem),
        .busy   (divu_busy)
    );

endmodule
