`timescale 1ns / 1ps

`include "defines.vh"

// Direct-mapped Data Cache (Write-through + Write-allocate)
//   Capacity: 64 lines x 128 bits = 1KB
//   Line format: {valid(1bit), tag(5bit), data(128bit)} = 134 bits
//   Uncached addresses: 0xFFFF_xxxx (peripherals)

module DCache(
    input  wire         cpu_clk,
    input  wire         cpu_rst,        // high active
    // Interface to CPU
    input  wire [ 3:0]  data_ren,       // read enable
    input  wire [31:0]  data_addr,      // address (read/write shared)
    output reg          data_valid,     // read data valid
    output reg  [31:0]  data_rdata,     // read data to CPU
    input  wire [ 3:0]  data_wen,       // write enable
    input  wire [31:0]  data_wdata,     // write data
    output reg          data_wresp,     // write response
    // Interface to Bus
    input  wire         dev_wrdy,       // bus write ready
    output reg  [ 3:0]  cpu_wen,        // write enable to bus
    output reg  [31:0]  cpu_waddr,      // write address to bus
    output reg  [31:0]  cpu_wdata,      // write data to bus
    input  wire         dev_rrdy,       // bus read ready
    output reg  [ 3:0]  cpu_ren,        // read enable to bus
    output reg  [31:0]  cpu_raddr,      // read address to bus
    input  wire         dev_rvalid,     // bus read data valid
    input  wire [`DC_BLK_SIZE-1:0] dev_rdata  // read data from bus (128 bits)
);

    // Peripherals access should be uncached
    wire uncached = (data_addr[31:16] == 16'hFFFF) && (data_ren != 4'h0 || data_wen != 4'h0);

    function [31:0] pick_word;
        input [127:0] line_data;
        input [  1:0] word_offset;
        begin
            case (word_offset)
                2'b00:   pick_word = line_data[31:0];
                2'b01:   pick_word = line_data[63:32];
                2'b10:   pick_word = line_data[95:64];
                default: pick_word = line_data[127:96];
            endcase
        end
    endfunction

`ifdef ENABLE_DCACHE

    // ---- Read FSM ----
    localparam R_IDLE    = 3'b000;
    localparam R_LOOKUP  = 3'b001;
    localparam R_REFILL  = 3'b010;
    localparam R_UC_REQ  = 3'b011;
    localparam R_UC_WAIT = 3'b100;

    // ---- Write FSM ----
    localparam W_IDLE   = 2'b00;
    localparam W_LOOKUP = 2'b01;
    localparam W_RESP   = 2'b10;

    reg [2:0] r_state, r_nstat;
    reg [1:0] w_state, w_nstat;
    reg [31:0] rd_addr_r, wr_addr_r;
    reg [ 3:0] rd_ren_r,  wr_wen_r;
    reg        rd_uncached_r, wr_uncached_r;
    reg [31:0] wr_data_r;
    reg [127:0] wr_cache_data;

    // Cache storage: 64 lines x 134 bits
    reg [133:0] cache_mem [0:63];

    wire [31:0] active_addr = (w_state != W_IDLE) ? wr_addr_r :
                              (r_state != R_IDLE) ? rd_addr_r : data_addr;
    wire [5:0]  cache_index = active_addr[9:4];
    wire [133:0] cache_line_r = cache_mem[cache_index];

    wire [4:0] tag_from_cpu   = (w_state != W_IDLE) ? wr_addr_r[14:10] : rd_addr_r[14:10];
    wire [1:0] offset         = rd_addr_r[3:2];
    wire       valid_bit      = cache_line_r[133];
    wire [4:0] tag_from_cache = cache_line_r[132:128];

    wire hit_r = (r_state == R_LOOKUP) && !rd_uncached_r && valid_bit && (rd_addr_r[14:10] == tag_from_cache);
    wire hit_w = (w_state == W_LOOKUP) && !wr_uncached_r && valid_bit && (wr_addr_r[14:10] == tag_from_cache);

    // Delay dev_rvalid to avoid race — same fix as ICache
    reg dev_rvalid_d1;
    always @(posedge cpu_clk) begin
        if (cpu_rst) dev_rvalid_d1 <= 1'b0;
        else         dev_rvalid_d1 <= dev_rvalid;
    end

    // ---- Read data output (registered, matches Inst_ROM/Data_RAM timing) ----
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            data_valid <= 1'b0;
            data_rdata <= 32'h0;
        end else begin
            data_valid <= hit_r || ((r_state == R_REFILL) && dev_rvalid_d1) || ((r_state == R_UC_WAIT) && dev_rvalid_d1);
            if ((r_state == R_REFILL) && dev_rvalid_d1)
                data_rdata <= pick_word(dev_rdata, rd_addr_r[3:2]);
            else if ((r_state == R_UC_WAIT) && dev_rvalid_d1)
                data_rdata <= dev_rdata[31:0];
            else if (hit_r)
                data_rdata <= pick_word(cache_line_r[127:0], offset);
        end
    end

    // ---- Cache write logic ----
    wire refill_we    = (r_state == R_REFILL) && dev_rvalid_d1;
    wire write_hit_we = (w_state == W_LOOKUP) && dev_wrdy && hit_w;
    wire cache_we     = refill_we || write_hit_we;
    wire [133:0] cache_line_w = refill_we ? {1'b1, rd_addr_r[14:10], dev_rdata} :
                                            {1'b1, wr_addr_r[14:10], wr_cache_data};

    always @(posedge cpu_clk) begin
        if (cache_we)
            cache_mem[cache_index] <= cache_line_w;
    end

    // ---- Read FSM registers ----
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            r_state       <= R_IDLE;
            rd_addr_r     <= 32'h0;
            rd_ren_r      <= 4'h0;
            rd_uncached_r <= 1'b0;
        end else begin
            r_state <= r_nstat;
            if (r_state == R_IDLE && |data_ren) begin
                rd_addr_r     <= data_addr;
                rd_ren_r      <= data_ren;
                rd_uncached_r <= uncached;
            end
        end
    end

    always @(*) begin
        case (r_state)
            R_IDLE:    r_nstat = (|data_ren) ? (uncached ? (dev_rrdy ? R_UC_WAIT : R_UC_REQ) : R_LOOKUP) : R_IDLE;
            R_LOOKUP:  r_nstat = hit_r ? R_IDLE : (dev_rrdy ? R_REFILL : R_LOOKUP);
            R_REFILL:  r_nstat = dev_rvalid_d1 ? R_IDLE : R_REFILL;
            R_UC_REQ:  r_nstat = dev_rrdy ? R_UC_WAIT : R_UC_REQ;
            R_UC_WAIT: r_nstat = dev_rvalid_d1 ? R_IDLE : R_UC_WAIT;
            default:   r_nstat = R_IDLE;
        endcase
    end

    // ---- Write FSM registers ----
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            w_state       <= W_IDLE;
            wr_addr_r     <= 32'h0;
            wr_wen_r      <= 4'h0;
            wr_data_r     <= 32'h0;
            wr_uncached_r <= 1'b0;
        end else begin
            w_state <= w_nstat;
            if (w_state == W_IDLE && |data_wen) begin
                wr_addr_r     <= data_addr;
                wr_wen_r      <= data_wen;
                wr_data_r     <= data_wdata;
                wr_uncached_r <= uncached;
            end
        end
    end

    wire wr_resp = dev_wrdy && (cpu_wen == 4'h0);

    always @(*) begin
        case (w_state)
            W_IDLE:   w_nstat = (|data_wen) ? W_LOOKUP : W_IDLE;
            W_LOOKUP: w_nstat = dev_wrdy ? W_RESP : W_LOOKUP;
            W_RESP:   w_nstat = wr_resp ? W_IDLE : W_RESP;
            default:  w_nstat = W_IDLE;
        endcase
    end

    // ---- Read request to bus ----
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            cpu_ren   <= 4'h0;
            cpu_raddr <= 32'h0;
        end else begin
            cpu_ren <= 4'h0;
            case (r_state)
                R_IDLE: begin
                    if (|data_ren && uncached && dev_rrdy) begin
                        cpu_ren   <= data_ren;
                        cpu_raddr <= data_addr;
                    end
                end
                R_LOOKUP: begin
                    if (!hit_r && dev_rrdy) begin
                        cpu_ren   <= 4'hF;
                        cpu_raddr <= {rd_addr_r[31:4], 4'b0000};
                    end
                end
                R_REFILL: begin
                    if (!dev_rvalid) begin
                        cpu_ren   <= 4'hF;
                        cpu_raddr <= {rd_addr_r[31:4], 4'b0000};
                    end
                end
                R_UC_REQ: begin
                    if (dev_rrdy) begin
                        cpu_ren   <= rd_ren_r;
                        cpu_raddr <= rd_addr_r;
                    end
                end
            endcase
        end
    end

    // ---- Write to bus ----
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            data_wresp <= 1'b0;
            cpu_wen    <= 4'h0;
            cpu_waddr  <= 32'h0;
            cpu_wdata  <= 32'h0;
        end else begin
            data_wresp <= 1'b0;
            cpu_wen    <= 4'h0;
            case (w_state)
                W_LOOKUP: begin
                    if (dev_wrdy) begin
                        cpu_wen   <= wr_wen_r;
                        cpu_waddr <= wr_addr_r;
                        cpu_wdata <= wr_data_r;
                    end
                end
                W_RESP: begin
                    if (wr_resp)
                        data_wresp <= 1'b1;
                end
            endcase
        end
    end

    // ---- Write-hit: update cache line word ----
    always @(*) begin
        wr_cache_data = cache_line_r[127:0];
        case (wr_addr_r[3:2])
            2'b00: begin
                if (wr_wen_r[0]) wr_cache_data[ 7: 0] = wr_data_r[ 7: 0];
                if (wr_wen_r[1]) wr_cache_data[15: 8] = wr_data_r[15: 8];
                if (wr_wen_r[2]) wr_cache_data[23:16] = wr_data_r[23:16];
                if (wr_wen_r[3]) wr_cache_data[31:24] = wr_data_r[31:24];
            end
            2'b01: begin
                if (wr_wen_r[0]) wr_cache_data[39:32] = wr_data_r[ 7: 0];
                if (wr_wen_r[1]) wr_cache_data[47:40] = wr_data_r[15: 8];
                if (wr_wen_r[2]) wr_cache_data[55:48] = wr_data_r[23:16];
                if (wr_wen_r[3]) wr_cache_data[63:56] = wr_data_r[31:24];
            end
            2'b10: begin
                if (wr_wen_r[0]) wr_cache_data[71:64] = wr_data_r[ 7: 0];
                if (wr_wen_r[1]) wr_cache_data[79:72] = wr_data_r[15: 8];
                if (wr_wen_r[2]) wr_cache_data[87:80] = wr_data_r[23:16];
                if (wr_wen_r[3]) wr_cache_data[95:88] = wr_data_r[31:24];
            end
            2'b11: begin
                if (wr_wen_r[0]) wr_cache_data[103:96]  = wr_data_r[ 7: 0];
                if (wr_wen_r[1]) wr_cache_data[111:104] = wr_data_r[15: 8];
                if (wr_wen_r[2]) wr_cache_data[119:112] = wr_data_r[23:16];
                if (wr_wen_r[3]) wr_cache_data[127:120] = wr_data_r[31:24];
            end
        endcase
    end

`else
    // Passthrough when DCache disabled
    localparam R_IDLE  = 2'b00;
    localparam R_STAT0 = 2'b01;
    localparam R_STAT1 = 2'b11;
    reg [1:0] r_state, r_nstat;
    reg [3:0] ren_r;

    always @(posedge cpu_clk or posedge cpu_rst) r_state <= cpu_rst ? R_IDLE : r_nstat;

    always @(*) begin
        case (r_state)
            R_IDLE:  r_nstat = (|data_ren) ? (dev_rrdy ? R_STAT1 : R_STAT0) : R_IDLE;
            R_STAT0: r_nstat = dev_rrdy ? R_STAT1 : R_STAT0;
            R_STAT1: r_nstat = dev_rvalid ? R_IDLE : R_STAT1;
            default: r_nstat = R_IDLE;
        endcase
    end

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            data_valid <= 1'b0;
            cpu_ren    <= 4'h0;
            cpu_raddr  <= 32'h0;
        end else begin
            case (r_state)
                R_IDLE: begin
                    data_valid <= 1'b0;
                    cpu_ren    <= (|data_ren && dev_rrdy) ? data_ren : 4'h0;
                    cpu_raddr  <= (|data_ren) ? data_addr : 32'h0;
                    if (|data_ren && !dev_rrdy) ren_r <= data_ren;
                end
                R_STAT0: begin
                    cpu_ren   <= dev_rrdy ? ren_r : 4'h0;
                end
                R_STAT1: begin
                    cpu_ren    <= 4'h0;
                    data_valid <= dev_rvalid;
                    data_rdata <= dev_rvalid ? dev_rdata[31:0] : 32'h0;
                end
                default: begin
                    data_valid <= 1'b0;
                    cpu_ren    <= 4'h0;
                end
            endcase
        end
    end

    localparam W_IDLE  = 2'b00;
    localparam W_STAT0 = 2'b01;
    localparam W_STAT1 = 2'b11;
    reg [1:0] w_state, w_nstat;
    reg [3:0] wen_r;
    wire wr_resp_d = dev_wrdy && (cpu_wen == 4'h0);

    always @(posedge cpu_clk or posedge cpu_rst) w_state <= cpu_rst ? W_IDLE : w_nstat;

    always @(*) begin
        case (w_state)
            W_IDLE:  w_nstat = (|data_wen) ? (dev_wrdy ? W_STAT1 : W_STAT0) : W_IDLE;
            W_STAT0: w_nstat = dev_wrdy ? W_STAT1 : W_STAT0;
            W_STAT1: w_nstat = wr_resp_d ? W_IDLE : W_STAT1;
            default: w_nstat = W_IDLE;
        endcase
    end

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            data_wresp <= 1'b0;
            cpu_wen    <= 4'h0;
            cpu_waddr  <= 32'h0;
            cpu_wdata  <= 32'h0;
        end else begin
            case (w_state)
                W_IDLE: begin
                    data_wresp <= 1'b0;
                    cpu_wen    <= (|data_wen && dev_wrdy) ? data_wen : 4'h0;
                    cpu_waddr  <= (|data_wen) ? data_addr : 32'h0;
                    cpu_wdata  <= (|data_wen) ? data_wdata : 32'h0;
                    if (|data_wen && !dev_wrdy) wen_r <= data_wen;
                end
                W_STAT0: begin
                    cpu_wen   <= dev_wrdy ? wen_r : 4'h0;
                end
                W_STAT1: begin
                    cpu_wen    <= 4'h0;
                    data_wresp <= wr_resp_d;
                end
                default: begin
                    data_wresp <= 1'b0;
                    cpu_wen    <= 4'h0;
                end
            endcase
        end
    end
`endif

endmodule
