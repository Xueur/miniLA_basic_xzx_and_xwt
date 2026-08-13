`timescale 1ns / 1ps

`include "defines.vh"

module cpu_top(
    input  wire         cpu_clk,
    input  wire         cpu_rst,        // high active

    // AXI4 Master Interface
    output wire [31:0]  m_axi_awaddr,
    output wire [ 7:0]  m_axi_awlen,
    output wire [ 2:0]  m_axi_awsize,
    output wire [ 1:0]  m_axi_awburst,
    input  wire         m_axi_awready,
    output wire         m_axi_awvalid,
    output wire [31:0]  m_axi_wdata,
    input  wire         m_axi_wready,
    output wire [ 3:0]  m_axi_wstrb,
    output wire         m_axi_wlast,
    output wire         m_axi_wvalid,
    output wire         m_axi_bready,
    input  wire [ 1:0]  m_axi_bresp,
    input  wire         m_axi_bvalid,
    output wire [31:0]  m_axi_araddr,
    output wire [ 7:0]  m_axi_arlen,
    output wire [ 2:0]  m_axi_arsize,
    output wire [ 1:0]  m_axi_arburst,
    input  wire         m_axi_arready,
    output wire         m_axi_arvalid,
    input  wire [31:0]  m_axi_rdata,
    output wire         m_axi_rready,
    input  wire [ 1:0]  m_axi_rresp,
    input  wire         m_axi_rlast,
    input  wire         m_axi_rvalid
);

    wire        cpu2ic_rreq;
    wire [31:0] cpu2ic_addr;
    wire        ic2cpu_valid;
    wire [31:0] ic2cpu_inst;

    wire [ 3:0] cpu2dc_ren;
    wire [31:0] cpu2dc_addr;
    wire        dc2cpu_valid;
    wire [31:0] dc2cpu_rdata;
    wire [ 3:0] cpu2dc_wen;
    wire [31:0] cpu2dc_wdata;
    wire        dc2cpu_wresp;

    wire        dev2ic_rrdy;
    wire [ 3:0] ic2dev_ren_4b;
    wire [31:0] ic2dev_raddr;
    wire        dev2ic_rvalid;
    wire [127:0] dev2ic_rdata;
    wire        ic2dev_ren = |ic2dev_ren_4b;

    wire        dev2dc_wrdy;
    wire [ 3:0] dc2dev_wen;
    wire [31:0] dc2dev_waddr;
    wire [31:0] dc2dev_wdata;
    wire        dev2dc_rrdy;
    wire [ 3:0] dc2dev_ren_4b;
    wire [31:0] dc2dev_raddr;
    wire        dev2dc_rvalid;
    wire [127:0] dev2dc_rdata;
    wire        dc2dev_ren = |dc2dev_ren_4b;

    cpu_core U_core (
        .cpu_clk        (cpu_clk),
        .cpu_rst        (cpu_rst),
        .ifetch_req     (cpu2ic_rreq),
        .ifetch_addr    (cpu2ic_addr),
        .ifetch_valid   (ic2cpu_valid),
        .ifetch_inst    (ic2cpu_inst),
        .daccess_ren    (cpu2dc_ren),
        .daccess_addr   (cpu2dc_addr),
        .daccess_rvalid (dc2cpu_valid),
        .daccess_rdata  (dc2cpu_rdata),
        .daccess_wen    (cpu2dc_wen),
        .daccess_wdata  (cpu2dc_wdata),
        .daccess_wresp  (dc2cpu_wresp)
    );

    ICache U_icache (
        .cpu_clk        (cpu_clk),
        .cpu_rst        (cpu_rst),
        .inst_rreq      (cpu2ic_rreq),
        .inst_addr      (cpu2ic_addr),
        .inst_valid     (ic2cpu_valid),
        .inst_out       (ic2cpu_inst),
        .dev_rrdy       (dev2ic_rrdy),
        .cpu_ren        (ic2dev_ren_4b),
        .cpu_raddr      (ic2dev_raddr),
        .dev_rvalid     (dev2ic_rvalid),
        .dev_rdata      (dev2ic_rdata)
    );

    DCache U_dcache (
        .cpu_clk        (cpu_clk),
        .cpu_rst        (cpu_rst),
        .data_ren       (cpu2dc_ren),
        .data_addr      (cpu2dc_addr),
        .data_valid     (dc2cpu_valid),
        .data_rdata     (dc2cpu_rdata),
        .data_wen       (cpu2dc_wen),
        .data_wdata     (cpu2dc_wdata),
        .data_wresp     (dc2cpu_wresp),
        .dev_wrdy       (dev2dc_wrdy),
        .cpu_wen        (dc2dev_wen),
        .cpu_waddr      (dc2dev_waddr),
        .cpu_wdata      (dc2dev_wdata),
        .dev_rrdy       (dev2dc_rrdy),
        .cpu_ren        (dc2dev_ren_4b),
        .cpu_raddr      (dc2dev_raddr),
        .dev_rvalid     (dev2dc_rvalid),
        .dev_rdata      (dev2dc_rdata)
    );

    axi_bus U_axibus (
        .aclk           (cpu_clk),
        .areset         (cpu_rst),
        .ic_dev_rrdy    (dev2ic_rrdy),
        .ic_cpu_ren     (ic2dev_ren),
        .ic_cpu_raddr   (ic2dev_raddr),
        .ic_dev_rvalid  (dev2ic_rvalid),
        .ic_dev_rdata   (dev2ic_rdata),
        .dc_dev_wrdy    (dev2dc_wrdy),
        .dc_cpu_wen     (dc2dev_wen),
        .dc_cpu_waddr   (dc2dev_waddr),
        .dc_cpu_wdata   (dc2dev_wdata),
        .dc_dev_rrdy    (dev2dc_rrdy),
        .dc_cpu_ren     (dc2dev_ren),
        .dc_cpu_raddr   (dc2dev_raddr),
        .dc_dev_rvalid  (dev2dc_rvalid),
        .dc_dev_rdata   (dev2dc_rdata),
        .m_axi_awaddr   (m_axi_awaddr),
        .m_axi_awlen    (m_axi_awlen),
        .m_axi_awsize   (m_axi_awsize),
        .m_axi_awburst  (m_axi_awburst),
        .m_axi_awready  (m_axi_awready),
        .m_axi_awvalid  (m_axi_awvalid),
        .m_axi_wdata    (m_axi_wdata),
        .m_axi_wready   (m_axi_wready),
        .m_axi_wstrb    (m_axi_wstrb),
        .m_axi_wlast    (m_axi_wlast),
        .m_axi_wvalid   (m_axi_wvalid),
        .m_axi_bready   (m_axi_bready),
        .m_axi_bresp    (m_axi_bresp),
        .m_axi_bvalid   (m_axi_bvalid),
        .m_axi_araddr   (m_axi_araddr),
        .m_axi_arlen    (m_axi_arlen),
        .m_axi_arsize   (m_axi_arsize),
        .m_axi_arburst  (m_axi_arburst),
        .m_axi_arready  (m_axi_arready),
        .m_axi_arvalid  (m_axi_arvalid),
        .m_axi_rdata    (m_axi_rdata),
        .m_axi_rready   (m_axi_rready),
        .m_axi_rresp    (m_axi_rresp),
        .m_axi_rlast    (m_axi_rlast),
        .m_axi_rvalid   (m_axi_rvalid)
    );

endmodule
