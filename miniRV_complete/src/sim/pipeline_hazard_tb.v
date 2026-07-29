`timescale 1ns / 1ps

module pipeline_hazard_tb;

    reg clk = 1'b0;
    reg rst = 1'b1;

    wire ifetch_req;
    wire [31:0] ifetch_addr;
    reg ifetch_valid = 1'b0;
    reg [31:0] ifetch_inst = 32'h00000013;

    wire [3:0] daccess_ren;
    wire [31:0] daccess_addr;
    reg daccess_rvalid = 1'b0;
    reg [31:0] daccess_rdata = 32'h0;
    wire [3:0] daccess_wen;
    wire [31:0] daccess_wdata;
    reg daccess_wresp = 1'b0;

    wire debug_wb_valid;
    wire [31:0] debug_wb_inst;
    wire [31:0] debug_wb_pc;
    wire debug_wb_rf_we;
    wire [4:0] debug_wb_rf_wR;
    wire [31:0] debug_wb_rf_wD;

    reg [31:0] imem [0:31];
    reg [31:0] dmem [0:127];
    integer i;
    integer write_count = 0;
    reg load_use_seen = 1'b0;
    reg redirect_seen = 1'b0;

    always #5 clk = ~clk;

    cpu_core DUT (
        .cpu_rst(rst),
        .cpu_clk(clk),
        .ifetch_req(ifetch_req),
        .ifetch_addr(ifetch_addr),
        .ifetch_valid(ifetch_valid),
        .ifetch_inst(ifetch_inst),
        .daccess_ren(daccess_ren),
        .daccess_addr(daccess_addr),
        .daccess_rvalid(daccess_rvalid),
        .daccess_rdata(daccess_rdata),
        .daccess_wen(daccess_wen),
        .daccess_wdata(daccess_wdata),
        .daccess_wresp(daccess_wresp),
        .debug_wb_valid(debug_wb_valid),
        .debug_wb_inst(debug_wb_inst),
        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_we(debug_wb_rf_we),
        .debug_wb_rf_wR(debug_wb_rf_wR),
        .debug_wb_rf_wD(debug_wb_rf_wD)
    );

    initial begin
        for (i = 0; i < 32; i = i + 1)
            imem[i] = 32'h00000013;
        for (i = 0; i < 128; i = i + 1)
            dmem[i] = 32'h0;

        imem[0] = 32'h10000093;  // addi x1,x0,0x100
        imem[1] = 32'h0000a103;  // lw   x2,0(x1)
        imem[2] = 32'h002101b3;  // add  x3,x2,x2: load-use
        imem[3] = 32'h00218233;  // add  x4,x3,x2: forwarding
        imem[4] = 32'h0040a223;  // sw   x4,4(x1)
        imem[5] = 32'h00420463;  // beq  x4,x4,target
        imem[6] = 32'h00100293;  // wrong path: must be flushed
        imem[7] = 32'h05500293;  // target: addi x5,x0,0x55
        imem[8] = 32'h00000073;  // ecall
        dmem[64] = 32'd7;

        repeat (4) @(posedge clk);
        rst = 1'b0;
    end

    always @(posedge clk) begin
        ifetch_valid <= ifetch_req;
        if (ifetch_req)
            ifetch_inst <= imem[ifetch_addr[6:2]];

        daccess_rvalid <= |daccess_ren;
        if (|daccess_ren)
            daccess_rdata <= dmem[daccess_addr[8:2]];

        daccess_wresp <= |daccess_wen;
        if (daccess_wen[0])
            dmem[daccess_addr[8:2]][7:0] <= daccess_wdata[7:0];
        if (daccess_wen[1])
            dmem[daccess_addr[8:2]][15:8] <= daccess_wdata[15:8];
        if (daccess_wen[2])
            dmem[daccess_addr[8:2]][23:16] <= daccess_wdata[23:16];
        if (daccess_wen[3])
            dmem[daccess_addr[8:2]][31:24] <= daccess_wdata[31:24];

        if (DUT.load_use_stall)
            load_use_seen <= 1'b1;
        if (DUT.ex_redirect)
            redirect_seen <= 1'b1;

        if (debug_wb_rf_we && debug_wb_rf_wR != 0)
            write_count <= write_count + 1;

        if (debug_wb_valid && debug_wb_inst == 32'h00000073) begin
            if (!load_use_seen)
                $fatal(1, "load-use stall was not observed");
            if (!redirect_seen)
                $fatal(1, "branch redirect was not observed");
            if (write_count != 5)
                $fatal(1, "unexpected register write count");
            if (dmem[65] != 32'd21)
                $fatal(1, "store/forward result mismatch");
            $display(
                "HAZARD TEST PASSED: load-use + forwarding + flush"
            );
            $finish;
        end
    end

    initial begin
        #10000;
        $fatal(1, "pipeline hazard test timeout");
    end

endmodule

