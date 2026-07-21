`timescale 1ns / 1ps

`include "defines.vh"

// ================================================================
// AXI4 Bus Controller (State Machine)
//   Converts ICache/DCache simple requests into AXI4 transactions.
//   - ICache refill: 4-beat read burst (128 bits)
//   - DCache refill: 4-beat read burst (128 bits)
//   - Uncached read:  1-beat read
//   - Write:          1-beat write
//   Priority: ICache > DCache read > DCache write
// ================================================================

module axi_bus #(
    parameter IC_BLK_LEN = `IC_BLK_LEN,   // burst length for I$ refill (default 4)
    parameter DC_BLK_LEN = `DC_BLK_LEN    // burst length for D$ refill (default 4)
)(
    input  wire         aclk,
    input  wire         areset,         // high active

    // ---- ICache Interface ----
    output wire         ic_dev_rrdy,
    input  wire         ic_cpu_ren,
    input  wire [31:0]  ic_cpu_raddr,
    output wire         ic_dev_rvalid,
    output wire [`IC_BLK_SIZE-1:0] ic_dev_rdata,

    // ---- DCache Interface ----
    output wire         dc_dev_wrdy,
    input  wire [ 3:0]  dc_cpu_wen,
    input  wire [31:0]  dc_cpu_waddr,
    input  wire [31:0]  dc_cpu_wdata,
    output wire         dc_dev_rrdy,
    input  wire         dc_cpu_ren,
    input  wire [31:0]  dc_cpu_raddr,
    output wire         dc_dev_rvalid,
    output wire [`DC_BLK_SIZE-1:0] dc_dev_rdata,

    // ---- AXI4 Master Interface ----
    // Write address channel
    output reg  [31:0]  m_axi_awaddr,
    output reg  [ 7:0]  m_axi_awlen,
    output reg  [ 2:0]  m_axi_awsize,
    output reg  [ 1:0]  m_axi_awburst,
    input  wire         m_axi_awready,
    output reg          m_axi_awvalid,
    // Write data channel
    output reg  [31:0]  m_axi_wdata,
    input  wire         m_axi_wready,
    output reg  [ 3:0]  m_axi_wstrb,
    output reg          m_axi_wlast,
    output reg          m_axi_wvalid,
    // Write response channel
    output reg          m_axi_bready,
    input  wire [ 1:0]  m_axi_bresp,
    input  wire         m_axi_bvalid,
    // Read address channel
    output reg  [31:0]  m_axi_araddr,
    output reg  [ 7:0]  m_axi_arlen,
    output reg  [ 2:0]  m_axi_arsize,
    output reg  [ 1:0]  m_axi_arburst,
    input  wire         m_axi_arready,
    output reg          m_axi_arvalid,
    // Read data channel
    input  wire [31:0]  m_axi_rdata,
    output reg          m_axi_rready,
    input  wire [ 1:0]  m_axi_rresp,
    input  wire         m_axi_rlast,
    input  wire         m_axi_rvalid
);

    // ============================================================
    // State Machine
    // ============================================================
    localparam S_IDLE       = 4'd0;
    localparam S_IC_RD_AR   = 4'd1;   // ICache read: assert AR
    localparam S_IC_RD_DATA = 4'd2;   // ICache read: receive R data (burst)
    localparam S_DC_RD_AR   = 4'd3;   // DCache read: assert AR
    localparam S_DC_RD_DATA = 4'd4;   // DCache read: receive R data (burst or single)
    localparam S_DC_WR_AW   = 4'd5;   // DCache write: assert AW
    localparam S_DC_WR_W    = 4'd6;   // DCache write: send W data
    localparam S_DC_WR_B    = 4'd7;   // DCache write: wait for B

    reg [3:0] state, nstate;

    // Burst beat counter
    reg [7:0] beat_cnt;
    reg       is_cached_rd;       // cached read (4-beat) vs uncached (1-beat)

    // Data accumulation for reads (always 128 bits internally)
    reg [127:0] ic_rdata_buf;
    reg [127:0] dc_rdata_buf;

    // Latched request info
    reg [31:0] ic_raddr_r;
    reg [31:0] dc_raddr_r;
    reg        dc_is_cached_r;
    reg [31:0] dc_waddr_r;
    reg [ 3:0] dc_wen_r;
    reg [31:0] dc_wdata_r;

    // ============================================================
    // Ready signals to caches
    // ============================================================
    wire ic_has_req = ic_cpu_ren;   // active high pulse
    wire dc_has_rd  = dc_cpu_ren;   // active high pulse
    wire dc_has_wr  = |dc_cpu_wen;  // active high pulse

    // Ready when in IDLE and no higher-priority request is pending
    assign ic_dev_rrdy = (state == S_IDLE);
    assign dc_dev_rrdy = (state == S_IDLE) && !ic_has_req;
    assign dc_dev_wrdy = (state == S_IDLE) && !ic_has_req && !dc_has_rd;

    // ============================================================
    // Read data valid to caches
    // ============================================================
    assign ic_dev_rvalid = (state == S_IC_RD_DATA) && m_axi_rvalid && m_axi_rlast;
    assign ic_dev_rdata  = ic_rdata_buf;

    assign dc_dev_rvalid = (state == S_DC_RD_DATA) && m_axi_rvalid && m_axi_rlast;
    assign dc_dev_rdata  = dc_rdata_buf;

    // ============================================================
    // State register
    // ============================================================
    always @(posedge aclk or posedge areset) begin
        if (areset)
            state <= S_IDLE;
        else
            state <= nstate;
    end

    // ============================================================
    // Next state logic + latch requests
    // ============================================================
    always @(*) begin
        nstate = state;
        case (state)
            S_IDLE: begin
                if (ic_has_req)
                    nstate = S_IC_RD_AR;
                else if (dc_has_rd)
                    nstate = S_DC_RD_AR;
                else if (dc_has_wr)
                    nstate = S_DC_WR_AW;
            end
            S_IC_RD_AR:   if (m_axi_arready) nstate = S_IC_RD_DATA;
            S_IC_RD_DATA: if (m_axi_rvalid && m_axi_rlast) nstate = S_IDLE;
            S_DC_RD_AR:   if (m_axi_arready) nstate = S_DC_RD_DATA;
            S_DC_RD_DATA: if (m_axi_rvalid && m_axi_rlast) nstate = S_IDLE;
            S_DC_WR_AW:   if (m_axi_awready) nstate = S_DC_WR_W;
            S_DC_WR_W:    if (m_axi_wready)  nstate = S_DC_WR_B;
            S_DC_WR_B:    if (m_axi_bvalid)  nstate = S_IDLE;
        endcase
    end

    // ============================================================
    // Latch request info on entry to each state
    // ============================================================
    always @(posedge aclk) begin
        if (state == S_IDLE) begin
            if (ic_has_req) begin
                ic_raddr_r <= ic_cpu_raddr;
            end else if (dc_has_rd) begin
                dc_raddr_r     <= dc_cpu_raddr;
                dc_is_cached_r <= (dc_cpu_raddr[31:16] != 16'hFFFF);
            end else if (dc_has_wr) begin
                dc_waddr_r <= dc_cpu_waddr;
                dc_wen_r   <= dc_cpu_wen;
                dc_wdata_r <= dc_cpu_wdata;
            end
        end
    end

    // ============================================================
    // Beat counter
    // ============================================================
    wire rd_last_beat = (beat_cnt == m_axi_arlen);

    always @(posedge aclk or posedge areset) begin
        if (areset) begin
            beat_cnt <= 8'd0;
        end else begin
            if (state == S_IC_RD_AR || state == S_DC_RD_AR)
                beat_cnt <= 8'd0;
            else if (m_axi_rvalid && m_axi_rready)
                beat_cnt <= beat_cnt + 8'd1;
        end
    end

    // ============================================================
    // Read data accumulation
    // ============================================================
    always @(posedge aclk) begin
        if (m_axi_rvalid && m_axi_rready) begin
            case (beat_cnt[2:0])
                3'd0: begin ic_rdata_buf[ 31: 0] <= m_axi_rdata; dc_rdata_buf[ 31: 0] <= m_axi_rdata; end
                3'd1: begin ic_rdata_buf[ 63:32] <= m_axi_rdata; dc_rdata_buf[ 63:32] <= m_axi_rdata; end
                3'd2: begin ic_rdata_buf[ 95:64] <= m_axi_rdata; dc_rdata_buf[ 95:64] <= m_axi_rdata; end
                3'd3: begin ic_rdata_buf[127:96] <= m_axi_rdata; dc_rdata_buf[127:96] <= m_axi_rdata; end
            endcase
        end
    end

    // ============================================================
    // AXI Read Address Channel
    // ============================================================
    always @(posedge aclk or posedge areset) begin
        if (areset) begin
            m_axi_araddr  <= 32'h0;
            m_axi_arlen   <= 8'd0;
            m_axi_arsize  <= 3'd2;
            m_axi_arburst <= 2'b01;
            m_axi_arvalid <= 1'b0;
        end else begin
            if (m_axi_arready) begin
                m_axi_arvalid <= 1'b0;
            end
            case (state)
                S_IDLE: begin
                    if (ic_has_req) begin
                        m_axi_araddr  <= {ic_cpu_raddr[31:4], 4'b0000};
                        m_axi_arlen   <= IC_BLK_LEN - 1;     // 4 beats -> len=3
                        m_axi_arsize  <= 3'd2;               // 4 bytes per beat
                        m_axi_arburst <= 2'b01;              // INCR
                        m_axi_arvalid <= 1'b1;
                    end else if (dc_has_rd) begin
                        m_axi_araddr  <= dc_cpu_raddr;
                        if (dc_cpu_raddr[31:16] == 16'hFFFF) begin
                            // Uncached: single beat
                            m_axi_arlen   <= 8'd0;
                            m_axi_arsize  <= 3'd2;
                        end else begin
                            // Cached: burst
                            m_axi_araddr  <= {dc_cpu_raddr[31:4], 4'b0000};
                            m_axi_arlen   <= DC_BLK_LEN - 1;
                            m_axi_arsize  <= 3'd2;
                        end
                        m_axi_arburst <= 2'b01;
                        m_axi_arvalid <= 1'b1;
                    end
                end
            endcase
        end
    end

    // ============================================================
    // AXI Read Data Channel
    // ============================================================
    always @(*) begin
        m_axi_rready = (state == S_IC_RD_DATA) || (state == S_DC_RD_DATA);
    end

    // ============================================================
    // AXI Write Address Channel
    // ============================================================
    always @(posedge aclk or posedge areset) begin
        if (areset) begin
            m_axi_awaddr  <= 32'h0;
            m_axi_awlen   <= 8'd0;
            m_axi_awsize  <= 3'd2;
            m_axi_awburst <= 2'b01;
            m_axi_awvalid <= 1'b0;
        end else begin
            if (m_axi_awready)
                m_axi_awvalid <= 1'b0;
            if (state == S_IDLE && dc_has_wr && !ic_has_req && !dc_has_rd) begin
                m_axi_awaddr  <= dc_cpu_waddr;
                m_axi_awlen   <= 8'd0;     // single beat
                m_axi_awsize  <= 3'd2;
                m_axi_awburst <= 2'b01;
                m_axi_awvalid <= 1'b1;
            end
        end
    end

    // ============================================================
    // AXI Write Data Channel
    // ============================================================
    always @(posedge aclk or posedge areset) begin
        if (areset) begin
            m_axi_wdata  <= 32'h0;
            m_axi_wstrb  <= 4'h0;
            m_axi_wlast  <= 1'b0;
            m_axi_wvalid <= 1'b0;
        end else begin
            if (m_axi_wready) begin
                m_axi_wvalid <= 1'b0;
                m_axi_wlast  <= 1'b0;
            end
            if (state == S_DC_WR_AW && m_axi_awready) begin
                m_axi_wdata  <= dc_wdata_r;
                m_axi_wstrb  <= dc_wen_r;
                m_axi_wlast  <= 1'b1;      // single beat, last = 1
                m_axi_wvalid <= 1'b1;
            end
        end
    end

    // ============================================================
    // AXI Write Response Channel
    // ============================================================
    always @(posedge aclk or posedge areset) begin
        if (areset)
            m_axi_bready <= 1'b0;
        else
            m_axi_bready <= (state == S_DC_WR_B);
    end

endmodule
