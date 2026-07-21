`timescale 1ns / 1ps

// ================================================================
// Booth Radix-2 补码乘法器
// WIDTH 位 × WIDTH 位 → 2*WIDTH 位，WIDTH 个时钟周期完成
// 接口时序: start 有效 1 拍 → busy 拉高 → 运算中 → busy 变低 → z 有效
// ================================================================
module multiplier #(
    parameter WIDTH = 32
)(
    input  wire               clk,
    input  wire               rst,
    input  wire [WIDTH-1:0]   x,       // 被乘数
    input  wire [WIDTH-1:0]   y,       // 乘数
    input  wire               start,   // 启动信号，有效 1 拍
    output reg  [2*WIDTH-1:0] z,       // 乘积 (2*WIDTH 位)
    output wire               busy     // 忙标志位
);

    localparam O_WID = 2 * WIDTH;

    reg [5:0]      count;                // 计数器 0 ~ WIDTH
    reg [WIDTH:0]  A;                    // 累加器 (WIDTH+1 位，含进位)
    reg [WIDTH-1:0] Q;                   // 乘数寄存器
    reg [WIDTH-1:0] M;                   // 被乘数寄存器
    reg            q_1;                  // Booth 额外位
    reg            busy_r;               // 内部 busy 寄存器

    assign busy = busy_r;

    // ---- 组合逻辑：Booth 步骤后的 A 值 (符号扩展 M) ----
    wire [WIDTH:0] A_booth;
    assign A_booth = ({Q[0], q_1} == 2'b01) ? (A + {M[WIDTH-1], M}) :
                     ({Q[0], q_1} == 2'b10) ? (A - {M[WIDTH-1], M}) :
                                              A;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            busy_r <= 1'b0;
            count  <= 6'd0;
            A      <= {(WIDTH+1){1'b0}};
            Q      <= {WIDTH{1'b0}};
            M      <= {WIDTH{1'b0}};
            q_1    <= 1'b0;
            z      <= {O_WID{1'b0}};
        end else if (start && !busy_r) begin
            // 启动：锁存操作数
            busy_r <= 1'b1;
            count  <= 6'd0;
            A      <= {(WIDTH+1){1'b0}};
            Q      <= y;
            M      <= x;
            q_1    <= 1'b0;
        end else if (busy_r) begin
            if (count < WIDTH) begin
                // ---- 算术右移 {A_booth, Q, q_1} >> 1 ----
                q_1   <= Q[0];
                Q     <= {A_booth[0], Q[WIDTH-1:1]};
                A     <= {A_booth[WIDTH], A_booth[WIDTH:1]};
                count <= count + 6'd1;
            end else begin
                // ---- 完成 ----
                busy_r <= 1'b0;
                z      <= {A[WIDTH-1:0], Q};
            end
        end
    end

endmodule
