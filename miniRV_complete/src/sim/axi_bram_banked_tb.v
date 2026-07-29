`timescale 1ns / 1ps

module axi_bram_banked_tb;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg [31:0] awaddr = 32'h0;
    reg awvalid = 1'b0;
    wire awready;
    reg [31:0] wdata = 32'h0;
    reg [3:0] wstrb = 4'h0;
    reg wvalid = 1'b0;
    wire wready;
    wire [1:0] bresp;
    wire bvalid;
    reg bready = 1'b0;
    reg [31:0] araddr = 32'h0;
    reg arvalid = 1'b0;
    wire arready;
    wire [31:0] rdata;
    wire [1:0] rresp;
    wire rlast;
    wire rvalid;
    reg rready = 1'b0;
    integer checks = 0;

    always #10 clk = ~clk;

    axi_bram_slave #(
        .RAM_WORDS (40960),
        .BANK0_INIT_FILE ("coremark_bank0.hex"),
        .BANK1_INIT_FILE ("coremark_bank1.hex"),
        .BANK2_INIT_FILE ("coremark_bank2.hex"),
        .BANK3_INIT_FILE ("coremark_bank3.hex"),
        .BANK4_INIT_FILE ("coremark_bank4.hex")
    ) DUT (
        .clk (clk),
        .rst (rst),
        .s_axi_awaddr (awaddr),
        .s_axi_awlen (8'h0),
        .s_axi_awsize (3'd2),
        .s_axi_awburst (2'b01),
        .s_axi_awvalid (awvalid),
        .s_axi_awready (awready),
        .s_axi_wdata (wdata),
        .s_axi_wstrb (wstrb),
        .s_axi_wlast (1'b1),
        .s_axi_wvalid (wvalid),
        .s_axi_wready (wready),
        .s_axi_bresp (bresp),
        .s_axi_bvalid (bvalid),
        .s_axi_bready (bready),
        .s_axi_araddr (araddr),
        .s_axi_arlen (8'h0),
        .s_axi_arsize (3'd2),
        .s_axi_arburst (2'b01),
        .s_axi_arvalid (arvalid),
        .s_axi_arready (arready),
        .s_axi_rdata (rdata),
        .s_axi_rresp (rresp),
        .s_axi_rlast (rlast),
        .s_axi_rvalid (rvalid),
        .s_axi_rready (rready)
    );

    task axi_write;
        input [31:0] address;
        input [31:0] value;
        input [3:0] strobes;
        begin
            @(negedge clk);
            awaddr = address;
            awvalid = 1'b1;
            wdata = value;
            wstrb = strobes;
            wvalid = 1'b1;
            while (!awready || !wready)
                @(negedge clk);
            @(negedge clk);
            awvalid = 1'b0;
            wvalid = 1'b0;
            bready = 1'b1;
            while (!bvalid)
                @(negedge clk);
            if (bresp != 2'b00)
                $fatal(1, "AXI write response error at %08x", address);
            @(negedge clk);
            bready = 1'b0;
        end
    endtask

    task axi_read_check;
        input [31:0] address;
        input [31:0] expected;
        begin
            @(negedge clk);
            araddr = address;
            arvalid = 1'b1;
            while (!arready)
                @(negedge clk);
            @(negedge clk);
            arvalid = 1'b0;
            rready = 1'b1;
            while (!rvalid)
                @(negedge clk);
            if (rresp != 2'b00 || !rlast)
                $fatal(1, "AXI read response error at %08x", address);
            if (rdata !== expected)
                $fatal(
                    1,
                    "Read mismatch at %08x: got %08x expected %08x",
                    address,
                    rdata,
                    expected
                );
            checks = checks + 1;
            @(negedge clk);
            rready = 1'b0;
        end
    endtask

    initial begin
        repeat (5) @(negedge clk);
        rst = 1'b0;

        axi_write(32'h00000000, 32'h10203040, 4'hF);
        axi_write(32'h00007FFC, 32'h11223344, 4'hF);
        axi_write(32'h00008000, 32'h55667788, 4'hF);
        axi_write(32'h00010000, 32'h99AABBCC, 4'hF);
        axi_write(32'h00018000, 32'hDDEEFF00, 4'hF);
        axi_write(32'h00020000, 32'h13579BDF, 4'hF);
        axi_write(32'h00025800, 32'h2468ACE0, 4'hF);
        axi_write(32'h00027FFC, 32'h0BADF00D, 4'hF);

        axi_read_check(32'h00000000, 32'h10203040);
        axi_read_check(32'h00007FFC, 32'h11223344);
        axi_read_check(32'h00008000, 32'h55667788);
        axi_read_check(32'h00010000, 32'h99AABBCC);
        axi_read_check(32'h00018000, 32'hDDEEFF00);
        axi_read_check(32'h00020000, 32'h13579BDF);
        axi_read_check(32'h00025800, 32'h2468ACE0);
        axi_read_check(32'h00027FFC, 32'h0BADF00D);

        axi_write(32'h00020000, 32'hA1B2C3D4, 4'b0101);
        axi_read_check(32'h00020000, 32'h13B29BD4);
        axi_read_check(32'h00028000, 32'h00000000);

        $display(
            "BANKED BRAM AXI TEST PASSED: %0d checks across all 5 banks",
            checks
        );
        $finish;
    end

endmodule
