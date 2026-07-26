`timescale 1ns / 1ps

`include "defines.vh"

// Direct-mapped Instruction Cache
//   Capacity: 64 lines x 128 bits = 1KB
//   Line format: {valid(1bit), tag(5bit), data(128bit)} = 134 bits
//   Index: inst_addr[9:4] (6 bits, 64 entries)
//   Tag:   inst_addr[14:10] (5 bits)

module ICache(
    input  wire         cpu_clk,
    input  wire         cpu_rst,        // high active
    // Interface to CPU
    input  wire         inst_rreq,      // instruction read request
    input  wire [31:0]  inst_addr,      // instruction address
    output reg          inst_valid,     // instruction valid
    output reg  [31:0]  inst_out,       // instruction output
    // Interface to Read Bus (from axi_bus)
    input  wire         dev_rrdy,       // bus ready to accept read request
    output reg  [ 3:0]  cpu_ren,        // read enable to bus
    output reg  [31:0]  cpu_raddr,      // read address to bus
    input  wire         dev_rvalid,     // bus data valid
    input  wire [`IC_BLK_SIZE-1:0] dev_rdata  // data from bus (128 bits)
);

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

`ifdef ENABLE_ICACHE

    localparam IDLE   = 2'b00;
    localparam LOOKUP = 2'b01;
    localparam REFILL = 2'b10;

    reg  [ 1:0] state, nstat;
    reg  [31:0] req_addr_r;

    // Cache storage: 64 lines x 134 bits
    reg [133:0] cache_mem [0:63];

    wire [5:0] cache_index_r = req_addr_r[9:4];
    wire [5:0] cache_index_w = (state == IDLE) ? inst_addr[9:4] : cache_index_r;
    wire [133:0] cache_line_r = cache_mem[cache_index_r];
    wire [133:0] cache_line_w = {1'b1, req_addr_r[14:10], dev_rdata};

    wire [4:0] tag_from_cpu   = req_addr_r[14:10];
    wire [1:0] offset         = req_addr_r[3:2];
    wire       valid_bit      = cache_line_r[133];
    wire [4:0] tag_from_cache = cache_line_r[132:128];

    wire hit = (state == LOOKUP) && valid_bit && (tag_from_cpu == tag_from_cache);

    // Delay dev_rvalid by 1 cycle — data is stable one cycle after rvalid asserts
    reg dev_rvalid_d1;
    always @(posedge cpu_clk) begin
        if (cpu_rst) dev_rvalid_d1 <= 1'b0;
        else         dev_rvalid_d1 <= dev_rvalid;
    end

    always @(posedge cpu_clk) begin
        if (state == REFILL && dev_rvalid_d1)
            cache_mem[cache_index_w] <= {1'b1, req_addr_r[14:10], dev_rdata};
    end

    // ----- DEBUG -----
    reg [31:0] dbg_hit_cnt;
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            dbg_hit_cnt <= 0;
        end else begin

            if ((state == REFILL) && dev_rvalid_d1)
                $display("[ICache] FILL idx=%d addr=%08x d0=%08x d1=%08x d2=%08x d3=%08x",
                    cache_index_w, req_addr_r, dev_rdata[31:0], dev_rdata[63:32],
                    dev_rdata[95:64], dev_rdata[127:96]);
            if (hit) begin
                dbg_hit_cnt <= dbg_hit_cnt + 1;
                if (dbg_hit_cnt < 8)
                    $display("[ICache] HIT  idx=%d pc=%08x inst=%08x",
                        req_addr_r[9:4], req_addr_r, pick_word(cache_line_r[127:0], req_addr_r[3:2]));
            end
            if (state == REFILL && !dev_rvalid && !hit)
                $display("[ICache] WAIT_REFILL pc=%08x dev_rrdy=%d", req_addr_r, dev_rrdy);
        end
    end

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            inst_valid <= 1'b0;
            inst_out   <= 32'h0;
        end else begin
            inst_valid <= hit | ((state == REFILL) && dev_rvalid_d1);
            if ((state == REFILL) && dev_rvalid_d1)
                inst_out <= pick_word(dev_rdata, offset);
            else if (hit)
                inst_out <= pick_word(cache_line_r[127:0], offset);
        end
    end

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            state      <= IDLE;
            req_addr_r <= 32'h0;
        end else begin
            state <= nstat;
            if (state == IDLE && inst_rreq)
                req_addr_r <= inst_addr;
        end
    end

    always @(*) begin
        case (state)
            IDLE:   nstat = inst_rreq ? LOOKUP : IDLE;
            LOOKUP: nstat = hit ? IDLE : (dev_rrdy ? REFILL : LOOKUP);
            REFILL: nstat = dev_rvalid_d1 ? IDLE : REFILL;
            default:nstat = IDLE;
        endcase
    end

    reg [31:0] refill_addr;
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            cpu_ren   <= 4'h0;
            cpu_raddr <= 32'h0;
        end else begin
            cpu_ren <= 4'h0;
            // Latch refill address once on LOOKUP miss
            if (state == LOOKUP && !hit && dev_rrdy)
                refill_addr <= {req_addr_r[31:4], 4'b0000};
            // Hold cpu_ren during entire REFILL so axi_bus doesn't miss the pulse
            if (state == REFILL && !dev_rvalid) begin
                cpu_ren   <= 4'hF;
                cpu_raddr <= refill_addr;
            end
        end
    end

`else
    // Passthrough when ICache disabled
    localparam IDLE  = 2'b00;
    localparam STAT0 = 2'b01;
    localparam STAT1 = 2'b11;
    reg [1:0] state, nstat;

    always @(posedge cpu_clk or posedge cpu_rst) begin
        state <= cpu_rst ? IDLE : nstat;
    end

    always @(*) begin
        case (state)
            IDLE:    nstat = inst_rreq ? (dev_rrdy ? STAT1 : STAT0) : IDLE;
            STAT0:   nstat = dev_rrdy ? STAT1 : STAT0;
            STAT1:   nstat = dev_rvalid ? IDLE : STAT1;
            default: nstat = IDLE;
        endcase
    end

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            inst_valid <= 1'b0;
            cpu_ren    <= 4'h0;
            cpu_raddr  <= 32'h0;
        end else begin
            case (state)
                IDLE: begin
                    inst_valid <= 1'b0;
                    cpu_ren    <= (inst_rreq && dev_rrdy) ? 4'hF : 4'h0;
                    cpu_raddr  <= inst_rreq ? inst_addr : 32'h0;
                end
                STAT0: begin
                    cpu_ren    <= dev_rrdy ? 4'hF : 4'h0;
                end
                STAT1: begin
                    cpu_ren    <= 4'h0;
                    inst_valid <= dev_rvalid;
                    inst_out   <= dev_rvalid ? dev_rdata[31:0] : 32'h0;
                end
                default: begin
                    inst_valid <= 1'b0;
                    cpu_ren    <= 4'h0;
                end
            endcase
        end
    end
`endif

endmodule
