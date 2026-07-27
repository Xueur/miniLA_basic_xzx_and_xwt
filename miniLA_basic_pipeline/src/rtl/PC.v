module PC(
    input wire clk,
    input wire rst,
    input wire flush,   // 新增分支跳转刷新
    input wire fetch,
    input wire [31:0] npc,
    output reg [31:0] pc
);
always @(posedge clk or posedge rst) begin
    if(rst) begin
        pc <= 32'h0;
    end else if(flush) begin
        pc <= npc; // 分支立刻载入跳转地址，同步更新PC
    end else if(fetch) begin
        pc <= npc;
    end
end
endmodule