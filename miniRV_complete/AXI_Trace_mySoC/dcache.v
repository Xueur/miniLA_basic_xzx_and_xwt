`timescale 1ns / 1ps

module dcache #(
    parameter LINES = 64
)(
    input  wire         clk,
    input  wire         rst,

    input  wire [ 3:0]  cpu_ren,
    input  wire [ 3:0]  cpu_wen,
    input  wire [31:0]  cpu_addr,
    input  wire [31:0]  cpu_wdata,
    output reg          cpu_rvalid,
    output reg  [31:0]  cpu_rdata,
    output reg          cpu_wresp,

    input  wire         mem_rrdy,
    output wire         mem_ren,
    output wire [31:0]  mem_raddr,
    input  wire         mem_rvalid,
    input  wire [127:0] mem_rdata,

    input  wire         mem_wrdy,
    output wire [ 3:0]  mem_wen,
    output wire [31:0]  mem_waddr,
    output wire [31:0]  mem_wdata,

    output wire         io_ren,
    output wire [ 3:0]  io_wen,
    output wire [31:0]  io_addr,
    output wire [31:0]  io_wdata,
    input  wire         io_rvalid,
    input  wire [31:0]  io_rdata,
    input  wire         io_wresp
);

    localparam INDEX_W = $clog2(LINES);
    localparam ST_IDLE    = 4'd0;
    localparam ST_RD_REQ  = 4'd1;
    localparam ST_RD_WAIT = 4'd2;
    localparam ST_WR_REQ  = 4'd3;
    localparam ST_WR_WAIT = 4'd4;
    localparam ST_IO_RREQ = 4'd5;
    localparam ST_IO_RWAIT= 4'd6;
    localparam ST_IO_WREQ = 4'd7;
    localparam ST_IO_WWAIT= 4'd8;

    reg [3:0] state;
    reg [31:0] request_addr;
    reg [31:0] request_wdata;
    reg [3:0] request_wen;
    reg [31-INDEX_W-4:0] tags [0:LINES-1];
    reg [127:0] lines [0:LINES-1];
    reg valid [0:LINES-1];
    integer i;

    wire [INDEX_W-1:0] cpu_index = cpu_addr[INDEX_W+3:4];
    wire [31-INDEX_W-4:0] cpu_tag = cpu_addr[31:INDEX_W+4];
    wire cpu_hit = valid[cpu_index] && tags[cpu_index] == cpu_tag;
    wire is_io = cpu_addr[31:16] == 16'hFFFF;

    wire [INDEX_W-1:0] request_index =
        request_addr[INDEX_W+3:4];
    wire [31-INDEX_W-4:0] request_tag =
        request_addr[31:INDEX_W+4];

    function [31:0] select_word;
        input [127:0] block;
        input [1:0] word;
        begin
            case (word)
                2'd0: select_word = block[31:0];
                2'd1: select_word = block[63:32];
                2'd2: select_word = block[95:64];
                default: select_word = block[127:96];
            endcase
        end
    endfunction

    assign mem_ren = state == ST_RD_REQ;
    assign mem_raddr = {request_addr[31:4], 4'h0};
    assign mem_wen = state == ST_WR_REQ ? request_wen : 4'h0;
    assign mem_waddr = request_addr;
    assign mem_wdata = request_wdata;

    assign io_ren = state == ST_IO_RREQ;
    assign io_wen = state == ST_IO_WREQ ? request_wen : 4'h0;
    assign io_addr = request_addr;
    assign io_wdata = request_wdata;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= ST_IDLE;
            request_addr <= 32'h0;
            request_wdata <= 32'h0;
            request_wen <= 4'h0;
            cpu_rvalid <= 1'b0;
            cpu_rdata <= 32'h0;
            cpu_wresp <= 1'b0;
            for (i = 0; i < LINES; i = i + 1)
                valid[i] <= 1'b0;
        end else begin
            cpu_rvalid <= 1'b0;
            cpu_wresp <= 1'b0;
            case (state)
                ST_IDLE: begin
                    if (|cpu_wen) begin
                        request_addr <= cpu_addr;
                        request_wdata <= cpu_wdata;
                        request_wen <= cpu_wen;
                        if (cpu_hit)
                            valid[cpu_index] <= 1'b0;
                        state <= is_io ? ST_IO_WREQ : ST_WR_REQ;
                    end else if (|cpu_ren) begin
                        if (is_io) begin
                            request_addr <= cpu_addr;
                            state <= ST_IO_RREQ;
                        end else if (cpu_hit) begin
                            cpu_rdata <= select_word(lines[cpu_index],
                                                     cpu_addr[3:2]);
                            cpu_rvalid <= 1'b1;
                        end else begin
                            request_addr <= cpu_addr;
                            state <= ST_RD_REQ;
                        end
                    end
                end
                ST_RD_REQ:
                    if (mem_rrdy)
                        state <= ST_RD_WAIT;
                ST_RD_WAIT: begin
                    if (mem_rvalid) begin
                        lines[request_index] <= mem_rdata;
                        tags[request_index] <= request_tag;
                        valid[request_index] <= 1'b1;
                        cpu_rdata <= select_word(mem_rdata,
                                                 request_addr[3:2]);
                        cpu_rvalid <= 1'b1;
                        state <= ST_IDLE;
                    end
                end
                ST_WR_REQ:
                    if (mem_wrdy)
                        state <= ST_WR_WAIT;
                ST_WR_WAIT: begin
                    if (mem_wrdy) begin
                        cpu_wresp <= 1'b1;
                        state <= ST_IDLE;
                    end
                end
                ST_IO_RREQ:
                    state <= ST_IO_RWAIT;
                ST_IO_RWAIT: begin
                    if (io_rvalid) begin
                        cpu_rdata <= io_rdata;
                        cpu_rvalid <= 1'b1;
                        state <= ST_IDLE;
                    end
                end
                ST_IO_WREQ:
                    state <= ST_IO_WWAIT;
                ST_IO_WWAIT: begin
                    if (io_wresp) begin
                        cpu_wresp <= 1'b1;
                        state <= ST_IDLE;
                    end
                end
                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
