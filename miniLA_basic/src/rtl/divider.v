`timescale 1ns / 1ps

// ================================================================
// 恢复余数除法器 (Restoring Division)
// WIDTH 位 ÷ WIDTH 位 → WIDTH 位商 + WIDTH 位余数
// WIDTH 个时钟周期完成
// 接口时序: start 有效 1 拍 → busy 拉高 → 运算中 → busy 变低 → z/r 有效
// 除零处理: 立即返回 z=0, r=0
// ================================================================
module divider #(
    parameter WIDTH = 32
)(
    input  wire               clk,
    input  wire               rst,
    input  wire [WIDTH-1:0]   x,       // 被除数
    input  wire [WIDTH-1:0]   y,       // 除数
    input  wire               start,   // 启动信号，有效 1 拍
    output wire [WIDTH-1:0]   z,       // 商
    output reg  [WIDTH-1:0]   r,       // 余数
    output reg                busy     // 忙标志位
);

    reg [5:0]       count;             // 计数器 0 ~ WIDTH
    reg [WIDTH-1:0] divisor;           // 除数寄存器
    reg [WIDTH:0]   remainder;         // 余数寄存器 (WIDTH+1 位，最高位是借位标志)
    reg [WIDTH-1:0] quotient;          // 商寄存器
    reg [WIDTH-1:0] dividend;          // 被除数寄存器 (用于逐位移入余数)
    reg             div_by_zero;       // 除零标志

    reg [WIDTH-1:0] z_r;
    assign z = z_r;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            busy        <= 1'b0;
            count       <= 6'd0;
            divisor     <= {WIDTH{1'b0}};
            remainder   <= {(WIDTH+1){1'b0}};
            quotient    <= {WIDTH{1'b0}};
            dividend    <= {WIDTH{1'b0}};
            div_by_zero <= 1'b0;
            r           <= {WIDTH{1'b0}};
            z_r         <= {WIDTH{1'b0}};
        end else if (start && !busy) begin
            // ---- 启动：锁存操作数 ----
            if (y == {WIDTH{1'b0}}) begin
                // 除零：立即返回 0
                busy        <= 1'b1;     // 拉高，下一拍就变低
                div_by_zero <= 1'b1;
                count       <= 6'd0;
            end else begin
                busy        <= 1'b1;
                count       <= 6'd0;
                divisor     <= y;
                remainder   <= {(WIDTH+1){1'b0}};
                quotient    <= {WIDTH{1'b0}};
                dividend    <= x;
                div_by_zero <= 1'b0;
            end
        end else if (busy) begin
            if (div_by_zero) begin
                // 除零：直接结束
                busy  <= 1'b0;
                z_r   <= {WIDTH{1'b0}};
                r     <= {WIDTH{1'b0}};
            end else if (count < WIDTH) begin
                // ---- 恢复余数法核心 ----
                // 1. 左移：余数 = {余数[WIDTH-2:0], 被除数最高位}
                remainder <= {remainder[WIDTH-2:0], dividend[WIDTH-1]};
                dividend  <= {dividend[WIDTH-2:0], 1'b0};

                // 2. 试减：余数 = 余数 - 除数
                // 3. 判断：若余数 < 0 (最高位为1)，恢复余数，商上0
                //          若余数 >= 0 (最高位为0)，保留新余数，商上1
                if ({remainder[WIDTH-2:0], dividend[WIDTH-1]} >= {1'b0, divisor}) begin
                    // 够减 → 商上 1，保留减法结果
                    remainder <= {remainder[WIDTH-2:0], dividend[WIDTH-1]} - {1'b0, divisor};
                    quotient  <= {quotient[WIDTH-2:0], 1'b1};
                end else begin
                    // 不够减 → 商上 0，保持原余数
                    quotient <= {quotient[WIDTH-2:0], 1'b0};
                end
                count <= count + 6'd1;
            end else begin
                // ---- 完成 ----
                busy  <= 1'b0;
                z_r   <= quotient;
                r     <= remainder[WIDTH-1:0];
            end
        end
    end

endmodule
