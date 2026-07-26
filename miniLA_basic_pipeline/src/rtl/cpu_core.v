`timescale 1ns / 1ps

`include "defines.vh"

module cpu_core(
    input  wire         cpu_rst,
    input  wire         cpu_clk,

    output wire         ifetch_req   /* verilator public */ ,
    output wire [31:0]  ifetch_addr  /* verilator public */ ,
    input  wire         ifetch_valid /* verilator public */ ,
    input  wire [31:0]  ifetch_inst,

    output wire [ 3:0]  daccess_ren,
    output wire [31:0]  daccess_addr,
    input  wire         daccess_rvalid,
    input  wire [31:0]  daccess_rdata,
    output wire [ 3:0]  daccess_wen,
    output wire [31:0]  daccess_wdata,
    input  wire         daccess_wresp
);

    // ================================================================
    // 全局流水线控制（统一单暂停信号，所有级同步）
    // ================================================================
    wire stall;           // 全局暂停：取指/访存/乘除未完成 → 整条流水线冻结
    wire flush;           // 分支预测失败 → 清空 IF/ID 和 ID/EX

    // ================================================================
    // IF 阶段 — 取指 + PC + NPC
    // ================================================================
    wire [31:0] pc, npc, pc4;
    wire [31:0] inst;

    reg rst_r;
    wire first_req = rst_r & !cpu_rst;
    always @(posedge cpu_clk) rst_r <= cpu_rst;

    // 取指暂停：指令存储器未返回有效数据
    wire if_stall = !ifetch_valid && !first_req;
    
    // 取指请求：复位后首次取指 + 不暂停时持续取指
    assign ifetch_req  = first_req | !stall;
    assign ifetch_addr = pc;

    // 分支排空：冲刷后延迟1拍阻塞IF_ID，排空指令ROM残留错误指令
    reg        flush_drain;
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst)     flush_drain <= 1'b0;
        else if (flush)  flush_drain <= 1'b1;
        else             flush_drain <= 1'b0;
    end

    // NPC 在 EX 段解析分支目标
    wire [ 1:0] ex_npc_op;
    wire        ex_br;
    wire [31:0] ex_alu_c;
    wire [31:0] ex_ext;
    wire [31:0] ex_pc;

    NPC U_NPC (
        .op         (ex_npc_op),
        .pc         (ex_pc),
        .offset     (ex_ext),
        .br         (ex_br),
        .jr_target  (ex_alu_c),
        .npc        (npc),
        .pc4        (pc4)
    );

    PC U_PC (
        .clk        (cpu_clk),
        .rst        (cpu_rst),
        .npc        (npc),
        .fetch      (!stall),
        .pc         (pc)
    );

    // ================================================================
    // IF/ID 流水线寄存器
    // ================================================================
    reg [31:0] IF_ID_inst;
    reg [31:0] IF_ID_pc;
    reg [31:0] IF_ID_pc4;
    reg [31:0] if_pc_delayed;   // 上一拍的pc，与ifetch_inst时序对齐

    always @(posedge cpu_clk) if_pc_delayed <= pc;

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            IF_ID_inst <= 32'h00000000;
            IF_ID_pc   <= 32'h0;
            IF_ID_pc4  <= 32'h0;
        end else if (flush) begin
            // 分支冲刷：清空IF_ID
            IF_ID_inst <= 32'h00000000;
            IF_ID_pc   <= 32'h0;
            IF_ID_pc4  <= 32'h0;
        end else if (flush_drain) begin
            // 排空指令ROM残留的错误指令
        end else if (!stall) begin
            // 正常流动：更新为新取到的指令
            IF_ID_inst <= ifetch_valid ? ifetch_inst : 32'h00000000;
            IF_ID_pc   <= if_pc_delayed;
            IF_ID_pc4  <= if_pc_delayed + 32'h4;
        end
        // stall=1 时保持不变
    end

    // ================================================================
    // ID 阶段 — 译码 + 读寄存器 + 扩展立即数
    // ================================================================
    assign inst = IF_ID_inst;

    wire [ 1:0] id_npc_op;
    wire [ 2:0] id_ext_op;
    wire        id_r2_sel;
    wire        id_alua_sel;
    wire        id_alub_sel;
    wire [ 4:0] id_alu_op;
    wire [ 2:0] id_ram_rop;
    wire [ 3:0] id_ram_wop;
    wire        id_rf_we;
    wire        id_wr_sel;
    wire [ 1:0] id_rf_wsel;

    Controller U_CU (
        .inst_31_15 (inst[31:15]),
        .npc_op     (id_npc_op),
        .ext_op     (id_ext_op),
        .r2_sel     (id_r2_sel),
        .alua_sel   (id_alua_sel),
        .alub_sel   (id_alub_sel),
        .alu_op     (id_alu_op),
        .ram_r_op   (id_ram_rop),
        .ram_w_op   (id_ram_wop),
        .rf_we      (id_rf_we),
        .wr_sel     (id_wr_sel),
        .rf_wsel    (id_rf_wsel)
    );

    wire [ 4:0] id_rs1, id_rs2, id_rd;
    assign id_rs1 = inst[9:5];
    assign id_rs2 = id_r2_sel ? inst[14:10] : inst[4:0];
    // wr_sel: 1=rd(inst[4:0]), 0=r1($ra, bl指令)
    assign id_rd  = id_rf_we ? (id_wr_sel ? inst[4:0] : 5'h1) : 5'h0;

    wire [31:0] id_rD1, id_rD2;
    RF U_RF (
        .clk  (cpu_clk),
        .rR1  (id_rs1),
        .rR2  (id_rs2),
        .rD1  (id_rD1),
        .rD2  (id_rD2),
        .we   (MEM_WB_rf_we),
        .wR   (MEM_WB_rd),
        .wD   (wb_wD)
    );

    wire [31:0] id_ext;
    EXT U_EXT (
        .op  (id_ext_op),
        .imm (inst[25:0]),
        .ext (id_ext)
    );

    // 乘除法判断
    wire id_is_mul_div = (id_alu_op == `ALU_MUL ) | (id_alu_op == `ALU_MULH) | (id_alu_op == `ALU_MULHU)
                       | (id_alu_op == `ALU_DIV ) | (id_alu_op == `ALU_MOD ) | (id_alu_op == `ALU_DIVU) | (id_alu_op == `ALU_MODU);

    // ================================================================
    // ID/EX 流水线寄存器
    // ================================================================
    reg [31:0] ID_EX_pc;
    reg [31:0] ID_EX_pc4;
    reg [31:0] ID_EX_rD1;
    reg [31:0] ID_EX_rD2;
    reg [31:0] ID_EX_ext;
    reg [ 4:0] ID_EX_rs1;
    reg [ 4:0] ID_EX_rs2;
    reg [ 4:0] ID_EX_rd;
    reg [ 4:0] ID_EX_alu_op;
    reg        ID_EX_alua_sel;
    reg        ID_EX_alub_sel;
    reg [ 2:0] ID_EX_ram_rop;
    reg [ 3:0] ID_EX_ram_wop;
    reg        ID_EX_rf_we;
    reg [ 1:0] ID_EX_rf_wsel;
    reg        ID_EX_wr_sel;
    reg [ 1:0] ID_EX_npc_op;
    reg        ID_EX_is_mul_div;

    wire id_bubble = flush;

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            ID_EX_pc      <= 32'h0;
            ID_EX_pc4     <= 32'h0;
            ID_EX_rD1     <= 32'h0;
            ID_EX_rD2     <= 32'h0;
            ID_EX_ext     <= 32'h0;
            ID_EX_rs1     <= 5'h0;
            ID_EX_rs2     <= 5'h0;
            ID_EX_rd      <= 5'h0;
            ID_EX_alu_op  <= `ALU_ADD;
            ID_EX_alua_sel <= `ALUA_R1;
            ID_EX_alub_sel <= `ALUB_R2;
            ID_EX_ram_rop <= `RAM_EXT_N;
            ID_EX_ram_wop <= `RAM_WE_N;
            ID_EX_rf_we   <= 1'b0;
            ID_EX_rf_wsel <= `WB_ALU;
            ID_EX_wr_sel  <= `WR_RD;
            ID_EX_npc_op  <= `NPC_PC4;
            ID_EX_is_mul_div <= 1'b0;
        end else if (id_bubble) begin
            // 分支冲刷 → 插入NOP气泡
            ID_EX_alu_op  <= `ALU_ADD;
            ID_EX_ram_rop <= `RAM_EXT_N;
            ID_EX_ram_wop <= `RAM_WE_N;
            ID_EX_rf_we   <= 1'b0;
            ID_EX_rf_wsel <= `WB_ALU;
            ID_EX_npc_op  <= `NPC_PC4;
            ID_EX_is_mul_div <= 1'b0;
        end else if (!stall) begin
            // 正常流动
            ID_EX_pc      <= IF_ID_pc;
            ID_EX_pc4     <= IF_ID_pc4;
            ID_EX_rD1     <= id_rD1;
            ID_EX_rD2     <= id_rD2;
            ID_EX_ext     <= id_ext;
            ID_EX_rs1     <= id_rs1;
            ID_EX_rs2     <= id_rs2;
            ID_EX_rd      <= id_rd;
            ID_EX_alu_op  <= id_alu_op;
            ID_EX_alua_sel <= id_alua_sel;
            ID_EX_alub_sel <= id_alub_sel;
            ID_EX_ram_rop <= id_ram_rop;
            ID_EX_ram_wop <= id_ram_wop;
            ID_EX_rf_we   <= id_rf_we;
            ID_EX_rf_wsel <= id_rf_wsel;
            ID_EX_wr_sel  <= id_wr_sel;
            ID_EX_npc_op  <= id_npc_op;
            ID_EX_is_mul_div <= id_is_mul_div;
        end
        // stall=1 时保持不变
    end

    // ================================================================
    // EX 阶段 — ALU + 数据前递
    // ================================================================

    // === 前递逻辑 ===
    // EX/MEM 阶段结果前递（优先级更高）
    wire fwd_ex_a = EX_MEM_rf_we && (EX_MEM_rd != 5'h0) && (EX_MEM_rd == ID_EX_rs1);
    wire fwd_ex_b = EX_MEM_rf_we && (EX_MEM_rd != 5'h0) && (EX_MEM_rd == ID_EX_rs2);

    // MEM/WB 阶段结果前递
    wire fwd_mem_a = MEM_WB_rf_we && (MEM_WB_rd != 5'h0) && (MEM_WB_rd == ID_EX_rs1) && !fwd_ex_a;
    wire fwd_mem_b = MEM_WB_rf_we && (MEM_WB_rd != 5'h0) && (MEM_WB_rd == ID_EX_rs2) && !fwd_ex_b;

    wire [31:0] ex_fwd_data  = (EX_MEM_rf_wsel == `WB_PC4) ? EX_MEM_pc4 :
                               (EX_MEM_rf_wsel == `WB_EXT) ? EX_MEM_ext :
                               EX_MEM_alu_c;
    wire [31:0] mem_fwd_data = wb_wD;

    wire [31:0] fwd_a = fwd_ex_a  ? ex_fwd_data :
                        fwd_mem_a ? mem_fwd_data : ID_EX_rD1;
    wire [31:0] fwd_b = fwd_ex_b  ? ex_fwd_data :
                        fwd_mem_b ? mem_fwd_data : ID_EX_rD2;

    // ALU 输入选择
    wire [31:0] alu_a = ID_EX_alua_sel ? fwd_a : ID_EX_pc;
    wire [31:0] alu_b = ID_EX_alub_sel ? fwd_b : ID_EX_ext;

    wire [31:0] alu_c;
    wire        br;
    wire        mul_div_busy;

    ALU U_ALU (
        .rst  (cpu_rst),
        .clk  (cpu_clk),
        .op   (ID_EX_alu_op),
        .a    (alu_a),
        .b    (alu_b),
        .br   (br),
        .c    (alu_c),
        .busy (mul_div_busy)
    );

    // === 分支处理（静态预测不跳） ===
    wire br_taken;
    assign br_taken = (ID_EX_npc_op == `NPC_BRCH && br) ||
                      (ID_EX_npc_op == `NPC_JMP) ||
                      (ID_EX_npc_op == `NPC_JR);

    // flush 组合逻辑输出
    wire flush_cmb = br_taken && !stall;
    assign flush = flush_cmb;

    // NPC 选择：分支跳转用EX段信息，否则默认pc+4
    assign ex_npc_op = flush_cmb ? ID_EX_npc_op : `NPC_PC4;
    assign ex_br     = br;
    assign ex_alu_c  = alu_c;
    assign ex_ext    = ID_EX_ext;
    assign ex_pc     = flush_cmb ? ID_EX_pc : pc;

    // ================================================================
    // EX/MEM 流水线寄存器
    // ================================================================
    reg [31:0] EX_MEM_pc;
    reg [31:0] EX_MEM_pc4;
    reg [31:0] EX_MEM_alu_c;
    reg [31:0] EX_MEM_rD2;
    reg [31:0] EX_MEM_ext;
    reg [ 4:0] EX_MEM_rd;
    reg [ 2:0] EX_MEM_ram_rop;
    reg [ 3:0] EX_MEM_ram_wop;
    reg        EX_MEM_rf_we;
    reg [ 1:0] EX_MEM_rf_wsel;

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            EX_MEM_pc      <= 32'h0;
            EX_MEM_pc4     <= 32'h0;
            EX_MEM_alu_c   <= 32'h0;
            EX_MEM_rD2     <= 32'h0;
            EX_MEM_ext     <= 32'h0;
            EX_MEM_rd      <= 5'h0;
            EX_MEM_ram_rop <= `RAM_EXT_N;
            EX_MEM_ram_wop <= `RAM_WE_N;
            EX_MEM_rf_we   <= 1'b0;
            EX_MEM_rf_wsel <= `WB_ALU;
        end else if (!stall) begin
            // 与前级同步更新
            EX_MEM_pc      <= ID_EX_pc;
            EX_MEM_pc4     <= ID_EX_pc4;
            EX_MEM_alu_c   <= alu_c;
            EX_MEM_rD2     <= fwd_b;
            EX_MEM_ext     <= ID_EX_ext;
            EX_MEM_rd      <= ID_EX_rd;
            EX_MEM_ram_rop <= ID_EX_ram_rop;
            EX_MEM_ram_wop <= ID_EX_ram_wop;
            EX_MEM_rf_we   <= ID_EX_rf_we;
            EX_MEM_rf_wsel <= ID_EX_rf_wsel;
        end
        // stall=1 时保持不变，等待访存/乘除完成
    end

    // ================================================================
    // MEM 阶段 — 访存 + 全局暂停生成
    // ================================================================
    wire [ 3:0] da_ren, da_wen;
    wire [31:0] da_addr, da_wdata, ram_ext;

    MREQ U_MEM_REQ (
        .ram_addr  (EX_MEM_alu_c),
        .ram_rop   (EX_MEM_ram_rop),
        .da_ren    (da_ren),
        .da_addr   (da_addr),
        .ram_wop   (EX_MEM_ram_wop),
        .ram_wdata (EX_MEM_rD2),
        .da_wen    (da_wen),
        .da_wdata  (da_wdata)
    );

    MEXT U_MEM_EXT (
        .op        (EX_MEM_ram_rop),
        .din       (daccess_rdata),
        .byte_offs (EX_MEM_alu_c[1:0]),
        .ext       (ram_ext)
    );

    assign daccess_ren   = da_ren;
    assign daccess_addr  = da_addr;
    assign daccess_wen   = da_wen;
    assign daccess_wdata = da_wdata;

    // 访存暂停：MEM阶段有有效访存且未收到响应
    wire mem_read  = (EX_MEM_ram_rop != `RAM_EXT_N);
    wire mem_write = (EX_MEM_ram_wop != `RAM_WE_N);
    wire mem_stall = (mem_read && !daccess_rvalid) || (mem_write && !daccess_wresp);

    // 乘除法暂停：EX阶段有乘除法且正在执行
    wire mul_stall = ID_EX_is_mul_div && mul_div_busy;

    // 全局统一暂停信号
    assign stall = if_stall | mem_stall | mul_stall;

    // ================================================================
    // MEM/WB 流水线寄存器
    // ================================================================
    reg [31:0] MEM_WB_pc;
    reg [31:0] MEM_WB_alu_c;
    reg [31:0] MEM_WB_ram_ext;
    reg [31:0] MEM_WB_ext;
    reg [31:0] MEM_WB_pc4;
    reg [ 4:0] MEM_WB_rd;
    reg        MEM_WB_rf_we;
    reg [ 1:0] MEM_WB_rf_wsel;

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            MEM_WB_alu_c   <= 32'h0;
            MEM_WB_ram_ext <= 32'h0;
            MEM_WB_ext     <= 32'h0;
            MEM_WB_pc4     <= 32'h0;
            MEM_WB_rd      <= 5'h0;
            MEM_WB_rf_we   <= 1'b0;
            MEM_WB_rf_wsel <= `WB_ALU;
        end else if (!stall) begin
            // 与前级同步更新，确保访存完成后才写回
            MEM_WB_pc      <= EX_MEM_pc;
            MEM_WB_alu_c   <= EX_MEM_alu_c;
            MEM_WB_ram_ext <= ram_ext;
            MEM_WB_ext     <= EX_MEM_ext;
            MEM_WB_pc4     <= EX_MEM_pc4;
            MEM_WB_rd      <= EX_MEM_rd;
            MEM_WB_rf_we   <= EX_MEM_rf_we;
            MEM_WB_rf_wsel <= EX_MEM_rf_wsel;
        end
        // stall=1 时保持不变，防止重复写回
    end

    // ================================================================
    // WB 阶段 — 写回
    // ================================================================
    wire [31:0] wb_wD;
    assign wb_wD = (MEM_WB_rf_wsel == `WB_PC4) ? MEM_WB_pc4 :
                   (MEM_WB_rf_wsel == `WB_RAM) ? MEM_WB_ram_ext :
                   (MEM_WB_rf_wsel == `WB_EXT) ? MEM_WB_ext :
                   MEM_WB_alu_c;

    // ================================================================
    // Debug trace
    // ================================================================
    reg [31:0] dbg_cnt;
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            dbg_cnt <= 0;
        end else begin
            dbg_cnt <= dbg_cnt + 1;
            if (flush)
                $display("[PIPE %d] === FLUSH br_taken=%d npc=%08x stall=%d ===", dbg_cnt, br_taken, npc, stall);
            if (!stall && !flush)
                $display("[PIPE %d] IF->ID pc=%08x inst=%08x valid=%d", dbg_cnt, if_pc_delayed, ifetch_valid ? ifetch_inst : 32'h0, ifetch_valid);
            if (!flush && !stall)
                $display("[PIPE %d] ID->EX pc=%08x inst=%08x rf_we=%d", dbg_cnt, IF_ID_pc, IF_ID_inst, id_rf_we);
            if (!stall)
                $display("[PIPE %d] EX->MEM pc=%08x rf_we=%d", dbg_cnt, ID_EX_pc, ID_EX_rf_we);
            if (MEM_WB_rf_we)
                $display("[PIPE %d] WB pc=%08x rd=%d wD=%08x", dbg_cnt, MEM_WB_pc, MEM_WB_rd, wb_wD);
        end
    end

    // ================================================================
`ifdef RUN_TRACE
    wire [31:0] debug_wb_pc    /* verilator public */ ;
    wire        debug_wb_rf_we /* verilator public */ ;
    wire [ 4:0] debug_wb_rf_wR /* verilator public */ ;
    wire [31:0] debug_wb_rf_wD /* verilator public */ ;
    wire [31:0] debug_mem_pc    /* verilator public */ ;
    wire [ 3:0] debug_mem_we    /* verilator public */ ;
    wire [31:0] debug_mem_waddr /* verilator public */ ;
    wire [31:0] debug_mem_wdata /* verilator public */ ;

    assign debug_wb_pc    = MEM_WB_pc;
    assign debug_wb_rf_we = MEM_WB_rf_we;
    assign debug_wb_rf_wR = MEM_WB_rd;
    assign debug_wb_rf_wD = wb_wD;
    assign debug_mem_pc    = EX_MEM_pc;
    assign debug_mem_we    = da_wen;
    assign debug_mem_waddr = da_addr;
    assign debug_mem_wdata = da_wdata;
`endif

endmodule