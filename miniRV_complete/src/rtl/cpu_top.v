`timescale 1ns / 1ps

module cpu_top(
    input  wire         clk,
    input  wire         rst,
    input  wire [15:0]  sw,
    output wire [15:0]  led,
    output wire [ 7:0]  dig_en,
    output wire [ 7:0]  dig_seg,
    output wire [ 7:0]  dig_seg1,
    input  wire         rx,
    output wire         tx,

    output wire [31:0]  m_axi_awaddr,
    output wire [ 7:0]  m_axi_awlen,
    output wire [ 2:0]  m_axi_awsize,
    output wire [ 1:0]  m_axi_awburst,
    output wire         m_axi_awvalid,
    input  wire         m_axi_awready,

    output wire [31:0]  m_axi_wdata,
    output wire [ 3:0]  m_axi_wstrb,
    output wire         m_axi_wlast,
    output wire         m_axi_wvalid,
    input  wire         m_axi_wready,

    input  wire [ 1:0]  m_axi_bresp,
    input  wire         m_axi_bvalid,
    output wire         m_axi_bready,

    output wire [31:0]  m_axi_araddr,
    output wire [ 7:0]  m_axi_arlen,
    output wire [ 2:0]  m_axi_arsize,
    output wire [ 1:0]  m_axi_arburst,
    output wire         m_axi_arvalid,
    input  wire         m_axi_arready,

    input  wire [31:0]  m_axi_rdata,
    input  wire [ 1:0]  m_axi_rresp,
    input  wire         m_axi_rlast,
    input  wire         m_axi_rvalid,
    output wire         m_axi_rready
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

    wire cpu_if_req;
    wire [31:0] cpu_if_addr;
    wire cpu_if_valid;
    wire [31:0] cpu_if_inst;

    wire [3:0] cpu_d_ren;
    wire [31:0] cpu_d_addr;
    wire cpu_d_rvalid;
    wire [31:0] cpu_d_rdata;
    wire [3:0] cpu_d_wen;
    wire [31:0] cpu_d_wdata;
    wire cpu_d_wresp;

    wire ic_mem_rrdy;
    wire ic_mem_ren;
    wire [31:0] ic_mem_raddr;
    wire ic_mem_rvalid;
    wire [127:0] ic_mem_rdata;

    wire dc_mem_rrdy;
    wire dc_mem_ren;
    wire [31:0] dc_mem_raddr;
    wire dc_mem_rvalid;
    wire [127:0] dc_mem_rdata;
    wire dc_mem_wrdy;
    wire [3:0] dc_mem_wen;
    wire [31:0] dc_mem_waddr;
    wire [31:0] dc_mem_wdata;

    wire io_ren;
    wire [3:0] io_wen;
    wire [31:0] io_addr;
    wire [31:0] io_wdata;
    wire io_rvalid;
    wire [31:0] io_rdata;
    wire io_wresp;
    wire [31:0] dig_value;

    cpu_core U_core (
        .cpu_rst        (rst),
        .cpu_clk        (clk),
        .ifetch_req     (cpu_if_req),
        .ifetch_addr    (cpu_if_addr),
        .ifetch_valid   (cpu_if_valid),
        .ifetch_inst    (cpu_if_inst),
        .daccess_ren    (cpu_d_ren),
        .daccess_addr   (cpu_d_addr),
        .daccess_rvalid (cpu_d_rvalid),
        .daccess_rdata  (cpu_d_rdata),
        .daccess_wen    (cpu_d_wen),
        .daccess_wdata  (cpu_d_wdata),
        .daccess_wresp  (cpu_d_wresp)
`ifndef RUN_TRACE
        ,
        .debug_wb_valid (debug_wb_valid),
        .debug_wb_inst  (debug_wb_inst),
        .debug_wb_pc    (debug_wb_pc),
        .debug_wb_rf_we (debug_wb_rf_we),
        .debug_wb_rf_wR (debug_wb_rf_wR),
        .debug_wb_rf_wD (debug_wb_rf_wD),
        .debug_mem_pc   (debug_mem_pc),
        .debug_mem_we   (debug_mem_we),
        .debug_mem_waddr(debug_mem_waddr),
        .debug_mem_wdata(debug_mem_wdata)
