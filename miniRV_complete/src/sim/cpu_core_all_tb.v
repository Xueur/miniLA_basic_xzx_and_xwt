`timescale 1ns / 1ps

module cpu_core_all_tb;
    reg clk = 1'b0;
    reg rst = 1'b1;

    wire ifetch_req;
    wire [31:0] ifetch_addr;
    reg ifetch_valid = 1'b0;
    reg [31:0] ifetch_inst = 32'h13;

    wire [3:0] daccess_ren;
    wire [31:0] daccess_addr;
    reg daccess_rvalid = 1'b0;
    reg [31:0] daccess_rdata = 32'h0;
    wire [3:0] daccess_wen;
    wire [31:0] daccess_wdata;
    reg daccess_wresp = 1'b0;

    reg [31:0] imem [0:255];
    reg [31:0] dmem [0:1023];
    reg [31:0] expected_pc [0:72];
    reg [4:0] expected_wb_rd [0:62];
    reg [31:0] expected_wb_data [0:62];

    integer i;
    integer pc_count = 0;
    integer wb_count = 0;

    always #5 clk = ~clk;

    initial begin
        for (i = 0; i < 256; i = i + 1) imem[i] = 32'h00000013;
        for (i = 0; i < 1024; i = i + 1) dmem[i] = 32'h0;
        dmem[384] = 32'h80ff7f01;
        dmem[386] = 32'h11223344;
        dmem[387] = 32'h11223344;
        imem[0] = 32'h60000f13;
        imem[1] = 32'h00700093;
        imem[2] = 32'hffd00113;
        imem[3] = 32'h800001b7;
        imem[4] = 32'h00400213;
        imem[5] = 32'h004092b3;
        imem[6] = 32'h0041d2b3;
        imem[7] = 32'h0041d293;
        imem[8] = 32'h4041d2b3;
        imem[9] = 32'h4041d293;
        imem[10] = 32'h00309293;
        imem[11] = 32'h002082b3;
        imem[12] = 32'h402082b3;
        imem[13] = 32'h00001297;
        imem[14] = 32'h0020c2b3;
        imem[15] = 32'hfff0c293;
        imem[16] = 32'h0020e2b3;
        imem[17] = 32'h1550e293;
        imem[18] = 32'h0020f2b3;
        imem[19] = 32'h0f017293;
        imem[20] = 32'h001122b3;
        imem[21] = 32'h00012293;
        imem[22] = 32'h001132b3;
        imem[23] = 32'hfff0b293;
        imem[24] = 32'h022082b3;
        imem[25] = 32'h80000337;
        imem[26] = 32'hffe00393;
        imem[27] = 32'h027312b3;
        imem[28] = 32'h027332b3;
        imem[29] = 32'h0220c2b3;
        imem[30] = 32'h021152b3;
        imem[31] = 32'h0220e2b3;
        imem[32] = 32'h021172b3;
        imem[33] = 32'h002f0283;
        imem[34] = 32'h003f4283;
        imem[35] = 32'h000f1283;
        imem[36] = 32'h002f5283;
        imem[37] = 32'h000f2283;
        imem[38] = 32'h0000c337;
        imem[39] = 32'heef30313;
        imem[40] = 32'h006f2223;
        imem[41] = 32'h0aa00393;
        imem[42] = 32'h007f04a3;
        imem[43] = 32'h006f1723;
        imem[44] = 32'h004f2283;
        imem[45] = 32'h008f2283;
        imem[46] = 32'h00cf2283;
        imem[47] = 32'h00700393;
        imem[48] = 32'h00100293;
        imem[49] = 32'h00708463;
        imem[50] = 32'h00000293;
        imem[51] = 32'h00028293;
        imem[52] = 32'h00100293;
        imem[53] = 32'h00209463;
        imem[54] = 32'h00000293;
        imem[55] = 32'h00028293;
        imem[56] = 32'h00100293;
        imem[57] = 32'h00114463;
        imem[58] = 32'h00000293;
        imem[59] = 32'h00028293;
        imem[60] = 32'h00100293;
        imem[61] = 32'h0020d463;
        imem[62] = 32'h00000293;
        imem[63] = 32'h00028293;
        imem[64] = 32'h00100293;
        imem[65] = 32'h0020e463;
        imem[66] = 32'h00000293;
        imem[67] = 32'h00028293;
        imem[68] = 32'h00100293;
        imem[69] = 32'h00117463;
        imem[70] = 32'h00000293;
        imem[71] = 32'h00028293;
        imem[72] = 32'h008002ef;
        imem[73] = 32'h00000e13;
        imem[74] = 32'h00100e13;
        imem[75] = 32'h00000317;
        imem[76] = 32'h01130313;
        imem[77] = 32'h000302e7;
        imem[78] = 32'h00000e13;
        imem[79] = 32'h00100e13;
        imem[80] = 32'h00000073;
        expected_pc[0] = 32'h00000000;
        expected_pc[1] = 32'h00000004;
        expected_pc[2] = 32'h00000008;
        expected_pc[3] = 32'h0000000c;
        expected_pc[4] = 32'h00000010;
        expected_pc[5] = 32'h00000014;
        expected_pc[6] = 32'h00000018;
        expected_pc[7] = 32'h0000001c;
        expected_pc[8] = 32'h00000020;
        expected_pc[9] = 32'h00000024;
        expected_pc[10] = 32'h00000028;
        expected_pc[11] = 32'h0000002c;
        expected_pc[12] = 32'h00000030;
        expected_pc[13] = 32'h00000034;
        expected_pc[14] = 32'h00000038;
        expected_pc[15] = 32'h0000003c;
        expected_pc[16] = 32'h00000040;
        expected_pc[17] = 32'h00000044;
        expected_pc[18] = 32'h00000048;
        expected_pc[19] = 32'h0000004c;
        expected_pc[20] = 32'h00000050;
        expected_pc[21] = 32'h00000054;
        expected_pc[22] = 32'h00000058;
        expected_pc[23] = 32'h0000005c;
        expected_pc[24] = 32'h00000060;
        expected_pc[25] = 32'h00000064;
        expected_pc[26] = 32'h00000068;
        expected_pc[27] = 32'h0000006c;
        expected_pc[28] = 32'h00000070;
        expected_pc[29] = 32'h00000074;
        expected_pc[30] = 32'h00000078;
        expected_pc[31] = 32'h0000007c;
        expected_pc[32] = 32'h00000080;
        expected_pc[33] = 32'h00000084;
        expected_pc[34] = 32'h00000088;
        expected_pc[35] = 32'h0000008c;
        expected_pc[36] = 32'h00000090;
        expected_pc[37] = 32'h00000094;
        expected_pc[38] = 32'h00000098;
        expected_pc[39] = 32'h0000009c;
        expected_pc[40] = 32'h000000a0;
        expected_pc[41] = 32'h000000a4;
        expected_pc[42] = 32'h000000a8;
        expected_pc[43] = 32'h000000ac;
        expected_pc[44] = 32'h000000b0;
        expected_pc[45] = 32'h000000b4;
        expected_pc[46] = 32'h000000b8;
        expected_pc[47] = 32'h000000bc;
        expected_pc[48] = 32'h000000c0;
        expected_pc[49] = 32'h000000c4;
        expected_pc[50] = 32'h000000cc;
        expected_pc[51] = 32'h000000d0;
        expected_pc[52] = 32'h000000d4;
        expected_pc[53] = 32'h000000dc;
        expected_pc[54] = 32'h000000e0;
        expected_pc[55] = 32'h000000e4;
        expected_pc[56] = 32'h000000ec;
        expected_pc[57] = 32'h000000f0;
        expected_pc[58] = 32'h000000f4;
        expected_pc[59] = 32'h000000fc;
        expected_pc[60] = 32'h00000100;
        expected_pc[61] = 32'h00000104;
        expected_pc[62] = 32'h0000010c;
        expected_pc[63] = 32'h00000110;
        expected_pc[64] = 32'h00000114;
        expected_pc[65] = 32'h0000011c;
        expected_pc[66] = 32'h00000120;
        expected_pc[67] = 32'h00000128;
        expected_pc[68] = 32'h0000012c;
        expected_pc[69] = 32'h00000130;
        expected_pc[70] = 32'h00000134;
        expected_pc[71] = 32'h0000013c;
        expected_pc[72] = 32'h00000140;
        expected_wb_rd[0] = 5'd30; expected_wb_data[0] = 32'h00000600;
        expected_wb_rd[1] = 5'd1; expected_wb_data[1] = 32'h00000007;
        expected_wb_rd[2] = 5'd2; expected_wb_data[2] = 32'hfffffffd;
        expected_wb_rd[3] = 5'd3; expected_wb_data[3] = 32'h80000000;
        expected_wb_rd[4] = 5'd4; expected_wb_data[4] = 32'h00000004;
        expected_wb_rd[5] = 5'd5; expected_wb_data[5] = 32'h00000070;
        expected_wb_rd[6] = 5'd5; expected_wb_data[6] = 32'h08000000;
        expected_wb_rd[7] = 5'd5; expected_wb_data[7] = 32'h08000000;
        expected_wb_rd[8] = 5'd5; expected_wb_data[8] = 32'hf8000000;
        expected_wb_rd[9] = 5'd5; expected_wb_data[9] = 32'hf8000000;
        expected_wb_rd[10] = 5'd5; expected_wb_data[10] = 32'h00000038;
        expected_wb_rd[11] = 5'd5; expected_wb_data[11] = 32'h00000004;
        expected_wb_rd[12] = 5'd5; expected_wb_data[12] = 32'h0000000a;
        expected_wb_rd[13] = 5'd5; expected_wb_data[13] = 32'h00001034;
        expected_wb_rd[14] = 5'd5; expected_wb_data[14] = 32'hfffffffa;
        expected_wb_rd[15] = 5'd5; expected_wb_data[15] = 32'hfffffff8;
        expected_wb_rd[16] = 5'd5; expected_wb_data[16] = 32'hffffffff;
        expected_wb_rd[17] = 5'd5; expected_wb_data[17] = 32'h00000157;
        expected_wb_rd[18] = 5'd5; expected_wb_data[18] = 32'h00000005;
        expected_wb_rd[19] = 5'd5; expected_wb_data[19] = 32'h000000f0;
        expected_wb_rd[20] = 5'd5; expected_wb_data[20] = 32'h00000001;
        expected_wb_rd[21] = 5'd5; expected_wb_data[21] = 32'h00000001;
        expected_wb_rd[22] = 5'd5; expected_wb_data[22] = 32'h00000000;
        expected_wb_rd[23] = 5'd5; expected_wb_data[23] = 32'h00000001;
        expected_wb_rd[24] = 5'd5; expected_wb_data[24] = 32'hffffffeb;
        expected_wb_rd[25] = 5'd6; expected_wb_data[25] = 32'h80000000;
        expected_wb_rd[26] = 5'd7; expected_wb_data[26] = 32'hfffffffe;
        expected_wb_rd[27] = 5'd5; expected_wb_data[27] = 32'h00000001;
        expected_wb_rd[28] = 5'd5; expected_wb_data[28] = 32'h7fffffff;
        expected_wb_rd[29] = 5'd5; expected_wb_data[29] = 32'hfffffffe;
        expected_wb_rd[30] = 5'd5; expected_wb_data[30] = 32'h24924924;
        expected_wb_rd[31] = 5'd5; expected_wb_data[31] = 32'h00000001;
        expected_wb_rd[32] = 5'd5; expected_wb_data[32] = 32'h00000001;
        expected_wb_rd[33] = 5'd5; expected_wb_data[33] = 32'hffffffff;
        expected_wb_rd[34] = 5'd5; expected_wb_data[34] = 32'h00000080;
        expected_wb_rd[35] = 5'd5; expected_wb_data[35] = 32'h00007f01;
        expected_wb_rd[36] = 5'd5; expected_wb_data[36] = 32'h000080ff;
        expected_wb_rd[37] = 5'd5; expected_wb_data[37] = 32'h80ff7f01;
        expected_wb_rd[38] = 5'd6; expected_wb_data[38] = 32'h0000c000;
        expected_wb_rd[39] = 5'd6; expected_wb_data[39] = 32'h0000beef;
        expected_wb_rd[40] = 5'd7; expected_wb_data[40] = 32'h000000aa;
        expected_wb_rd[41] = 5'd5; expected_wb_data[41] = 32'h0000beef;
        expected_wb_rd[42] = 5'd5; expected_wb_data[42] = 32'h1122aa44;
        expected_wb_rd[43] = 5'd5; expected_wb_data[43] = 32'hbeef3344;
        expected_wb_rd[44] = 5'd7; expected_wb_data[44] = 32'h00000007;
        expected_wb_rd[45] = 5'd5; expected_wb_data[45] = 32'h00000001;
        expected_wb_rd[46] = 5'd5; expected_wb_data[46] = 32'h00000001;
        expected_wb_rd[47] = 5'd5; expected_wb_data[47] = 32'h00000001;
        expected_wb_rd[48] = 5'd5; expected_wb_data[48] = 32'h00000001;
        expected_wb_rd[49] = 5'd5; expected_wb_data[49] = 32'h00000001;
        expected_wb_rd[50] = 5'd5; expected_wb_data[50] = 32'h00000001;
        expected_wb_rd[51] = 5'd5; expected_wb_data[51] = 32'h00000001;
        expected_wb_rd[52] = 5'd5; expected_wb_data[52] = 32'h00000001;
        expected_wb_rd[53] = 5'd5; expected_wb_data[53] = 32'h00000001;
        expected_wb_rd[54] = 5'd5; expected_wb_data[54] = 32'h00000001;
        expected_wb_rd[55] = 5'd5; expected_wb_data[55] = 32'h00000001;
        expected_wb_rd[56] = 5'd5; expected_wb_data[56] = 32'h00000001;
        expected_wb_rd[57] = 5'd5; expected_wb_data[57] = 32'h00000124;
        expected_wb_rd[58] = 5'd28; expected_wb_data[58] = 32'h00000001;
        expected_wb_rd[59] = 5'd6; expected_wb_data[59] = 32'h0000012c;
        expected_wb_rd[60] = 5'd6; expected_wb_data[60] = 32'h0000013d;
        expected_wb_rd[61] = 5'd5; expected_wb_data[61] = 32'h00000138;
        expected_wb_rd[62] = 5'd28; expected_wb_data[62] = 32'h00000001;
        #37 rst = 1'b0;
    end

    always @(posedge clk) begin
        if (rst) begin
            ifetch_valid <= 1'b0;
            daccess_rvalid <= 1'b0;
            daccess_wresp <= 1'b0;
        end else begin
            ifetch_valid <= ifetch_req;
            if (ifetch_req) ifetch_inst <= imem[ifetch_addr[9:2]];

            daccess_rvalid <= |daccess_ren;
            if (|daccess_ren) daccess_rdata <= dmem[daccess_addr[11:2]];
            daccess_wresp <= |daccess_wen;
            if (daccess_wen[0]) dmem[daccess_addr[11:2]][7:0] <= daccess_wdata[7:0];
            if (daccess_wen[1]) dmem[daccess_addr[11:2]][15:8] <= daccess_wdata[15:8];
            if (daccess_wen[2]) dmem[daccess_addr[11:2]][23:16] <= daccess_wdata[23:16];
            if (daccess_wen[3]) dmem[daccess_addr[11:2]][31:24] <= daccess_wdata[31:24];
        end
    end

    always @(negedge clk) begin
        if (!rst) begin
            if (DUT.rf_we1 && DUT.rf_wR != 5'h0) begin
                if (wb_count >= 63) $fatal(1, "WB trace is longer than expected");
                if (DUT.rf_wR !== expected_wb_rd[wb_count] || DUT.rf_wD !== expected_wb_data[wb_count])
                    $fatal(1, "WB mismatch at %0d: got x%0d=%08x expected x%0d=%08x",
                           wb_count, DUT.rf_wR, DUT.rf_wD,
                           expected_wb_rd[wb_count], expected_wb_data[wb_count]);
                wb_count = wb_count + 1;
            end

            if (DUT.memwb_valid && DUT.memwb_inst == 32'h00000073) begin
                if (wb_count != 63) $fatal(1, "WB trace ended early: %0d/63", wb_count);
                if (dmem[385] !== 32'h0000beef) $fatal(1, "SW failed: %08x", dmem[385]);
                if (dmem[386] !== 32'h1122aa44) $fatal(1, "SB failed: %08x", dmem[386]);
                if (dmem[387] !== 32'hbeef3344) $fatal(1, "SH failed: %08x", dmem[387]);
                $display("PIPELINE CPU: ALL 44 miniRV INSTRUCTIONS PASSED");
                $finish;
            end
        end
    end

    initial begin
        #200000;
        $fatal(1, "timeout");
    end

    cpu_core DUT (
        .cpu_rst(rst), .cpu_clk(clk),
        .ifetch_req(ifetch_req), .ifetch_addr(ifetch_addr),
        .ifetch_valid(ifetch_valid), .ifetch_inst(ifetch_inst),
        .daccess_ren(daccess_ren), .daccess_addr(daccess_addr),
        .daccess_rvalid(daccess_rvalid), .daccess_rdata(daccess_rdata),
        .daccess_wen(daccess_wen), .daccess_wdata(daccess_wdata),
        .daccess_wresp(daccess_wresp)
    );
endmodule
