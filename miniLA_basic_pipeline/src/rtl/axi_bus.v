`timescale 1ns / 1ps

`include "defines.vh"

// ================================================================
// axi_bus — AXI4 Bus Controller
//   Read:  IDLE → SEND_RREQ → WAIT_R → PACKAGE → IDLE
//   Write: IDLE → SEND_WREQ → WAIT_AW → WAIT_W → WAIT_B → IDLE
//   Priority: DCache > ICache
// ================================================================

module axi_bus #(
    parameter IC_BLK_LEN = `IC_BLK_LEN,
    parameter DC_BLK_LEN = `DC_BLK_LEN
)(
    input  wire         aclk,
    input  wire         areset,

    // ---- ICache Interface ----
    output reg          ic_dev_rrdy,
    input  wire         ic_cpu_ren,
    input  wire [31:0]  ic_cpu_raddr,
    output reg          ic_dev_rvalid,
    output reg  [127:0] ic_dev_rdata,

    // ---- DCache Interface ----
    output reg          dc_dev_wrdy,
    input  wire [ 3:0]  dc_cpu_wen,
    input  wire [31:0]  dc_cpu_waddr,
    input  wire [31:0]  dc_cpu_wdata,
    output reg          dc_dev_rrdy,
    input  wire         dc_cpu_ren,
    input  wire [31:0]  dc_cpu_raddr,
    output reg          dc_dev_rvalid,
    output reg  [127:0] dc_dev_rdata,

    // ---- AXI4 Master Interface ----
    output reg  [31:0]  m_axi_awaddr,
    output reg  [ 7:0]  m_axi_awlen,
    output reg  [ 2:0]  m_axi_awsize,
    output reg  [ 1:0]  m_axi_awburst,
    input  wire         m_axi_awready,
    output reg          m_axi_awvalid,
    output reg  [31:0]  m_axi_wdata,
    input  wire         m_axi_wready,
    output reg  [ 3:0]  m_axi_wstrb,
    output reg          m_axi_wlast,
    output reg          m_axi_wvalid,
    output reg          m_axi_bready,
    input  wire [ 1:0]  m_axi_bresp,
    input  wire         m_axi_bvalid,
    output reg  [31:0]  m_axi_araddr,
    output reg  [ 7:0]  m_axi_arlen,
    output reg  [ 2:0]  m_axi_arsize,
    output reg  [ 1:0]  m_axi_arburst,
    input  wire         m_axi_arready,
    output reg          m_axi_arvalid,
    input  wire [31:0]  m_axi_rdata,
    output reg          m_axi_rready,
    input  wire [ 1:0]  m_axi_rresp,
    input  wire         m_axi_rlast,
    input  wire         m_axi_rvalid
);

    // ============================================================
    // Read State Machine: IDLE → SEND_RREQ → WAIT_R → PACKAGE
    // ============================================================
    localparam R_IDLE       = 2'd0;
    localparam R_SEND_RREQ  = 2'd1;
    localparam R_WAIT_R     = 2'd2;
    localparam R_PACKAGE    = 2'd3;

    reg [1:0] r_state, r_nstate;
    reg       rd_for_icache;
    reg [7:0] rd_burst_len;
    reg [7:0] rd_beat_cnt;
    reg [31:0] rd_buf [0:7];

    wire dc_has_rd    = dc_cpu_ren;
    wire ic_has_rd    = ic_cpu_ren;
    wire dc_rd_cached = dc_has_rd && (dc_cpu_raddr[31:16] != 16'hFFFF);

    // Ready — only in IDLE. DCache always priority over IC.
    always @(*) begin
        ic_dev_rrdy = (r_state == R_IDLE) && !dc_has_rd;
        dc_dev_rrdy = (r_state == R_IDLE);
    end

    // Valid — pulsed on last beat
    always @(*) begin
        ic_dev_rvalid = 1'b0;
        dc_dev_rvalid = 1'b0;
        if ((r_state == R_WAIT_R || r_state == R_PACKAGE) && m_axi_rvalid && m_axi_rlast) begin
            if (rd_for_icache) begin
                ic_dev_rvalid = 1'b1;
                $display("[AXI_R] VALID→IC rdata=%08x", m_axi_rdata);
            end else begin
                dc_dev_rvalid = 1'b1;
                $display("[AXI_R] VALID→DC rdata=%08x", m_axi_rdata);
            end
        end
    end

    always @(posedge aclk or posedge areset) begin
        if (areset) r_state <= R_IDLE;
        else begin
            r_state <= r_nstate;
            if (r_state != r_nstate)
                $display("[AXI_R] %d→%d dc_has=%d ic_has=%d dc_cached=%d w_idle=%d ar_rdy=%d r_vld=%d r_last=%d",
                    r_state, r_nstate, dc_has_rd, ic_has_rd, dc_rd_cached, w_state==W_IDLE,
                    m_axi_arready, m_axi_rvalid, m_axi_rlast);
        end
    end

    always @(*) begin
        case (r_state)
            R_IDLE:        if ((dc_has_rd || ic_has_rd) && w_state == W_IDLE) r_nstate = R_SEND_RREQ; else r_nstate = R_IDLE;
            R_SEND_RREQ:   r_nstate = m_axi_arready ? R_WAIT_R : R_SEND_RREQ;
            R_WAIT_R:      r_nstate = m_axi_rvalid ? (m_axi_rlast ? R_IDLE : R_PACKAGE) : R_WAIT_R;
            R_PACKAGE:     r_nstate = m_axi_rvalid ? (m_axi_rlast ? R_IDLE : R_PACKAGE) : R_PACKAGE;
            default:       r_nstate = R_IDLE;
        endcase
    end

    always @(posedge aclk or posedge areset) begin
        if (areset) begin
            rd_for_icache <= 1'b0;
            rd_burst_len  <= 8'd0;
        end else if (r_state == R_IDLE) begin
            if (dc_has_rd) begin
                rd_for_icache <= 1'b0;
                rd_burst_len  <= dc_rd_cached ? DC_BLK_LEN : 8'd1;
            end else if (ic_has_rd) begin
                rd_for_icache <= 1'b1;
                rd_burst_len  <= IC_BLK_LEN;
            end
        end
    end

    // AR channel
    always @(posedge aclk or posedge areset) begin
        if (areset) begin
            m_axi_arvalid <= 1'b0;
            m_axi_araddr  <= 32'h0;
            m_axi_arlen   <= 8'd0;
            m_axi_arsize  <= 3'd2;
            m_axi_arburst <= 2'b01;
        end else begin
            if (r_state == R_IDLE && (dc_has_rd || ic_has_rd)) begin
                m_axi_arvalid <= 1'b1;
                m_axi_arsize  <= 3'd2;
                m_axi_arburst <= 2'b01;
                if (dc_has_rd) begin
                    m_axi_araddr <= dc_rd_cached ? {dc_cpu_raddr[31:4], 4'b0000} : dc_cpu_raddr;
                    m_axi_arlen  <= dc_rd_cached ? (DC_BLK_LEN - 1) : 8'd0;
                end else begin
                    m_axi_araddr <= (IC_BLK_LEN > 1) ? {ic_cpu_raddr[31:4], 4'b0000} : ic_cpu_raddr;
                    m_axi_arlen  <= IC_BLK_LEN - 1;
                end
            end else if (m_axi_arready)
                m_axi_arvalid <= 1'b0;
        end
    end

    // R channel — ready in WAIT_R / PACKAGE
    always @(*) m_axi_rready = (r_state == R_WAIT_R) || (r_state == R_PACKAGE);

    // Beat counter and data accumulation
    always @(posedge aclk or posedge areset) begin
        if (areset) begin
            rd_beat_cnt <= 8'd0;
        end else begin
            if (r_state == R_IDLE)
                rd_beat_cnt <= 8'd0;
            else if (m_axi_rvalid && m_axi_rready)
                rd_beat_cnt <= rd_beat_cnt + 8'd1;
        end
    end

    always @(posedge aclk) begin
        if (m_axi_rvalid && m_axi_rready)
            rd_buf[rd_beat_cnt] <= m_axi_rdata;
    end

    // Output data — use m_axi_rdata for last beat directly, avoids race with rd_buf[3]
    always @(posedge aclk or posedge areset) begin
        if (areset) begin
            ic_dev_rdata <= 128'd0;
            dc_dev_rdata <= 128'd0;
        end else if ((r_state == R_WAIT_R || r_state == R_PACKAGE) && m_axi_rvalid && m_axi_rlast) begin
            if (rd_for_icache)
                ic_dev_rdata <= {m_axi_rdata, rd_buf[2], rd_buf[1], rd_buf[0]};
            else
                dc_dev_rdata <= {m_axi_rdata, rd_buf[2], rd_buf[1], rd_buf[0]};
        end
    end

    // ============================================================
    // Write State Machine: IDLE → SEND_WREQ → WAIT_AW → WAIT_W → WAIT_B
    // ============================================================
    localparam W_IDLE       = 3'd0;
    localparam W_SEND_WREQ  = 3'd1;
    localparam W_WAIT_AW    = 3'd2;   // W already done, waiting for AW
    localparam W_WAIT_W     = 3'd3;   // AW already done, waiting for W
    localparam W_WAIT_B     = 3'd4;

    reg [2:0] w_state, w_nstate;
    reg [31:0] w_addr_r;
    reg [ 3:0] w_wen_r;
    reg [31:0] w_data_r;
    reg        w_done;       // W handshake completed
    reg        aw_done;      // AW handshake completed

    always @(*) begin
        dc_dev_wrdy = (w_state == W_IDLE) && !dc_rd_cached;
    end

    wire r_busy = (r_state != R_IDLE);
    wire w_busy = (w_state != W_IDLE);

    always @(posedge aclk or posedge areset) begin
        if (areset) w_state <= W_IDLE;
        else        w_state <= w_nstate;
    end

    always @(*) begin
        if (m_axi_bvalid) begin
            w_nstate = W_IDLE;  // bvalid ends the write immediately, no matter which state
        end else begin
            case (w_state)
                W_IDLE:      w_nstate = (|dc_cpu_wen) ? W_SEND_WREQ : W_IDLE;
                W_SEND_WREQ: begin
                    if (m_axi_awready && m_axi_wready)     w_nstate = W_IDLE;
                    else if (m_axi_wready && !m_axi_awready) w_nstate = W_WAIT_AW;
                    else if (m_axi_awready && !m_axi_wready) w_nstate = W_WAIT_W;
                    else                                      w_nstate = W_SEND_WREQ;
                end
                W_WAIT_AW:   w_nstate = m_axi_awready ? W_IDLE : W_WAIT_AW;
                W_WAIT_W:    w_nstate = m_axi_wready  ? W_IDLE : W_WAIT_W;
                default:     w_nstate = W_IDLE;
            endcase
        end
    end

    always @(posedge aclk or posedge areset) begin
        if (areset) begin
            m_axi_awvalid <= 1'b0; m_axi_wvalid <= 1'b0; m_axi_wlast <= 1'b0;
            m_axi_bready  <= 1'b0; m_axi_awaddr <= 32'h0; m_axi_awlen <= 8'd0;
            m_axi_awsize  <= 3'd2; m_axi_awburst <= 2'b01; m_axi_wdata <= 32'h0;
            m_axi_wstrb   <= 4'h0; w_done <= 1'b0; aw_done <= 1'b0;
        end else begin
            case (w_state)
                W_IDLE: if (|dc_cpu_wen) begin
                    w_addr_r <= dc_cpu_waddr; w_wen_r <= dc_cpu_wen; w_data_r <= dc_cpu_wdata;
                end
                W_SEND_WREQ: begin
                    m_axi_awaddr  <= w_addr_r;  m_axi_awlen <= 8'd0;
                    m_axi_awsize  <= 3'd2;      m_axi_awburst <= 2'b01;
                    m_axi_awvalid <= 1'b1;      m_axi_wdata  <= w_data_r;
                    m_axi_wstrb   <= w_wen_r;   m_axi_wlast  <= 1'b1;
                    m_axi_wvalid  <= 1'b1;      m_axi_bready <= 1'b1;
                    w_done <= 1'b0; aw_done <= 1'b0;
                end
                W_WAIT_AW: begin
                    m_axi_wvalid <= 1'b0;
                    m_axi_bready <= 1'b1;
                    if (m_axi_awready) m_axi_awvalid <= 1'b0;
                end
                W_WAIT_W: begin
                    m_axi_awvalid <= 1'b0;
                    m_axi_bready <= 1'b1;
                    if (m_axi_wready) m_axi_wvalid <= 1'b0;
                end
                default: begin
                    if (m_axi_bvalid) begin
                        m_axi_bready <= 1'b0;
                        m_axi_wlast  <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule
