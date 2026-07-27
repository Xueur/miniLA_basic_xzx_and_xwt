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
`ifndef RUN_TRACE
    ,
    output wire         debug_wb_valid,
    output wire [31:0]  debug_wb_inst,
    output wire [31:0]  debug_wb_pc,
    output wire         debug_wb_rf_we,
    output wire [ 4:0]  debug_wb_rf_wR,
    output wire [31:0]  debug_wb_rf_wD,
    output wire [31:0]  debug_mem_pc,
    output wire [ 3:0]  debug_mem_we,
    output wire [31:0]  debug_mem_waddr,
    output wire [31:0]  debug_mem_wdata
`endif
);

    localparam NOP = 32'h0000_0013;

    reg  [31:0] fetch_pc;
    reg  [31:0] req_pc_q;
    reg         fetch_outstanding;
    reg         redirect_pending;
    reg  [31:0] redirect_target;
    reg         fetch_buf_valid;
    reg  [31:0] fetch_buf_pc;
    reg  [31:0] fetch_buf_inst;

    reg         ifid_valid;
    reg  [31:0] ifid_pc;
    reg  [31:0] ifid_inst;

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

    reg         memwb_valid;
    reg  [31:0] memwb_pc;
    reg  [31:0] memwb_inst;
    reg  [31:0] memwb_data;
    reg  [ 4:0] memwb_rd;
    reg         memwb_rf_we;

    wire [ 6:0] id_opcode = ifid_inst[6:0];
    wire [ 2:0] id_funct3 = ifid_inst[14:12];
    wire [ 6:0] id_funct7 = ifid_inst[31:25];
    wire [ 4:0] id_rs1 = ifid_inst[19:15];
    wire [ 4:0] id_rs2 = ifid_inst[24:20];
    wire [ 4:0] id_rd  = ifid_inst[11:7];

    wire [ 1:0] id_npc_op;
    wire [ 2:0] id_sext_op;
    wire         id_alua_sel;
    wire         id_alub_sel;
    wire [ 4:0] id_alu_op;
    wire         id_is_mul;
    wire         id_is_div;
    wire [ 2:0] id_ram_rop;
    wire [ 3:0] id_ram_wop;
    wire         id_rf_we;
    wire [ 1:0] id_rf_wsel;
    wire [31:0] id_ext;

    wire id_op_imm = id_opcode == 7'b0010011;
    wire id_op_reg = id_opcode == 7'b0110011;
    wire id_load   = id_opcode == 7'b0000011;
    wire id_store  = id_opcode == 7'b0100011;
    wire id_branch = id_opcode == 7'b1100011;
    wire id_jalr   = id_opcode == 7'b1100111;
    wire id_rs1_used = id_op_imm | id_op_reg | id_load | id_store |
                       id_branch | id_jalr;
    wire id_rs2_used = id_op_reg | id_store | id_branch;

    wire [31:0] rf_rd1;
    wire [31:0] rf_rd2;
    wire        wb_valid = memwb_valid;
    wire        wb_rf_we = memwb_valid && memwb_rf_we && memwb_rd != 5'h0;
    wire [ 4:0] wb_rd = memwb_rd;
    wire [31:0] wb_data = memwb_data;
    wire [31:0] id_rs1_data = wb_rf_we && wb_rd == id_rs1 ? wb_data : rf_rd1;
    wire [31:0] id_rs2_data = wb_rf_we && wb_rd == id_rs2 ? wb_data : rf_rd2;

    Controller U_CU (
        .opcode   (id_opcode),
        .funct3   (id_funct3),
        .funct7   (id_funct7),
        .npc_op   (id_npc_op),
        .sext_op  (id_sext_op),
        .alua_sel (id_alua_sel),
        .alub_sel (id_alub_sel),
        .alu_op   (id_alu_op),
        .is_mul   (id_is_mul),
        .is_div   (id_is_div),
        .ram_r_op (id_ram_rop),
        .ram_w_op (id_ram_wop),
        .rf_we    (id_rf_we),
        .rf_wsel  (id_rf_wsel)
    );

    SEXT U_SEXT (
        .op  (id_sext_op),
        .imm (ifid_inst[31:7]),
        .ext (id_ext)
    );

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

    wire [31:0] alu_a = idex_alua_sel ? idex_pc : ex_rs1_forward;
    wire [31:0] alu_b = idex_alub_sel ? idex_ext : ex_rs2_forward;
    wire        alu_br;
    wire [31:0] alu_c;
    wire        mul_div_busy;
    wire        is_mul_div_ex = idex_is_mul | idex_is_div;
    wire        mul_div_start = idex_valid && is_mul_div_ex &&
                                !idex_md_started;

    ALU U_ALU (
        .rst      (cpu_rst),
        .clk      (cpu_clk),
        .md_start (mul_div_start),
        .op       (idex_alu_op),
        .a        (alu_a),
        .b        (alu_b),
        .c        (alu_c),
        .br       (alu_br),
        .busy     (mul_div_busy)
    );

    wire [31:0] ex_pc4 = idex_pc4;
    wire [31:0] ex_forward_data =
        idex_rf_wsel == `WB_PC4 ? ex_pc4 :
        idex_rf_wsel == `WB_EXT ? idex_ext :
                                  alu_c;
    wire [31:0] ex_target =
        idex_npc_op == `NPC_JALR ? (alu_c & 32'hFFFF_FFFE) :
                                   (idex_pc + idex_ext);
    wire ex_redirect_raw = idex_valid &&
                           (idex_npc_op == `NPC_JMP ||
                            idex_npc_op == `NPC_JALR ||
                           (idex_npc_op == `NPC_BRA && alu_br));

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
    wire mem_done = mem_is_load ? daccess_rvalid :
                    mem_is_store ? daccess_wresp : 1'b1;
    wire mem_wait = mem_is_access && !mem_done;

    assign daccess_ren   = mem_is_load  && !mem_req_sent ? mem_da_ren   : 4'h0;
    assign daccess_wen   = mem_is_store && !mem_req_sent ? mem_da_wen   : 4'h0;
    assign daccess_addr  = mem_da_addr;
    assign daccess_wdata = mem_da_wdata;

    wire mul_div_wait = idex_valid && is_mul_div_ex &&
                        (!idex_md_started || mul_div_busy);
    wire load_use_stall = ifid_valid && idex_valid &&
                          idex_rf_we && idex_rf_wsel == `WB_RAM &&
                          idex_rd != 5'h0 &&
                         ((id_rs1_used && id_rs1 == idex_rd) ||
                          (id_rs2_used && id_rs2 == idex_rd));
    wire ex_redirect = ex_redirect_raw && !mem_wait && !mul_div_wait;
    wire front_stop = mem_wait || mul_div_wait || load_use_stall ||
                      redirect_pending;
    wire fetch_can_replace = !fetch_outstanding || ifetch_valid;
    wire issue_redirect = ex_redirect && fetch_can_replace;
    wire issue_pending_redirect = redirect_pending && fetch_can_replace;
    wire issue_sequential = !ex_redirect && !redirect_pending &&
                            !front_stop && !fetch_buf_valid &&
                            fetch_can_replace;

    assign ifetch_req = !cpu_rst &&
                        (issue_redirect || issue_pending_redirect ||
                         issue_sequential);
    assign ifetch_addr = issue_redirect ? ex_target :
                         issue_pending_redirect ? redirect_target :
                                                  fetch_pc;

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            fetch_pc         <= `PC_INIT_VAL;
            req_pc_q         <= `PC_INIT_VAL;
            fetch_outstanding <= 1'b0;
        end else if (ifetch_req) begin
            req_pc_q          <= ifetch_addr;
            fetch_pc          <= ifetch_addr + 32'h4;
            fetch_outstanding <= 1'b1;
        end else if (ifetch_valid) begin
            fetch_outstanding <= 1'b0;
        end
    end

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

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            fetch_buf_valid <= 1'b0;
            fetch_buf_pc    <= 32'h0;
            fetch_buf_inst  <= NOP;
            ifid_valid      <= 1'b0;
            ifid_pc         <= 32'h0;
            ifid_inst       <= NOP;
        end else if (ex_redirect || redirect_pending) begin
            fetch_buf_valid <= 1'b0;
            ifid_valid      <= 1'b0;
            ifid_inst       <= NOP;
        end else if (front_stop) begin
            if (ifetch_valid && !fetch_buf_valid) begin
                fetch_buf_valid <= 1'b1;
                fetch_buf_pc    <= req_pc_q;
                fetch_buf_inst  <= ifetch_inst;
            end
        end else if (fetch_buf_valid) begin
            ifid_valid <= 1'b1;
            ifid_pc    <= fetch_buf_pc;
            ifid_inst  <= fetch_buf_inst;
            if (ifetch_valid) begin
                fetch_buf_valid <= 1'b1;
                fetch_buf_pc    <= req_pc_q;
                fetch_buf_inst  <= ifetch_inst;
            end else begin
                fetch_buf_valid <= 1'b0;
            end
        end else begin
            ifid_valid <= ifetch_valid;
            ifid_pc    <= req_pc_q;
            ifid_inst  <= ifetch_valid ? ifetch_inst : NOP;
        end
    end

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
            idex_alua_sel   <= `ALU_A_RS1;
            idex_alub_sel   <= `ALU_B_RS2;
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
        end else if (ex_redirect || load_use_stall) begin
            idex_valid      <= 1'b0;
            idex_inst       <= NOP;
            idex_rf_we      <= 1'b0;
            idex_ram_rop    <= `RAM_EXT_N;
            idex_ram_wop    <= `RAM_WE_N;
            idex_is_mul     <= 1'b0;
            idex_is_div     <= 1'b0;
            idex_md_started <= 1'b0;
        end else begin
            idex_valid      <= ifid_valid;
            idex_pc         <= ifid_pc;
            idex_inst       <= ifid_inst;
            idex_pc4        <= ifid_pc + 32'h4;
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
            exmem_valid  <= 1'b0;
            mem_req_sent <= 1'b0;
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

    wire [31:0] pc = req_pc_q;
    wire        rf_we1 = wb_rf_we;
    wire [ 4:0] rf_wR = wb_rd;
    wire [31:0] rf_wD = wb_data;
    wire        inst_finished = memwb_valid;

`ifdef RUN_TRACE
    wire [31:0] debug_wb_pc     /* verilator public */;
    wire        debug_wb_rf_we  /* verilator public */;
    wire [ 4:0] debug_wb_rf_wR  /* verilator public */;
    wire [31:0] debug_wb_rf_wD  /* verilator public */;

    wire [31:0] debug_mem_pc    /* verilator public */;
    wire [ 3:0] debug_mem_we    /* verilator public */;
    wire [31:0] debug_mem_waddr /* verilator public */;
    wire [31:0] debug_mem_wdata /* verilator public */;
`else
    assign debug_wb_valid = memwb_valid;
    assign debug_wb_inst  = memwb_inst;
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
