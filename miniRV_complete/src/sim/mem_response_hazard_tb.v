`timescale 1ns / 1ps

module mem_response_hazard_tb;
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
    wire debug_wb_rf_we;
    wire [4:0] debug_wb_rf_wR;
    wire [31:0] debug_wb_rf_wD;

    reg [31:0] imem [0:31];
    reg [31:0] dmem [0:127];
    integer i;
    integer wresp_left = 0;
    integer accepted_writes = 0;
    reg load_result_seen = 1'b0;

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
        .debug_wb_pc(),
        .debug_wb_rf_we(debug_wb_rf_we),
        .debug_wb_rf_wR(debug_wb_rf_wR),
        .debug_wb_rf_wD(debug_wb_rf_wD)
    );

    initial begin
        for (i = 0; i < 32; i = i + 1)
            imem[i] = 32'h00000013;
        for (i = 0; i < 128; i = i + 1)
            dmem[i] = 32'h0;

        imem[0] = 32'h10000093;
        imem[1] = 32'h01100113;
        imem[2] = 32'h02200193;
        imem[3] = 32'h0020a023;
        imem[4] = 32'h0030a223;
        imem[5] = 32'h0040a203;
        imem[6] = 32'h00000073;

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

        if (wresp_left != 0) begin
            daccess_wresp <= 1'b1;
            wresp_left <= wresp_left - 1;
        end else begin
            daccess_wresp <= 1'b0;
        end

        if (|daccess_wen) begin
            if (daccess_wresp)
                $fatal(1, "new write issued while old response is active");
            if (daccess_wen[0])
                dmem[daccess_addr[8:2]][7:0] <= daccess_wdata[7:0];
            if (daccess_wen[1])
                dmem[daccess_addr[8:2]][15:8] <= daccess_wdata[15:8];
            if (daccess_wen[2])
                dmem[daccess_addr[8:2]][23:16] <= daccess_wdata[23:16];
            if (daccess_wen[3])
                dmem[daccess_addr[8:2]][31:24] <= daccess_wdata[31:24];
            accepted_writes <= accepted_writes + 1;
            wresp_left <= 2;
        end

        if (debug_wb_rf_we && debug_wb_rf_wR == 5'd4) begin
            if (debug_wb_rf_wD != 32'h00000022)
                $fatal(1, "load after back-to-back stores returned %08x",
                       debug_wb_rf_wD);
            load_result_seen <= 1'b1;
        end

        if (debug_wb_valid && debug_wb_inst == 32'h00000073) begin
            if (accepted_writes != 2)
                $fatal(1, "expected two accepted stores, got %0d",
                       accepted_writes);
            if (dmem[64] != 32'h00000011 ||
                dmem[65] != 32'h00000022)
                $fatal(1, "back-to-back store data was lost");
            if (!load_result_seen)
                $fatal(1, "load result was not observed");
            $display(
                "MEM RESPONSE HAZARD TEST PASSED: no stale response reuse"
            );
            $finish;
        end
    end

    initial begin
        #10000;
        $fatal(1, "memory response hazard test timeout");
    end
endmodule
