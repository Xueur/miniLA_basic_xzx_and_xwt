`timescale 1ns / 1ps

`include "defines.vh"


//   Read:  IDLE → RADDR → RDATA → IDLE
//   Write: IDLE → WRITE → WRESP → IDLE
//   Priority: DCache > ICache

module axi_bus #(
    parameter IC_BLK_LEN = `IC_BLK_LEN,
    parameter DC_BLK_LEN = `DC_BLK_LEN
)(
    input  wire         aclk,
    input  wire         areset,

    // ---- ICache Interface ----
    output wire         ic_dev_rrdy,
    input  wire         ic_cpu_ren,
    input  wire [31:0]  ic_cpu_raddr,
    output reg          ic_dev_rvalid,
    output reg  [127:0] ic_dev_rdata,

    // ---- DCache Interface ----
    output wire         dc_dev_wrdy,
    input  wire [ 3:0]  dc_cpu_wen,
    input  wire [31:0]  dc_cpu_waddr,
    input  wire [31:0]  dc_cpu_wdata,
    output wire         dc_dev_rrdy,
    input  wire         dc_cpu_ren,
    input  wire [31:0]  dc_cpu_raddr,
    output reg          dc_dev_rvalid,
    output reg  [127:0] dc_dev_rdata,

    // ---- AXI4 Master Interface ----
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

    localparam ST_IDLE   = 3'd0;
    localparam ST_RADDR  = 3'd1;
    localparam ST_RDATA  = 3'd2;
    localparam ST_WRITE  = 3'd3;
    localparam ST_WRESP  = 3'd4;

    reg [2:0] state;
    reg [31:0] read_addr;
    reg        read_is_dc;
    reg [1:0]  read_beat;
    reg [127:0] read_block;

    reg [31:0] write_addr;
    reg [31:0] write_data;
    reg [3:0]  write_strb;
    reg        aw_done;
    reg        w_done;

    wire dc_request = dc_cpu_ren || (|dc_cpu_wen);

    assign dc_dev_rrdy = state == ST_IDLE;
    assign dc_dev_wrdy = state == ST_IDLE;
    assign ic_dev_rrdy = state == ST_IDLE && !dc_request;

    // ---- AXI4 Read Channel ----
    assign m_axi_araddr  = {read_addr[31:4], 4'h0};
    assign m_axi_arlen   = 8'd3;           // 4-beat burst (128 bits)
    assign m_axi_arsize  = 3'd2;           // 4 bytes per beat
    assign m_axi_arburst = 2'b01;          // 递增
    assign m_axi_arvalid = state == ST_RADDR;
    assign m_axi_rready  = state == ST_RDATA;

    // ---- AXI4 Write Channel ----
    assign m_axi_awaddr  = write_addr;
    assign m_axi_awlen   = 8'd0;           // 单拍
    assign m_axi_awsize  = 3'd2;
    assign m_axi_awburst = 2'b01;
    assign m_axi_awvalid = state == ST_WRITE && !aw_done;

    assign m_axi_wdata   = write_data;
    assign m_axi_wstrb   = write_strb;
    assign m_axi_wlast   = 1'b1;
    assign m_axi_wvalid  = state == ST_WRITE && !w_done;
    assign m_axi_bready  = state == ST_WRESP;

    always @(posedge aclk or posedge areset) begin
        if (areset) begin
            state <= ST_IDLE;
            read_addr   <= 32'h0;
            read_is_dc  <= 1'b0;
            read_beat   <= 2'h0;
            read_block  <= 128'h0;
            write_addr  <= 32'h0;
            write_data  <= 32'h0;
            write_strb  <= 4'h0;
            aw_done     <= 1'b0;
            w_done      <= 1'b0;
            ic_dev_rvalid <= 1'b0;
            ic_dev_rdata  <= 128'h0;
            dc_dev_rvalid <= 1'b0;
            dc_dev_rdata  <= 128'h0;
        end else begin
            ic_dev_rvalid <= 1'b0;
            dc_dev_rvalid <= 1'b0;

            case (state)
                ST_IDLE: begin
                    aw_done <= 1'b0;
                    w_done  <= 1'b0;
                    if (|dc_cpu_wen) begin
                        write_addr <= dc_cpu_waddr;
                        write_data <= dc_cpu_wdata;
                        write_strb <= dc_cpu_wen;
                        state <= ST_WRITE;
                    end else if (dc_cpu_ren) begin
                        read_addr  <= dc_cpu_raddr;
                        read_is_dc <= 1'b1;
                        state <= ST_RADDR;
                    end else if (ic_cpu_ren) begin
                        read_addr  <= ic_cpu_raddr;
                        read_is_dc <= 1'b0;
                        state <= ST_RADDR;
                    end
                end

                ST_RADDR: begin
                    if (m_axi_arready) begin
                        read_beat  <= 2'h0;
                        read_block <= 128'h0;
                        state <= ST_RDATA;
                    end
                end

                ST_RDATA: begin
                    if (m_axi_rvalid) begin
                        case (read_beat)
                            2'd0: read_block[31:0]   <= m_axi_rdata;
                            2'd1: read_block[63:32]  <= m_axi_rdata;
                            2'd2: read_block[95:64]  <= m_axi_rdata;
                            default: read_block[127:96] <= m_axi_rdata;
                        endcase

                        if (m_axi_rlast || read_beat == 2'd3) begin
                            if (read_is_dc) begin
                                dc_dev_rdata <= {m_axi_rdata, read_block[95:0]};
                                dc_dev_rvalid <= 1'b1;
                            end else begin
                                ic_dev_rdata <= {m_axi_rdata, read_block[95:0]};
                                ic_dev_rvalid <= 1'b1;
                            end
                            state <= ST_IDLE;
                        end else begin
                            read_beat <= read_beat + 1'b1;
                        end
                    end
                end

                ST_WRITE: begin
                    if (m_axi_awvalid && m_axi_awready)
                        aw_done <= 1'b1;
                    if (m_axi_wvalid && m_axi_wready)
                        w_done <= 1'b1;
                    if ((aw_done || (m_axi_awvalid && m_axi_awready)) &&
                        (w_done || (m_axi_wvalid && m_axi_wready)))
                        state <= ST_WRESP;
                end

                ST_WRESP: begin
                    if (m_axi_bvalid)
                        state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
