`timescale 1ns / 1ps

`include "defines.vh"

module cpu_core(
    input  wire         cpu_rst,
    input  wire         cpu_clk,

    output wire         ifetch_req   /* verilator public */,
    output wire [31:0]  ifetch_addr  /* verilator public */,
    input  wire         ifetch_valid /* verilator public */,
    input  wire [31:0]  ifetch_inst,

    output wire [ 3:0]  daccess_ren,
    output wire [31:0]  daccess_addr,
    input  wire         daccess_rvalid,
    input  wire [31:0]  daccess_rdata,
    output wire [ 3:0]  daccess_wen,
    output wire [31:0]  daccess_wdata,
    input  wire         daccess_wresp
);

    localparam NOP = 32'h03400000;

    // =========================================================================
    // Fetch stage — 脉冲协议取指
    // =========================================================================
    reg  [31:0] fetch_pc;
    reg  [31:0] req_pc_q;
    reg         fetch_outstanding;
    reg         redirect_pending;
    reg  [31:0] redirect_target;
    reg         fetch_buf_valid;
    reg  [31:0] fetch_buf_pc;
    reg  [31:0] fetch_buf_inst;
    reg         first_wb_done;      // 第一条指令 WB 完成标志
    reg         first_fetch_sent;   // 已发出首次取指

    // =========================================================================
    // 当前指令 (组合逻辑, 无 IF/ID 寄存器 — 省 1 拍)
    // =========================================================================
    // 优先消费 fetch_buf, 否则直接使用 ifetch_valid 返回的指令
    wire        id_valid  = fetch_buf_valid || ifetch_valid;
    wire [31:0] id_inst   = fetch_buf_valid ? fetch_buf_inst  : ifetch_inst;
    wire [31:0] id_pc     = fetch_buf_valid ? fetch_buf_pc     : req_pc_q;

    // =========================================================================
    // ID/EX 寄存器
    // =========================================================================
    reg         idex_valid;
    reg  [31:0] idex_pc;
    reg  [31:0] idex_inst;
    reg  [31:0] idex_pc4;
    reg  [31:0] idex_ext;
    reg  [31:0] idex_rs1_data;
    reg  [31:0] idex_rs2_data;
    reg  [ 4:0] idex_rs1;
    reg  [ 4:0] idex_rs2;
    reg  [ 4:0] idex_rd;
    reg  [ 1:0] idex_npc_op;
    reg  [ 1:0] idex_rf_wsel;
    reg  [ 4:0] idex_alu_op;
    reg         idex_alua_sel;
    reg         idex_alub_sel;
    reg  [ 2:0] idex_ram_rop;
    reg  [ 3:0] idex_ram_wop;
    reg         idex_rf_we;
    reg         idex_is_mul;
    reg         idex_is_div;
    reg         idex_md_started;

    // =========================================================================
    // EX/MEM 寄存器
    // =========================================================================
    reg         exmem_valid;
    reg  [31:0] exmem_pc;
    reg  [31:0] exmem_inst;
    reg  [31:0] exmem_alu;
    reg  [31:0] exmem_store_data;
    reg  [31:0] exmem_forward_data;
    reg  [ 4:0] exmem_rd;
    reg  [ 1:0] exmem_rf_wsel;
    reg  [ 2:0] exmem_ram_rop;
    reg  [ 3:0] exmem_ram_wop;
    reg         exmem_rf_we;
    reg         mem_req_sent;

    // =========================================================================
    // MEM/WB 寄存器
    // =========================================================================
    reg         memwb_valid;
    reg  [31:0] memwb_pc;
    reg  [31:0] memwb_inst;
    reg  [31:0] memwb_data;
    reg  [ 4:0] memwb_rd;
    reg         memwb_rf_we;

    // =========================================================================
    // ID 阶段 — 译码 + 读寄存器 (组合逻辑, 直接驱动自 id_inst)
    // =========================================================================

    wire [ 4:0] id_rs1 = id_inst[9:5];

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
        .inst_31_15 (id_inst[31:15]),
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

    wire [ 4:0] id_rs2 = id_r2_sel ? id_inst[14:10] : id_inst[4:0];
    wire [ 4:0] id_rd  = id_rf_we ? (id_wr_sel ? id_inst[4:0] : 5'h1) : 5'h0;

    wire [31:0] id_ext;
    EXT U_EXT (
        .op  (id_ext_op),
        .imm (id_inst[25:0]),
        .ext (id_ext)
    );

    wire id_rs1_used = id_alua_sel && id_rf_wsel != `WB_EXT;
    wire id_rs2_used = id_alub_sel || (id_ram_wop != `RAM_WE_N);

    wire id_is_mul = (id_alu_op == `ALU_MUL ) | (id_alu_op == `ALU_MULH) | (id_alu_op == `ALU_MULHU);
    wire id_is_div = (id_alu_op == `ALU_DIV ) | (id_alu_op == `ALU_MOD ) | (id_alu_op == `ALU_DIVU) | (id_alu_op == `ALU_MODU);

    // --- 寄存器文件 (异步读, WB→ID 直通旁路) ---
    wire [31:0] rf_rd1;
    wire [31:0] rf_rd2;
    wire        wb_rf_we = memwb_valid && memwb_rf_we && memwb_rd != 5'h0;
    wire [ 4:0] wb_rd    = memwb_rd;
    wire [31:0] wb_data  = memwb_data;
    wire [31:0] id_rs1_data = wb_rf_we && wb_rd == id_rs1 ? wb_data : rf_rd1;
    wire [31:0] id_rs2_data = wb_rf_we && wb_rd == id_rs2 ? wb_data : rf_rd2;

    RF U_RF (
        .clk (cpu_clk),
        .rR1 (id_rs1),
        .rR2 (id_rs2),
        .we  (wb_rf_we),
        .wR  (wb_rd),
        .wD  (wb_data),
        .rD1 (rf_rd1),
        .rD2 (rf_rd2)
    );

    // =========================================================================
    // EX 阶段 — ALU + 前递
    // =========================================================================

    wire exmem_forward_valid = exmem_valid && exmem_rf_we &&
                               exmem_rd != 5'h0 &&
                               exmem_rf_wsel != `WB_RAM;
    wire memwb_forward_valid = wb_rf_we;

    wire [31:0] ex_rs1_forward =
        exmem_forward_valid && exmem_rd == idex_rs1 ? exmem_forward_data :
        memwb_forward_valid && memwb_rd == idex_rs1 ? memwb_data :
        idex_rs1_data;
    wire [31:0] ex_rs2_forward =
        exmem_forward_valid && exmem_rd == idex_rs2 ? exmem_forward_data :
        memwb_forward_valid && memwb_rd == idex_rs2 ? memwb_data :
        idex_rs2_data;

    wire [31:0] alu_a = idex_alua_sel ? ex_rs1_forward : idex_pc;
    wire [31:0] alu_b = idex_alub_sel ? ex_rs2_forward : idex_ext;

    wire        alu_br;
    wire [31:0] alu_c;
    wire        mul_div_busy;
    wire        is_mul_div_ex = idex_is_mul | idex_is_div;

    // mul_div_start: 1-cycle pulse when instruction enters execution
    wire mul_div_start = idex_valid && is_mul_div_ex && !idex_md_started;

    ALU U_ALU (
        .rst        (cpu_rst),
        .clk        (cpu_clk),
        .op         (idex_alu_op),
        .a          (alu_a),
        .b          (alu_b),
        .md_start (mul_div_start),
        .c          (alu_c),
        .br         (alu_br),
        .busy       (mul_div_busy)
    );

    wire [31:0] ex_pc4 = idex_pc4;
    wire [31:0] ex_forward_data =
        idex_rf_wsel == `WB_PC4 ? ex_pc4 :
        idex_rf_wsel == `WB_EXT ? idex_ext :
                                  alu_c;

    wire [31:0] ex_target =
        idex_npc_op == `NPC_JR ? (alu_c & 32'hFFFF_FFFE) :
                                 (idex_pc + idex_ext);

    wire ex_redirect_raw = idex_valid &&
                           (idex_npc_op == `NPC_JMP ||
                            idex_npc_op == `NPC_JR  ||
                           (idex_npc_op == `NPC_BRCH && alu_br));

    // =========================================================================
    // MEM 阶段 — 访存
    // =========================================================================

    wire [ 3:0] mem_da_ren;
    wire [31:0] mem_da_addr;
    wire [ 3:0] mem_da_wen;
    wire [31:0] mem_da_wdata;

    MREQ U_MEM_REQ (
        .ram_addr  (exmem_alu),
        .ram_rop   (exmem_ram_rop),
        .da_ren    (mem_da_ren),
        .da_addr   (mem_da_addr),
        .ram_wop   (exmem_ram_wop),
        .ram_wdata (exmem_store_data),
        .da_wen    (mem_da_wen),
        .da_wdata  (mem_da_wdata)
    );

    wire [31:0] mem_load_data;
    MEXT U_MEM_EXT (
        .op        (exmem_ram_rop),
        .din       (daccess_rdata),
        .byte_offs (exmem_alu[1:0]),
        .ext       (mem_load_data)
    );

    wire mem_is_load  = exmem_ram_rop != `RAM_EXT_N;
    wire mem_is_store = exmem_ram_wop != `RAM_WE_N;
    wire mem_is_access = exmem_valid && (mem_is_load || mem_is_store);
    // For loads: only accept daccess_rvalid after request was actually sent
    // (mem_req_sent=1). Prevents spurious completion from stale cache HITs.
    wire mem_done = mem_is_load ? (daccess_rvalid && mem_req_sent) :
                    mem_is_store ? daccess_wresp : 1'b1;
    wire mem_wait = mem_is_access && !mem_done;

    // exmem_just_changed: suppress daccess_ren for 1 cycle after EX/MEM
    // advances, giving exmem_alu time to settle with the new instruction.
    reg [31:0] prev_exmem_pc;
    always @(posedge cpu_clk) begin
        if (cpu_rst) prev_exmem_pc <= 32'h0;
        else         prev_exmem_pc <= exmem_pc;
    end
    wire exmem_just_changed = (exmem_pc != prev_exmem_pc);

    assign daccess_ren   = mem_is_load  && !mem_req_sent && !exmem_just_changed ? mem_da_ren   : 4'h0;
    assign daccess_wen   = mem_is_store && !mem_req_sent && !exmem_just_changed ? mem_da_wen   : 4'h0;
    assign daccess_addr  = mem_da_addr;
    assign daccess_wdata = mem_da_wdata;

    // =========================================================================
    // 流水线控制
    // =========================================================================

    wire mul_div_wait  = idex_valid && is_mul_div_ex &&
                         (!idex_md_started || mul_div_busy);


    // Load-use 停顿: ID 需要的寄存器正被 EX/MEM 阶段的 load 写
    wire load_use_stall = id_valid &&
                         ((idex_valid  && idex_rf_we  && idex_rf_wsel  == `WB_RAM && idex_rd  != 5'h0 &&
                           ((id_rs1_used && id_rs1 == idex_rd ) || (id_rs2_used && id_rs2 == idex_rd ))) ||
                          (exmem_valid && exmem_rf_we && exmem_rf_wsel == `WB_RAM && exmem_rd != 5'h0 &&
                           ((id_rs1_used && id_rs1 == exmem_rd) || (id_rs2_used && id_rs2 == exmem_rd))));

    wire ex_redirect = ex_redirect_raw && !mem_wait && !mul_div_wait;

    wire front_stop = mem_wait || mul_div_wait || load_use_stall ||
                      redirect_pending;

    // first_wb_done=0 时只允许单次取指 (等第一条指令 WB), 之后恢复流水取指
    wire block_until_wb    = first_fetch_sent && !first_wb_done;
    wire fetch_can_replace = first_wb_done ? (!fetch_outstanding || ifetch_valid)
                                           : !fetch_outstanding;
    wire issue_redirect = ex_redirect && fetch_can_replace;
    wire issue_pending_redirect = redirect_pending && fetch_can_replace;
    wire issue_sequential = !ex_redirect && !redirect_pending &&
                            !front_stop && !fetch_buf_valid &&
                            fetch_can_replace && !block_until_wb;

    assign ifetch_req = !cpu_rst &&
                        (issue_redirect || issue_pending_redirect ||
                         issue_sequential);
    assign ifetch_addr = issue_redirect ? ex_target :
                         issue_pending_redirect ? redirect_target :
                                                  fetch_pc;

    // =========================================================================
    // 流水线寄存器更新
    // =========================================================================

    // --- Fetch: PC + 请求追踪 ---
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            fetch_pc          <= `PC_INIT_VAL;
            req_pc_q          <= `PC_INIT_VAL;
            fetch_outstanding <= 1'b0;
            first_fetch_sent  <= 1'b0;
        end else begin
            if (ifetch_req) begin
                req_pc_q          <= ifetch_addr;
                fetch_pc          <= ifetch_addr + 32'h4;
                fetch_outstanding <= 1'b1;
                first_fetch_sent  <= 1'b1;
            end else if (ifetch_valid) begin
                fetch_outstanding <= 1'b0;
            end
        end
    end

    // --- 第一条指令 WB 检测 ---
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst)     first_wb_done <= 1'b0;
        else if (memwb_valid) first_wb_done <= 1'b1;
    end

    // --- 跳转挂起 ---
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            redirect_pending <= 1'b0;
            redirect_target  <= 32'h0;
        end else if (ex_redirect) begin
            redirect_pending <= !fetch_can_replace;
            redirect_target  <= ex_target;
        end else if (issue_pending_redirect) begin
            redirect_pending <= 1'b0;
        end
    end

    // --- fetch_buf 管理 (前端阻塞时的指令缓存) ---
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            fetch_buf_valid <= 1'b0;
            fetch_buf_pc    <= 32'h0;
            fetch_buf_inst  <= NOP;
        end else if (ex_redirect || redirect_pending) begin
            fetch_buf_valid <= 1'b0;
        end else if (front_stop) begin
            // 前端阻塞: 取到的指令暂存入 fetch_buf
            if (ifetch_valid && !fetch_buf_valid) begin
                fetch_buf_valid <= 1'b1;
                fetch_buf_pc    <= req_pc_q;
                fetch_buf_inst  <= ifetch_inst;
            end
        end else if (fetch_buf_valid) begin
            // 消费 fetch_buf
            fetch_buf_valid <= 1'b0;
        end
        // else: 正常流动 — ifetch_valid 直接驱动 id_inst (组合逻辑), 无需缓存
    end

    // --- ID/EX (译码结果在 id_valid 有效的同一拍捕获) ---
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            idex_valid      <= 1'b0;
            idex_pc         <= 32'h0;
            idex_inst       <= NOP;
            idex_pc4        <= 32'h0;
            idex_ext        <= 32'h0;
            idex_rs1_data   <= 32'h0;
            idex_rs2_data   <= 32'h0;
            idex_rs1        <= 5'h0;
            idex_rs2        <= 5'h0;
            idex_rd         <= 5'h0;
            idex_npc_op     <= `NPC_PC4;
            idex_rf_wsel    <= `WB_ALU;
            idex_alu_op     <= `ALU_ADD;
            idex_alua_sel   <= `ALUA_R1;
            idex_alub_sel   <= `ALUB_R2;
            idex_ram_rop    <= `RAM_EXT_N;
            idex_ram_wop    <= `RAM_WE_N;
            idex_rf_we      <= 1'b0;
            idex_is_mul     <= 1'b0;
            idex_is_div     <= 1'b0;
            idex_md_started <= 1'b0;
        end else if (mem_wait) begin
            idex_valid <= idex_valid;
            if (wb_rf_we && wb_rd == idex_rs1)
                idex_rs1_data <= wb_data;
            if (wb_rf_we && wb_rd == idex_rs2)
                idex_rs2_data <= wb_data;
        end else if (mul_div_wait) begin
            idex_valid <= idex_valid;
            if (wb_rf_we && wb_rd == idex_rs1)
                idex_rs1_data <= wb_data;
            if (wb_rf_we && wb_rd == idex_rs2)
                idex_rs2_data <= wb_data;
            if (mul_div_start)
                idex_md_started <= 1'b1;
        end else if (ex_redirect || load_use_stall || redirect_pending) begin
            idex_valid      <= 1'b0;
            idex_inst       <= NOP;
            idex_rf_we      <= 1'b0;
            idex_ram_rop    <= `RAM_EXT_N;
            idex_ram_wop    <= `RAM_WE_N;
            idex_is_mul     <= 1'b0;
            idex_is_div     <= 1'b0;
            idex_md_started <= 1'b0;
        end else begin
            // 正常流动: 从组合逻辑 id_* 直接捕获
            idex_valid      <= id_valid;
            idex_pc         <= id_pc;
            idex_inst       <= id_inst;
            idex_pc4        <= id_pc + 32'h4;
            idex_ext        <= id_ext;
            idex_rs1_data   <= id_rs1_data;
            idex_rs2_data   <= id_rs2_data;
            idex_rs1        <= id_rs1;
            idex_rs2        <= id_rs2;
            idex_rd         <= id_rd;
            idex_npc_op     <= id_npc_op;
            idex_rf_wsel    <= id_rf_wsel;
            idex_alu_op     <= id_alu_op;
            idex_alua_sel   <= id_alua_sel;
            idex_alub_sel   <= id_alub_sel;
            idex_ram_rop    <= id_ram_rop;
            idex_ram_wop    <= id_ram_wop;
            idex_rf_we      <= id_rf_we;
            idex_is_mul     <= id_is_mul;
            idex_is_div     <= id_is_div;
            idex_md_started <= 1'b0;
        end
    end

    // --- EX/MEM ---
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            exmem_valid        <= 1'b0;
            exmem_pc           <= 32'h0;
            exmem_inst         <= NOP;
            exmem_alu          <= 32'h0;
            exmem_store_data   <= 32'h0;
            exmem_forward_data <= 32'h0;
            exmem_rd           <= 5'h0;
            exmem_rf_wsel      <= `WB_ALU;
            exmem_ram_rop      <= `RAM_EXT_N;
            exmem_ram_wop      <= `RAM_WE_N;
            exmem_rf_we        <= 1'b0;
            mem_req_sent       <= 1'b0;
        end else if (mem_wait) begin
            if ((|daccess_ren) || (|daccess_wen))
                mem_req_sent <= 1'b1;
        end else if (mul_div_wait) begin
            exmem_valid        <= 1'b0;
            exmem_ram_rop      <= `RAM_EXT_N;
            exmem_ram_wop      <= `RAM_WE_N;
            mem_req_sent       <= 1'b0;
        end else begin
            exmem_valid        <= idex_valid;
            exmem_pc           <= idex_pc;
            exmem_inst         <= idex_inst;
            exmem_alu          <= alu_c;
            exmem_store_data   <= ex_rs2_forward;
            exmem_forward_data <= ex_forward_data;
            exmem_rd           <= idex_rd;
            exmem_rf_wsel      <= idex_rf_wsel;
            exmem_ram_rop      <= idex_ram_rop;
            exmem_ram_wop      <= idex_ram_wop;
            exmem_rf_we        <= idex_rf_we;
            mem_req_sent       <= 1'b0;
        end
    end

    // --- MEM/WB ---
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            memwb_valid <= 1'b0;
            memwb_pc    <= 32'h0;
            memwb_inst  <= NOP;
            memwb_data  <= 32'h0;
            memwb_rd    <= 5'h0;
            memwb_rf_we <= 1'b0;
        end else if (mem_wait) begin
            memwb_valid <= 1'b0;
            memwb_rf_we <= 1'b0;
        end else begin
            memwb_valid <= exmem_valid;
            memwb_pc    <= exmem_pc;
            memwb_inst  <= exmem_inst;
            memwb_data  <= mem_is_load ? mem_load_data : exmem_forward_data;
            memwb_rd    <= exmem_rd;
            memwb_rf_we <= exmem_rf_we;
        end
    end

    // =========================================================================
    // Debug 信号
    // =========================================================================
`ifdef RUN_TRACE
    wire [31:0] debug_wb_pc     /* verilator public */;
    wire        debug_wb_rf_we  /* verilator public */;
    wire [ 4:0] debug_wb_rf_wR  /* verilator public */;
    wire [31:0] debug_wb_rf_wD  /* verilator public */;

    wire [31:0] debug_mem_pc    /* verilator public */;
    wire [ 3:0] debug_mem_we    /* verilator public */;
    wire [31:0] debug_mem_waddr /* verilator public */;
    wire [31:0] debug_mem_wdata /* verilator public */;
`endif

    assign debug_wb_pc    = memwb_pc;
    assign debug_wb_rf_we = wb_rf_we;
    assign debug_wb_rf_wR = wb_rd;
    assign debug_wb_rf_wD = wb_data;

    assign debug_mem_pc    = exmem_pc;
    assign debug_mem_we    = daccess_wen;
    assign debug_mem_waddr = daccess_addr;
    assign debug_mem_wdata = exmem_store_data;

endmodule
