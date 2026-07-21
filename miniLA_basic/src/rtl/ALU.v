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

    // 硬件乘除法器接口
    wire        mul_flag, mulu_flag;
    wire [63:0] mul_res , mulu_res ;
    wire        mul_busy, mulu_busy;
    wire        div_flag, divu_flag;
    wire [31:0] div_quo , divu_quo ;
    wire [31:0] div_rem , divu_rem ;
    wire        div_busy, divu_busy;
    reg  [ 4:0] op_r;

    // ================================================================
    // 乘除法启动标志位 (组合逻辑, 仅有效 1 拍, 用作硬件模块的 start)
    // ================================================================
    assign mul_flag  = (op == `ALU_MUL) | (op == `ALU_MULH);
    assign mulu_flag = (op == `ALU_MULHU);
    assign div_flag  = (op == `ALU_DIV) | (op == `ALU_MOD);
    assign divu_flag = (op == `ALU_DIVU) | (op == `ALU_MODU);

    // busy: 任一硬件模块正在运算
    assign busy = mul_busy | mulu_busy | div_busy | divu_busy;

    // ================================================================
    // 有符号除法结果的符号修正
    // a[31]/b[31] 在多周期期间会变 (RF读到NOP), 必须在启动时锁存
    // ================================================================
    reg a31_latch, b31_latch;

    wire        div_neg_quo    = a31_latch ^ b31_latch;
    wire [31:0] div_quo_signed = div_neg_quo ? (~div_quo + 1'b1) : div_quo;
    wire [31:0] div_rem_signed = a31_latch ? (~div_rem + 1'b1) : div_rem;

    // ================================================================
    // 运算结果 c (组合逻辑)
    //   op_r != 0 → 乘除法多周期进行中或刚完成 → 读硬件模块输出
    //   op_r == 0 → 普通单周期指令 → 直接组合逻辑计算
    // ================================================================
    always @(*) begin
        case (op_r != 0 ? op_r : op)
            // ---- 单周期运算: 加减/逻辑/移位/比较 ----
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

            // ---- 乘除法: 读硬件模块输出 ----
            `ALU_MUL  : c = mul_res[31:0];        // 有符号乘积低 32 位
            `ALU_MULH : c = mul_res[63:32];        // 有符号乘积高 32 位
            `ALU_MULHU: c = mulu_res[63:32];       // 无符号乘积高 32 位
            `ALU_DIV  : c = div_quo_signed;        // 有符号商 (含符号修正)
            `ALU_DIVU : c = divu_quo[31:0];        // 无符号商
            `ALU_MOD  : c = div_rem_signed;        // 有符号余数 (含符号修正)
            `ALU_MODU : c = divu_rem[31:0];        // 无符号余数

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
    // op_r / 符号锁存: 乘除法启动时锁存
    // ================================================================
    always @(posedge clk) begin
        if (mul_flag | mulu_flag | div_flag | divu_flag)
            op_r <= op;
        else if (!busy)
            op_r <= 5'h0;

        if (div_flag) begin
            a31_latch <= a[31];
            b31_latch <= b[31];
        end
    end

    // ================================================================
    // 硬件乘除法器例化
    // ================================================================

    // 有符号乘法器: 32bit × 32bit → 64bit (补码乘法, 32 周期)
    multiplier #(32) U_mul (
        .clk    (clk),
        .rst    (rst),
        .x      (a),
        .y      (b),
        .start  (mul_flag),
        .z      (mul_res),
        .busy   (mul_busy)
    );

    // 无符号乘法器: 高位补 0 变成 33bit 正数, 复用补码乘法器
    multiplier #(33) U_mulu (
        .clk    (clk),
        .rst    (rst),
        .x      ({1'b0, a}),
        .y      ({1'b0, b}),
        .start  (mulu_flag),
        .z      (mulu_res),
        .busy   (mulu_busy)
    );

    // 有符号除法器: 取绝对值 → 硬件除法 → 符号修正
    divider #(32) U_div (
        .clk    (clk),
        .rst    (rst),
        .x      (a[31] ? (~a + 1'b1) : a),   // |a| (补码取反加一)
        .y      (b[31] ? (~b + 1'b1) : b),   // |b|
        .start  (div_flag),
        .z      (div_quo),
        .r      (div_rem),
        .busy   (div_busy)
    );

    // 无符号除法器: 高位补 0, 33bit 正数
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
