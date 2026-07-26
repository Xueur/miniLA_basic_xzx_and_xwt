`timescale 1ns / 1ps

`include "defines.vh"

module miniLA_SoC(
    input  wire         fpga_clk,
    input  wire         fpga_rst,   // Low Active
    input  wire [15:0]  sw,
    output wire [15:0]  led,
    output wire [ 7:0]  dig_en,
    output wire [ 7:0]  dig_seg,
    output wire [ 7:0]  dig_seg1,
    input  wire         rx,
    output wire         tx
);

`ifdef RUN_TRACE
    wire sys_clk = fpga_clk;
    wire sys_rst = fpga_rst;
`else
    wire pll_clk1;
    wire pll_lock;
    wire sys_clk = pll_lock & pll_clk1;
    reg  sys_rst;
    always @(posedge fpga_clk) sys_rst <= !fpga_rst | !pll_lock;
    clk_wiz_0 U_clkgen (
        .clk_in1    (fpga_clk),
        .locked     (pll_lock),
        .clk_out1   (pll_clk1)
    );
`endif

    wire [31:0] cpu_awaddr;
    wire [ 7:0] cpu_awlen;
    wire [ 2:0] cpu_awsize;
    wire [ 1:0] cpu_awburst;
    wire        cpu_awvalid, cpu_awready;
    wire [31:0] cpu_wdata;
    wire [ 3:0] cpu_wstrb;
    wire        cpu_wlast, cpu_wvalid, cpu_wready;
    wire        cpu_bready;
    wire [ 1:0] cpu_bresp;
    wire        cpu_bvalid;
    wire [31:0] cpu_araddr;
    wire [ 7:0] cpu_arlen;
    wire [ 2:0] cpu_arsize;
    wire [ 1:0] cpu_arburst;
    wire        cpu_arvalid, cpu_arready;
    wire        cpu_rready;
    wire [31:0] cpu_rdata;
    wire [ 1:0] cpu_rresp;
    wire        cpu_rlast, cpu_rvalid;
    wire [ 3:0] bram_bid, bram_rid;

    cpu_top U_cpu (
        .cpu_clk        (sys_clk),
        .cpu_rst        (sys_rst),
        .m_axi_awaddr   (cpu_awaddr),
        .m_axi_awlen    (cpu_awlen),
        .m_axi_awsize   (cpu_awsize),
        .m_axi_awburst  (cpu_awburst),
        .m_axi_awvalid  (cpu_awvalid),
        .m_axi_awready  (cpu_awready),
        .m_axi_wdata    (cpu_wdata),
        .m_axi_wstrb    (cpu_wstrb),
        .m_axi_wlast    (cpu_wlast),
        .m_axi_wvalid   (cpu_wvalid),
        .m_axi_wready   (cpu_wready),
        .m_axi_bready   (cpu_bready),
        .m_axi_bresp    (cpu_bresp),
        .m_axi_bvalid   (cpu_bvalid),
        .m_axi_araddr   (cpu_araddr),
        .m_axi_arlen    (cpu_arlen),
        .m_axi_arsize   (cpu_arsize),
        .m_axi_arburst  (cpu_arburst),
        .m_axi_arvalid  (cpu_arvalid),
        .m_axi_arready  (cpu_arready),
        .m_axi_rready   (cpu_rready),
        .m_axi_rdata    (cpu_rdata),
        .m_axi_rresp    (cpu_rresp),
        .m_axi_rlast    (cpu_rlast),
        .m_axi_rvalid   (cpu_rvalid)
    );

    bram_axi U_bram (
        .s_aclk         (sys_clk),
        .s_aresetn      (!sys_rst),
        .s_axi_awid     (4'h0),
        .s_axi_awaddr   (cpu_awaddr),
        .s_axi_awlen    (cpu_awlen),
        .s_axi_awsize   (cpu_awsize),
        .s_axi_awburst  (cpu_awburst),
        .s_axi_awlock   (1'b0),
        .s_axi_awcache  (4'h0),
        .s_axi_awprot   (3'h0),
        .s_axi_awready  (cpu_awready),
        .s_axi_awvalid  (cpu_awvalid),
        .s_axi_wdata    (cpu_wdata),
        .s_axi_wstrb    (cpu_wstrb),
        .s_axi_wlast    (cpu_wlast),
        .s_axi_wvalid   (cpu_wvalid),
        .s_axi_wready   (cpu_wready),
        .s_axi_bid      (bram_bid),
        .s_axi_bresp    (cpu_bresp),
        .s_axi_bvalid   (cpu_bvalid),
        .s_axi_bready   (cpu_bready),
        .s_axi_arid     (4'h0),
        .s_axi_araddr   (cpu_araddr),
        .s_axi_arlen    (cpu_arlen),
        .s_axi_arsize   (cpu_arsize),
        .s_axi_arburst  (cpu_arburst),
        .s_axi_arlock   (1'b0),
        .s_axi_arcache  (4'h0),
        .s_axi_arprot   (3'h0),
        .s_axi_arready  (cpu_arready),
        .s_axi_arvalid  (cpu_arvalid),
        .s_axi_rid      (bram_rid),
        .s_axi_rdata    (cpu_rdata),
        .s_axi_rvalid   (cpu_rvalid),
        .s_axi_rlast    (cpu_rlast),
        .s_axi_rready   (cpu_rready),
        .s_axi_rresp    (cpu_rresp)
    );

    // Initialize bram_axi — load test binary into BRAM
    initial begin
        integer fd, i, j;
        reg [31:0] tmp [0:8191];
        fd = $fopen("meminit.bin", "r");
        if (fd) begin
            for (i = 0; i < 8192; i = i + 256)
                for (j = i; j < i + 256 && j < 8192; j = j + 1)
                    tmp[j] = 0;
            $fread(tmp, fd);
            $fclose(fd);
            for (i = 0; i < 8192; i = i + 256)
                for (j = i; j < i + 256 && j < 8192; j = j + 1)
                    U_bram.mem[j] = {tmp[j][7:0], tmp[j][15:8], tmp[j][23:16], tmp[j][31:24]};
        end else begin
            $display("[ERROR] Cannot open meminit.bin!");
        end
    end

    assign led     = 16'h0;
    assign dig_en  = 8'h0;
    assign dig_seg = 8'hFF;
    assign dig_seg1= 8'hFF;
    assign tx      = 1'b1;

endmodule
