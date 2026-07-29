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
    wire [31:0] bram_awaddr ;
    wire [ 7:0] bram_awlen  ;
    wire [ 2:0] bram_awsize ;
    wire [ 1:0] bram_awburst;
    wire        bram_awvalid;
    wire        bram_awready;
    wire [31:0] bram_wdata  ;
    wire [ 3:0] bram_wstrb  ;
    wire        bram_wlast  ;
    wire        bram_wvalid ;
    wire        bram_wready ;
    wire        bram_bready ;
    wire [ 1:0] bram_bresp  ;
    wire        bram_bvalid ;
    wire [31:0] bram_araddr ;
    wire [ 7:0] bram_arlen  ;
    wire [ 2:0] bram_arsize ;
    wire [ 1:0] bram_arburst;
    wire        bram_arvalid;
    wire        bram_arready;
    wire        bram_rready ;
    wire [31:0] bram_rdata  ;
    wire [ 1:0] bram_rresp  ;
    wire        bram_rlast  ;
    wire        bram_rvalid ;

    // BRAM: address/data pass-through (gated by !IO to avoid AXI protocol violation)
    assign bram_awaddr  = cpu_awaddr ;
    assign bram_awlen   = cpu_awlen  ;
    assign bram_awsize  = cpu_awsize ;
    assign bram_awburst = cpu_awburst;
    assign bram_wdata   = cpu_wdata  ;
    assign bram_wstrb   = cpu_wstrb  ;
    assign bram_wlast   = cpu_wlast  ;
    assign bram_wvalid  = cpu_wvalid && !io_write_req;
    assign bram_bready  = cpu_bready ;
    assign bram_araddr  = cpu_araddr ;
    assign bram_arlen   = cpu_arlen  ;
    assign bram_arsize  = cpu_arsize ;
    assign bram_arburst = cpu_arburst;
    assign bram_rready  = cpu_rready && !io_read_req;

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
        .s_axi_awid     (4'h6),
        .s_axi_awaddr   (bram_awaddr ),
        .s_axi_awlen    (bram_awlen  ),
        .s_axi_awsize   (bram_awsize ),
        .s_axi_awburst  (bram_awburst),
        .s_axi_awready  (bram_awready),
        .s_axi_awvalid  (bram_awvalid),
        .s_axi_wdata    (bram_wdata  ),
        .s_axi_wstrb    (bram_wstrb  ),
        .s_axi_wvalid   (bram_wvalid ),
        .s_axi_wlast    (bram_wlast  ),
        .s_axi_wready   (bram_wready ),
        .s_axi_bready   (bram_bready ),
        .s_axi_bresp    (bram_bresp  ),
        .s_axi_bvalid   (bram_bvalid ),
        .s_axi_arid     (4'h6),
        .s_axi_araddr   (bram_araddr ),
        .s_axi_arlen    (bram_arlen  ),
        .s_axi_arsize   (bram_arsize ),
        .s_axi_arburst  (bram_arburst),
        .s_axi_arready  (bram_arready),
        .s_axi_arvalid  (bram_arvalid),
        .s_axi_rdata    (bram_rdata  ),
        .s_axi_rvalid   (bram_rvalid ),
        .s_axi_rlast    (bram_rlast  ),
        .s_axi_rready   (bram_rready ),
        .s_axi_rresp    (bram_rresp  )
    );

`ifdef BRAM_USE_IP
    // Vivado IP: memory init handled by .mif file, no need for initial block
`else
    // RTL bram_axi (Verilator): load test binary directly into mem array
    initial begin : bram_init
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
`endif

    // ---- IO Peripherals (UART, Timer, LED, Switch, DigitalLED) ----
    wire io_read_req  = cpu_arvalid && cpu_araddr[31:16] == 16'hFFFF;
    wire io_write_req = cpu_awvalid && cpu_awaddr[31:16] == 16'hFFFF;
    wire io_rvalid;
    wire [31:0] io_rdata;
    wire io_wresp;
    wire [31:0] dig_value;

    // Suppress AXI to BRAM when IO access
    assign bram_awvalid = cpu_awvalid && !io_write_req;
    assign bram_arvalid = cpu_arvalid && !io_read_req;

    // Mux read response: IO vs BRAM
    assign cpu_rdata  = io_rvalid ? io_rdata  : bram_rdata;
    assign cpu_rvalid = io_rvalid ? 1'b1      : bram_rvalid;
    assign cpu_rlast  = io_rvalid ? 1'b1      : bram_rlast;
    assign cpu_rresp  = io_rvalid ? 2'b00     : bram_rresp;

    // Mux write response
    assign cpu_bresp  = io_wresp ? 2'b00      : bram_bresp;
    assign cpu_bvalid = io_wresp ? 1'b1       : bram_bvalid;

    // Mux ready: IO is always ready
    assign cpu_awready = io_write_req ? 1'b1  : bram_awready;
    assign cpu_wready  = io_write_req ? 1'b1  : bram_wready;
    assign cpu_arready = io_read_req  ? 1'b1  : bram_arready;

    io_peripherals #(
        .CLK_FREQ   (50000000),
        .UART_BAUD  (115200)
    ) U_IO (
        .clk        (sys_clk),
        .rst        (sys_rst),
        .io_ren     (io_read_req),
        .io_wen     (cpu_wstrb & {4{io_write_req}}),
        .io_addr    (io_read_req ? cpu_araddr : cpu_awaddr),
        .io_wdata   (cpu_wdata),
        .io_rvalid  (io_rvalid),
        .io_rdata   (io_rdata),
        .io_wresp   (io_wresp),
        .sw         (sw[15:0]),
        .led        (led),
        .dig_value  (dig_value),
        .rx         (rx),
        .tx         (tx)
    );

    seven_seg U_SEG (
        .clk        (sys_clk),
        .rst        (sys_rst),
        .value      (dig_value),
        .dig_en     (dig_en),
        .dig_seg    (dig_seg),
        .dig_seg1   (dig_seg1)
    );

endmodule