`endif
    );

    icache U_ICACHE (
        .clk        (clk),
        .rst        (rst),
        .cpu_req    (cpu_if_req),
        .cpu_addr   (cpu_if_addr),
        .cpu_valid  (cpu_if_valid),
        .cpu_data   (cpu_if_inst),
        .mem_rrdy   (ic_mem_rrdy),
        .mem_ren    (ic_mem_ren),
        .mem_raddr  (ic_mem_raddr),
        .mem_rvalid (ic_mem_rvalid),
        .mem_rdata  (ic_mem_rdata)
    );

    dcache U_DCACHE (
        .clk        (clk),
        .rst        (rst),
        .cpu_ren    (cpu_d_ren),
        .cpu_wen    (cpu_d_wen),
        .cpu_addr   (cpu_d_addr),
        .cpu_wdata  (cpu_d_wdata),
        .cpu_rvalid (cpu_d_rvalid),
        .cpu_rdata  (cpu_d_rdata),
        .cpu_wresp  (cpu_d_wresp),
        .mem_rrdy   (dc_mem_rrdy),
        .mem_ren    (dc_mem_ren),
        .mem_raddr  (dc_mem_raddr),
        .mem_rvalid (dc_mem_rvalid),
        .mem_rdata  (dc_mem_rdata),
        .mem_wrdy   (dc_mem_wrdy),
        .mem_wen    (dc_mem_wen),
        .mem_waddr  (dc_mem_waddr),
        .mem_wdata  (dc_mem_wdata),
        .io_ren     (io_ren),
        .io_wen     (io_wen),
        .io_addr    (io_addr),
        .io_wdata   (io_wdata),
        .io_rvalid  (io_rvalid),
        .io_rdata   (io_rdata),
        .io_wresp   (io_wresp)
    );

    axi_master U_AXI_MASTER (
        .clk           (clk),
        .rst           (rst),
        .ic_dev_rrdy   (ic_mem_rrdy),
        .ic_cpu_ren    (ic_mem_ren),
        .ic_cpu_raddr  (ic_mem_raddr),
        .ic_dev_rvalid (ic_mem_rvalid),
        .ic_dev_rdata  (ic_mem_rdata),
        .dc_dev_rrdy   (dc_mem_rrdy),
        .dc_cpu_ren    (dc_mem_ren),
        .dc_cpu_raddr  (dc_mem_raddr),
        .dc_dev_rvalid (dc_mem_rvalid),
        .dc_dev_rdata  (dc_mem_rdata),
        .dc_dev_wrdy   (dc_mem_wrdy),
        .dc_cpu_wen    (dc_mem_wen),
        .dc_cpu_waddr  (dc_mem_waddr),
        .dc_cpu_wdata  (dc_mem_wdata),
        .m_axi_awaddr  (m_axi_awaddr),
        .m_axi_awlen   (m_axi_awlen),
        .m_axi_awsize  (m_axi_awsize),
        .m_axi_awburst (m_axi_awburst),
        .m_axi_awvalid (m_axi_awvalid),
        .m_axi_awready (m_axi_awready),
        .m_axi_wdata   (m_axi_wdata),
        .m_axi_wstrb   (m_axi_wstrb),
        .m_axi_wlast   (m_axi_wlast),
        .m_axi_wvalid  (m_axi_wvalid),
        .m_axi_wready  (m_axi_wready),
        .m_axi_bresp   (m_axi_bresp),
        .m_axi_bvalid  (m_axi_bvalid),
        .m_axi_bready  (m_axi_bready),
        .m_axi_araddr  (m_axi_araddr),
        .m_axi_arlen   (m_axi_arlen),
        .m_axi_arsize  (m_axi_arsize),
        .m_axi_arburst (m_axi_arburst),
        .m_axi_arvalid (m_axi_arvalid),
        .m_axi_arready (m_axi_arready),
        .m_axi_rdata   (m_axi_rdata),
        .m_axi_rresp   (m_axi_rresp),
        .m_axi_rlast   (m_axi_rlast),
        .m_axi_rvalid  (m_axi_rvalid),
        .m_axi_rready  (m_axi_rready)
    );

    io_peripherals #(
        .CLK_FREQ (50000000)
    ) U_IO (
        .clk        (clk),
        .rst        (rst),
        .io_ren     (io_ren),
        .io_wen     (io_wen),
        .io_addr    (io_addr),
        .io_wdata   (io_wdata),
        .io_rvalid  (io_rvalid),
        .io_rdata   (io_rdata),
        .io_wresp   (io_wresp),
        .sw         (sw),
        .led        (led),
        .dig_value  (dig_value),
        .rx         (rx),
        .tx         (tx)
    );

    seven_seg U_SEVEN_SEG (
        .clk      (clk),
        .rst      (rst),
        .value    (dig_value),
        .dig_en   (dig_en),
        .dig_seg  (dig_seg),
        .dig_seg1 (dig_seg1)
    );

endmodule
